//! Minesweeper core, exposed to Swift through UniFFI.
//!
//! The Swift layer is intentionally thin: it owns SwiftUI, platform APIs
//! (haptics, timers, UserDefaults/iCloud) and nothing else.  Every rule,
//! board mutation, replay step and history merge happens here.

mod game;
mod geometry;
mod history;
mod model;
mod replay;
mod rng;
mod solver;

uniffi::setup_scaffolding!();

pub use game::CoreGame;
pub use history::CoreHistory;
pub use model::*;
pub use replay::CoreReplay;
