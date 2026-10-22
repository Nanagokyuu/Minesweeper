//! Replay engine.  The UI slider asks for a step and receives a complete,
//! synchronous snapshot.  There are no delayed callbacks to cancel, so seeking
//! backwards and forwards cannot leak state from a previous position.

use std::sync::{Arc, Mutex, MutexGuard};

use crate::geometry::Geometry;
use crate::model::*;

#[derive(uniffi::Object)]
pub struct CoreReplay {
    state: Mutex<ReplayState>,
}

#[uniffi::export]
impl CoreReplay {
    #[uniffi::constructor]
    pub fn new(record: CoreRecord) -> Arc<Self> {
        Arc::new(Self {
            state: Mutex::new(ReplayState::new(record)),
        })
    }

    pub fn step_count(&self) -> u32 {
        self.lock().moves.len() as u32
    }

    pub fn seek(&self, step: u32) -> CoreSnapshot {
        let mut state = self.lock();
        state.seek(step as usize);
        state.snapshot()
    }
}

impl CoreReplay {
    fn lock(&self) -> MutexGuard<'_, ReplayState> {
        match self.state.lock() {
            Ok(guard) => guard,
            Err(poisoned) => poisoned.into_inner(),
        }
    }
}

struct ReplayState {
    geometry: Geometry,
    cells: Vec<u8>,
    neighbour_counts: Vec<u8>,
    moves: Vec<CoreMove>,
    is_win: bool,
    step: usize,
    /// Cell flags every CHECKPOINT_INTERVAL steps.  Backward seeks restore the
    /// nearest checkpoint instead of replaying from move zero.
    checkpoints: Vec<(usize, Vec<u8>)>,
}

const CHECKPOINT_INTERVAL: usize = 16;

impl ReplayState {
    fn new(record: CoreRecord) -> Self {
        let rows = record.rows.unwrap_or(9).max(1) as usize;
        let cols = record.cols.unwrap_or(9).max(1) as usize;
        let geometry = Geometry::new(rows, cols);
        let count = geometry.len();
        let mut cells = vec![0u8; count];
        if let Some(indices) = record.mine_indices {
            for index in indices {
                let index = index as usize;
                if index < count {
                    cells[index] |= FLAG_MINE;
                }
            }
        }
        let mut neighbour_counts = vec![0u8; count];
        for index in 0..count {
            if cells[index] & FLAG_MINE == 0 {
                let mut count = 0u8;
                for &neighbour in geometry.neighbours(index) {
                    if cells[neighbour as usize] & FLAG_MINE != 0 {
                        count += 1;
                    }
                }
                neighbour_counts[index] = count;
            }
        }
        let moves = record.moves.unwrap_or_default();
        let mut state = Self {
            geometry,
            cells,
            neighbour_counts,
            moves,
            is_win: record.is_win,
            step: 0,
            checkpoints: Vec::new(),
        };
        state.reset_visibility();
        state.checkpoints.push((0, state.cells.clone()));
        state
    }

    fn reset_visibility(&mut self) {
        for cell in &mut self.cells {
            *cell &= FLAG_MINE;
        }
    }

    fn seek(&mut self, target: usize) {
        let target = target.min(self.moves.len());
        if target < self.step {
            if let Some((checkpoint_step, checkpoint_cells)) = self
                .checkpoints
                .iter()
                .rev()
                .find(|(step, _)| *step <= target)
                .map(|(step, cells)| (*step, cells.clone()))
            {
                self.cells.clone_from(&checkpoint_cells);
                self.step = checkpoint_step;
            } else {
                self.reset_visibility();
                self.step = 0;
            }
        }
        while self.step < target {
            let move_data = self.moves[self.step].clone();
            self.apply(&move_data);
            self.step += 1;
            if self.step.is_multiple_of(CHECKPOINT_INTERVAL)
                && !self.checkpoints.iter().any(|(step, _)| *step == self.step)
            {
                self.checkpoints.push((self.step, self.cells.clone()));
            }
        }
        if self.is_win && self.step == self.moves.len() {
            self.reveal_all_safe();
        }
    }

    fn apply(&mut self, move_data: &CoreMove) {
        let index = move_data.index as usize;
        if index >= self.cells.len() {
            return;
        }
        match move_data.move_type.as_str() {
            "flag" => {
                if self.cells[index] & FLAG_REVEALED == 0 {
                    self.cells[index] ^= FLAG_FLAGGED;
                }
            }
            "chord" => self.chord(index),
            _ => self.reveal(index),
        }
    }

    fn reveal(&mut self, index: usize) {
        if index >= self.cells.len() {
            return;
        }
        if self.cells[index] & (FLAG_REVEALED | FLAG_FLAGGED) != 0 {
            return;
        }
        if self.cells[index] & FLAG_MINE != 0 {
            self.cells[index] |= FLAG_REVEALED | FLAG_TRIGGERED;
            return;
        }
        self.flood_fill(index);
    }

    fn flood_fill(&mut self, start: usize) {
        let mut queue = vec![start as u16];
        let mut head = 0usize;
        while head < queue.len() {
            let index = queue[head] as usize;
            head += 1;
            if self.cells[index] & (FLAG_MINE | FLAG_REVEALED | FLAG_FLAGGED) != 0 {
                continue;
            }
            self.cells[index] |= FLAG_REVEALED;
            if self.neighbour_counts[index] == 0 {
                for &neighbour in self.geometry.neighbours(index) {
                    let neighbour = neighbour as usize;
                    if self.cells[neighbour] & (FLAG_REVEALED | FLAG_FLAGGED) == 0 {
                        queue.push(neighbour as u16);
                    }
                }
            }
        }
    }

    fn chord(&mut self, index: usize) {
        if self.cells[index] & FLAG_REVEALED == 0 {
            return;
        }
        let number = self.neighbour_counts[index] as usize;
        if number == 0 {
            return;
        }
        let mut neighbours = [0u16; 8];
        let mut len = 0usize;
        for &neighbour in self.geometry.neighbours(index) {
            neighbours[len] = neighbour;
            len += 1;
        }
        let flagged = neighbours[..len]
            .iter()
            .filter(|&&neighbour| self.cells[neighbour as usize] & FLAG_FLAGGED != 0)
            .count();
        if flagged != number {
            return;
        }
        for &neighbour in &neighbours[..len] {
            let neighbour = neighbour as usize;
            if self.cells[neighbour] & (FLAG_REVEALED | FLAG_FLAGGED) == 0 {
                self.reveal(neighbour);
            }
        }
    }

    fn reveal_all_safe(&mut self) {
        for index in 0..self.cells.len() {
            if self.cells[index] & FLAG_MINE == 0 {
                self.cells[index] |= FLAG_REVEALED;
            }
        }
    }

    fn flags_count(&self) -> u32 {
        self.cells
            .iter()
            .filter(|&&cell| cell & FLAG_FLAGGED != 0)
            .count() as u32
    }

    fn mines_count(&self) -> u32 {
        self.cells
            .iter()
            .filter(|&&cell| cell & FLAG_MINE != 0)
            .count() as u32
    }

    fn snapshot(&self) -> CoreSnapshot {
        let status = if self.is_win && self.step == self.moves.len() {
            CoreGameStatus::Won
        } else {
            CoreGameStatus::Playing
        };
        CoreSnapshot {
            rows: self.geometry.rows as u32,
            cols: self.geometry.cols as u32,
            cell_flags: self.cells.clone(),
            neighbor_counts: self.neighbour_counts.clone(),
            reveal_delays_ms: vec![0; self.cells.len()],
            status,
            seed: 0,
            elapsed: 0,
            flags_count: self.flags_count(),
            mines_count: self.mines_count(),
            started: true,
            effects: Vec::new(),
            finished_record: None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn record(is_win: bool, moves: Vec<CoreMove>) -> CoreRecord {
        CoreRecord {
            id: "replay".to_string(),
            date: 0.0,
            duration: 3,
            difficulty_name: "easy".to_string(),
            is_win,
            is_pinned: false,
            seed: Some(1),
            rows: Some(3),
            cols: Some(3),
            mine_indices: Some(vec![0]),
            moves: Some(moves),
        }
    }

    fn move_at(index: u32, kind: &str) -> CoreMove {
        CoreMove {
            timestamp: index as f64,
            index,
            move_type: kind.to_string(),
        }
    }

    #[test]
    fn seek_forwards_and_backwards_is_deterministic() {
        let replay = CoreReplay::new(record(
            false,
            vec![move_at(1, "reveal"), move_at(0, "flag"), move_at(0, "flag")],
        ));
        assert_eq!(replay.step_count(), 3);

        let initial = replay.seek(0);
        assert!(initial
            .cell_flags
            .iter()
            .all(|flags| flags & FLAG_REVEALED == 0));

        let revealed = replay.seek(1);
        assert_ne!(revealed.cell_flags[1] & FLAG_REVEALED, 0);

        let flagged = replay.seek(2);
        assert_ne!(flagged.cell_flags[0] & FLAG_FLAGGED, 0);
        assert_eq!(flagged.flags_count, 1);

        let back = replay.seek(1);
        assert_eq!(back.cell_flags[0] & FLAG_FLAGGED, 0);
        assert_ne!(back.cell_flags[1] & FLAG_REVEALED, 0);

        let forward = replay.seek(3);
        assert_eq!(forward.cell_flags[0] & FLAG_FLAGGED, 0);
    }

    #[test]
    fn winning_replay_reveals_all_safe_cells_at_the_end() {
        let replay = CoreReplay::new(record(
            true,
            vec![
                move_at(1, "reveal"),
                move_at(2, "reveal"),
                move_at(3, "reveal"),
                move_at(6, "reveal"),
                move_at(7, "reveal"),
                move_at(8, "reveal"),
            ],
        ));
        let snapshot = replay.seek(6);
        assert_eq!(snapshot.status, CoreGameStatus::Won);
        for index in 0..9 {
            if index == 0 {
                assert_eq!(snapshot.cell_flags[index] & FLAG_REVEALED, 0);
            } else {
                assert_ne!(snapshot.cell_flags[index] & FLAG_REVEALED, 0);
            }
        }
    }
}
