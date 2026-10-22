//! History store: sorting, pinning, de-duplication, cloud merge, 50-record
//! cap and JSON (de)serialization.  Swift only supplies/drains `Data` and
//! talks to `UserDefaults` / iCloud KVS.

use std::cmp::Ordering;
use std::sync::{Arc, Mutex, MutexGuard};

use crate::model::CoreRecord;

const MAX_RECORDS: usize = 50;

#[derive(uniffi::Object)]
pub struct CoreHistory {
    records: Mutex<Vec<CoreRecord>>,
}

#[uniffi::export]
impl CoreHistory {
    #[uniffi::constructor]
    pub fn new() -> Arc<Self> {
        Arc::new(Self {
            records: Mutex::new(Vec::new()),
        })
    }

    pub fn load(&self, data: Vec<u8>) {
        let mut records = decode(&data);
        sort(&mut records);
        trim(&mut records);
        *self.lock() = records;
    }

    pub fn encode(&self) -> Vec<u8> {
        serde_json::to_vec(&*self.lock()).unwrap_or_default()
    }

    pub fn records(&self) -> Vec<CoreRecord> {
        self.lock().clone()
    }

    pub fn add(&self, record: CoreRecord) -> Vec<CoreRecord> {
        let mut records = self.lock();
        records.push(record);
        sort(&mut records);
        trim(&mut records);
        records.clone()
    }

    pub fn delete(&self, id: String) -> Vec<CoreRecord> {
        let mut records = self.lock();
        records.retain(|record| record.id != id);
        records.clone()
    }

    pub fn toggle_pin(&self, id: String) -> Vec<CoreRecord> {
        let mut records = self.lock();
        if let Some(record) = records.iter_mut().find(|record| record.id == id) {
            record.is_pinned = !record.is_pinned;
        }
        sort(&mut records);
        records.clone()
    }

    pub fn clear(&self) -> Vec<CoreRecord> {
        self.lock().clear();
        Vec::new()
    }

    /// Merge a cloud payload into the local list.  Cloud records win on ID
    /// collisions (same behaviour as the old Swift implementation), then the
    /// merged list is sorted and capped.
    pub fn merge_cloud(&self, data: Vec<u8>) -> Vec<CoreRecord> {
        // Malformed data is ignored instead of wiping local history.  An empty
        // cloud list is also ignored: it can mean "this device has never
        // uploaded" or a failed upload, and treating it as "clear all" used to
        // be able to erase a healthy local history on another device.  A
        // tombstone-based clear can be added later if cross-device clearing is
        // required.
        let cloud: Vec<CoreRecord> = match serde_json::from_slice(&data) {
            Ok(cloud) => cloud,
            Err(_) => return self.lock().clone(),
        };
        if cloud.is_empty() {
            return self.lock().clone();
        }
        let mut merged = Vec::with_capacity(cloud.len() + self.lock().len());
        for record in cloud {
            if !merged
                .iter()
                .any(|existing: &CoreRecord| existing.id == record.id)
            {
                merged.push(record);
            }
        }
        let local = self.lock();
        for record in local.iter() {
            if !merged.iter().any(|existing| existing.id == record.id) {
                merged.push(record.clone());
            }
        }
        drop(local);
        sort(&mut merged);
        trim(&mut merged);
        let mut records = self.lock();
        *records = merged;
        records.clone()
    }
}

impl CoreHistory {
    fn lock(&self) -> MutexGuard<'_, Vec<CoreRecord>> {
        match self.records.lock() {
            Ok(guard) => guard,
            Err(poisoned) => poisoned.into_inner(),
        }
    }
}

fn decode(data: &[u8]) -> Vec<CoreRecord> {
    if data.is_empty() {
        return Vec::new();
    }
    serde_json::from_slice::<Vec<CoreRecord>>(data).unwrap_or_default()
}

fn sort(records: &mut [CoreRecord]) {
    records.sort_by(|a, b| {
        b.is_pinned
            .cmp(&a.is_pinned)
            .then_with(|| b.date.partial_cmp(&a.date).unwrap_or(Ordering::Equal))
    });
}

fn trim(records: &mut Vec<CoreRecord>) {
    if records.len() > MAX_RECORDS {
        records.truncate(MAX_RECORDS);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn record(id: &str, date: f64, pinned: bool) -> CoreRecord {
        CoreRecord {
            id: id.to_string(),
            date,
            duration: 12,
            difficulty_name: "easy".to_string(),
            is_win: true,
            is_pinned: pinned,
            seed: Some(42),
            rows: Some(9),
            cols: Some(9),
            mine_indices: Some(vec![1, 2]),
            moves: Some(vec![crate::model::CoreMove {
                timestamp: 0.5,
                index: 1,
                move_type: "reveal".to_string(),
            }]),
        }
    }

    #[test]
    fn roundtrip_preserves_records() {
        let history = CoreHistory::new();
        history.add(record("a", 10.0, false));
        history.add(record("b", 20.0, false));
        let data = history.encode();
        let loaded = CoreHistory::new();
        loaded.load(data);
        let records = loaded.records();
        assert_eq!(records.len(), 2);
        assert_eq!(records[0].id, "b"); // newest first
        assert_eq!(records[1].id, "a");
    }

    #[test]
    fn pinned_records_sort_first() {
        let history = CoreHistory::new();
        history.add(record("a", 10.0, false));
        history.add(record("b", 20.0, true));
        history.add(record("c", 30.0, false));
        let records = history.records();
        assert_eq!(records[0].id, "b");
        assert_eq!(records[1].id, "c");
    }

    #[test]
    fn empty_cloud_payload_keeps_local_history() {
        let local = CoreHistory::new();
        local.add(record("a", 10.0, false));
        let cloud = CoreHistory::new();
        let merged = local.merge_cloud(cloud.encode());
        assert_eq!(merged.len(), 1);
        assert_eq!(local.records().len(), 1);
    }

    #[test]
    fn malformed_cloud_payload_keeps_local_history() {
        let local = CoreHistory::new();
        local.add(record("a", 10.0, false));
        local.merge_cloud(b"not json".to_vec());
        assert_eq!(local.records().len(), 1);
    }

    #[test]
    fn cloud_merge_deduplicates() {
        let local = CoreHistory::new();
        local.add(record("a", 10.0, false));
        local.add(record("b", 20.0, false));
        let cloud = CoreHistory::new();
        cloud.add(record("b", 25.0, false));
        cloud.add(record("c", 30.0, false));
        let merged = local.merge_cloud(cloud.encode());
        assert_eq!(merged.len(), 3);
        assert_eq!(merged.iter().find(|r| r.id == "b").unwrap().date, 25.0);
    }

    #[test]
    fn cap_is_enforced() {
        let history = CoreHistory::new();
        for i in 0..60 {
            history.add(record(&format!("{i}"), i as f64, false));
        }
        assert_eq!(history.records().len(), MAX_RECORDS);
        // The newest record survives.
        assert_eq!(history.records()[0].id, "59");
    }

    #[test]
    fn legacy_foundation_json_is_decoded() {
        // Mirrors Swift's default JSONEncoder output: Date as a Double since
        // 2001-01-01, camelCase keys and "type" for moves.
        let json = r#"[{"id":"legacy","date":123.5,"duration":7,"difficultyName":"简单","isWin":false,"isPinned":true,"seed":9,"rows":9,"cols":9,"mineIndices":[0],"moves":[{"timestamp":1.25,"index":0,"type":"reveal"}]}]"#;
        let decoded = decode(json.as_bytes());
        assert_eq!(decoded.len(), 1);
        assert_eq!(decoded[0].id, "legacy");
        assert_eq!(decoded[0].difficulty_name, "简单");
        assert_eq!(decoded[0].moves.as_ref().unwrap()[0].move_type, "reveal");
    }

    #[test]
    fn malformed_json_is_ignored() {
        let history = CoreHistory::new();
        history.load(b"not json".to_vec());
        assert!(history.records().is_empty());
    }
}
