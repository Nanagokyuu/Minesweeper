//! UniFFI-facing types.  Keep this module free of gameplay logic where
//! possible so the generated Swift API stays small and stable.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum CoreDifficulty {
    Easy,
    Medium,
    Hard,
    Hell,
}

impl CoreDifficulty {
    pub fn rows(self) -> usize {
        match self {
            Self::Easy => 9,
            Self::Medium => 12,
            Self::Hard => 16,
            Self::Hell => 30,
        }
    }

    pub fn cols(self) -> usize {
        match self {
            Self::Easy => 9,
            Self::Medium => 12,
            Self::Hard => 16,
            Self::Hell => 24,
        }
    }

    pub fn mines(self) -> usize {
        match self {
            Self::Easy => 10,
            Self::Medium => 20,
            Self::Hard => 45,
            Self::Hell => 200,
        }
    }

    /// Stable identifier stored in history records.  Never localize this.
    pub fn code(self) -> &'static str {
        match self {
            Self::Easy => "easy",
            Self::Medium => "medium",
            Self::Hard => "hard",
            Self::Hell => "hell",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum CoreGameStatus {
    Playing,
    Won,
    Lost,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum CoreHapticKind {
    Light,
    Heavy,
    Success,
    Failure,
}

/// Presentation effects are decisions made by the core and executed by
/// Swift.  The core never calls UIKit, never schedules timers and never
/// touches SwiftUI.
#[derive(Clone, Debug, uniffi::Enum)]
pub enum CoreEffect {
    Haptic { kind: CoreHapticKind, delay_ms: u32 },
    ExplosionWave { delay_ms: u32, indices: Vec<u32> },
    ShowResult { win: bool, delay_ms: u32 },
}

#[derive(Clone, Debug, uniffi::Enum)]
pub enum CoreAction {
    Reveal { index: u32 },
    ToggleFlag { index: u32 },
    Chord { index: u32 },
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct CoreConfig {
    pub difficulty: CoreDifficulty,
    pub seed: Option<i64>,
    pub battery_percent: i32,
    pub no_guessing: bool,
    pub god_mode: bool,
    pub nanagokyuu: bool,
}

/// A compact snapshot.  `cell_flags`, `neighbor_counts` and
/// `reveal_delays_ms` are flat arrays indexed by `row * cols + col`, which
/// keeps the FFI boundary to three allocations instead of one object per
/// cell.
#[derive(Clone, Debug, uniffi::Record)]
pub struct CoreSnapshot {
    pub rows: u32,
    pub cols: u32,
    /// bit 0 = mine, bit 1 = revealed, bit 2 = flagged, bit 3 = triggered mine
    pub cell_flags: Vec<u8>,
    pub neighbor_counts: Vec<u8>,
    pub reveal_delays_ms: Vec<u16>,
    pub status: CoreGameStatus,
    pub seed: i64,
    pub elapsed: u32,
    pub flags_count: u32,
    pub mines_count: u32,
    pub started: bool,
    pub effects: Vec<CoreEffect>,
    pub finished_record: Option<CoreRecord>,
}

#[derive(Clone, Debug, Serialize, Deserialize, uniffi::Record)]
#[serde(rename_all = "camelCase")]
pub struct CoreRecord {
    pub id: String,
    /// Seconds since Apple's reference date (2001-01-01), matching
    /// Foundation's default `JSONEncoder` date strategy for old records.
    pub date: f64,
    #[serde(default)]
    pub duration: u32,
    /// Stable difficulty code for new records; legacy records may contain a
    /// localized (Chinese) name, which Swift maps back to a code.
    #[serde(default)]
    pub difficulty_name: String,
    #[serde(default)]
    pub is_win: bool,
    #[serde(default)]
    pub is_pinned: bool,
    #[serde(default)]
    pub seed: Option<i64>,
    #[serde(default)]
    pub rows: Option<u32>,
    #[serde(default)]
    pub cols: Option<u32>,
    #[serde(default)]
    pub mine_indices: Option<Vec<u32>>,
    #[serde(default)]
    pub moves: Option<Vec<CoreMove>>,
}

#[derive(Clone, Debug, Serialize, Deserialize, uniffi::Record)]
pub struct CoreMove {
    pub timestamp: f64,
    pub index: u32,
    #[serde(rename = "type")]
    pub move_type: String,
}

pub const FLAG_MINE: u8 = 1 << 0;
pub const FLAG_REVEALED: u8 = 1 << 1;
pub const FLAG_FLAGGED: u8 = 1 << 2;
pub const FLAG_TRIGGERED: u8 = 1 << 3;
