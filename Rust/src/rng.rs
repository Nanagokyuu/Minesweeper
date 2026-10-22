//! Deterministic RNG + environmental seed helpers.
//!
//! The LCG is intentionally tiny and fully specified in code.  Do not replace
//! it with `rand` unless you also version the seed, otherwise every shared
//! seed produces a different board on a different build.

use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

const LCG_A: u64 = 6_364_136_223_846_793_005;
const LCG_C: u64 = 1_442_695_040_888_963_407;
const UNIX_TO_APPLE_REFERENCE: f64 = 978_307_200.0;

#[derive(Clone, Debug)]
pub struct SeededRng {
    state: u64,
}

impl SeededRng {
    pub fn new(seed: i64) -> Self {
        let mut state = seed as u64;
        if state == 0 {
            state = 0x0009_8765_4321;
        }
        Self { state }
    }

    #[inline]
    pub fn next_u64(&mut self) -> u64 {
        self.state = self.state.wrapping_mul(LCG_A).wrapping_add(LCG_C);
        self.state
    }

    /// Unbiased-enough bounded integer for a game RNG.  The modulo bias is
    /// irrelevant for boards of at most a few hundred cells, and avoiding a
    /// division loop keeps board generation branch-light.
    #[inline]
    pub fn range(&mut self, upper: usize) -> usize {
        debug_assert!(upper > 0);
        (self.next_u64() % upper as u64) as usize
    }

    /// Returns true with roughly `percent`% probability.
    #[inline]
    pub fn chance(&mut self, percent: u32) -> bool {
        (self.next_u64() % 100) < percent as u64
    }
}

pub fn now_unix_nanos() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos() as i64)
        .unwrap_or(0)
}

pub fn now_reference_date() -> f64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs_f64() - UNIX_TO_APPLE_REFERENCE)
        .unwrap_or(0.0)
}

pub fn generate_environmental_seed(battery_percent: i32) -> i64 {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default();
    let seconds = now.as_secs() as i64;
    let nanos = now.subsec_nanos() as i64;
    let battery = battery_percent.clamp(0, 100) as i64;
    // Same spirit as the original Swift implementation: time XOR nanos plus
    // a battery factor, kept positive.
    (seconds ^ nanos).wrapping_add(battery.wrapping_mul(1145)) & i64::MAX
}

static ID_COUNTER: AtomicU64 = AtomicU64::new(1);

/// UUID v4-shaped identifier.  IDs only need to be unique inside this app's
/// history, so a time + counter + splitmix mix is sufficient and avoids an
/// extra dependency.
pub fn new_record_id() -> String {
    let counter = ID_COUNTER.fetch_add(1, Ordering::Relaxed);
    let nanos = now_unix_nanos() as u64;
    let mut rng = SeededRng::new((nanos ^ counter.rotate_left(17)) as i64);
    let a = rng.next_u64();
    let b = rng.next_u64();
    let bytes = [
        (a >> 56) as u8,
        (a >> 48) as u8,
        (a >> 40) as u8,
        (a >> 32) as u8,
        (a >> 24) as u8,
        (a >> 16) as u8,
        (a >> 8) as u8,
        a as u8,
        (b >> 56) as u8,
        (b >> 48) as u8,
        (b >> 40) as u8,
        (b >> 32) as u8,
        (b >> 24) as u8,
        (b >> 16) as u8,
        (b >> 8) as u8,
        b as u8,
    ];
    let mut out = String::with_capacity(36);
    for (i, byte) in bytes.iter().enumerate() {
        if matches!(i, 4 | 6 | 8 | 10) {
            out.push('-');
        }
        let mut value = *byte;
        if i == 6 {
            value = (value & 0x0f) | 0x40;
        } else if i == 8 {
            value = (value & 0x3f) | 0x80;
        }
        out.push(char::from_digit((value >> 4) as u32, 16).unwrap());
        out.push(char::from_digit((value & 0x0f) as u32, 16).unwrap());
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rng_is_deterministic() {
        let mut a = SeededRng::new(42);
        let mut b = SeededRng::new(42);
        for _ in 0..1000 {
            assert_eq!(a.next_u64(), b.next_u64());
        }
    }

    #[test]
    fn rng_range_is_bounded() {
        let mut rng = SeededRng::new(7);
        for _ in 0..10_000 {
            assert!(rng.range(37) < 37);
        }
    }

    #[test]
    fn ids_are_uuid_shaped_and_unique() {
        let a = new_record_id();
        let b = new_record_id();
        assert_eq!(a.len(), 36);
        assert_ne!(a, b);
        assert_eq!(a.as_bytes()[14], b'4');
    }

    #[test]
    fn environmental_seed_is_non_negative() {
        assert!(generate_environmental_seed(-1) >= 0);
        assert!(generate_environmental_seed(100) >= 0);
    }
}
