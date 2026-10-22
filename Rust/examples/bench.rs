//! First-click / no-guess generation benchmark.
//!
//! Run with: cargo run --release --example bench

use std::time::Instant;

use minesweeper_core::{CoreAction, CoreConfig, CoreDifficulty, CoreGame};

fn main() {
    for difficulty in [
        CoreDifficulty::Easy,
        CoreDifficulty::Medium,
        CoreDifficulty::Hard,
    ] {
        let iterations = 100;
        let mut total = 0.0f64;
        let mut worst = 0.0f64;
        let mut won_or_playing = 0;
        for seed in 0..iterations {
            let game = CoreGame::new(CoreConfig {
                difficulty,
                seed: Some(seed as i64),
                battery_percent: 100,
                no_guessing: true,
                god_mode: false,
                nanagokyuu: false,
            });
            let started = Instant::now();
            let snapshot = game.apply(CoreAction::Reveal { index: 40 });
            let elapsed = started.elapsed().as_secs_f64();
            total += elapsed;
            worst = worst.max(elapsed);
            if snapshot.status != minesweeper_core::CoreGameStatus::Lost {
                won_or_playing += 1;
            }
        }
        println!(
            "{difficulty:?}: avg {:.3} ms, worst {:.3} ms, non-losing first clicks {}/{}",
            total * 1000.0 / iterations as f64,
            worst * 1000.0,
            won_or_playing,
            iterations
        );
    }
}
