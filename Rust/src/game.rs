//! Gameplay state machine.  All mutations are synchronous: a snapshot already
//! contains the post-action truth, which is what makes win/loss detection
//! reliable.  Animation is represented as data (`reveal_delays_ms` and
//! `CoreEffect`) and executed by Swift.

use std::sync::{Arc, Mutex, MutexGuard};
use std::time::Instant;

use crate::geometry::Geometry;
use crate::model::*;
use crate::rng::{generate_environmental_seed, new_record_id, now_reference_date, SeededRng};
use crate::solver;

const REVEAL_DELAY_STEP_MS: u16 = 45;
const REVEAL_DELAY_MAX_MS: u16 = 1500;
const EXPLOSION_WAVE_STEP_MS: u32 = 90;
const EXPLOSION_RESULT_EXTRA_MS: u32 = 350;

#[inline]
fn neighbour_array(geometry: &Geometry, index: usize) -> ([u16; 8], usize) {
    let mut out = [0u16; 8];
    let mut len = 0usize;
    for &neighbour in geometry.neighbours(index) {
        out[len] = neighbour;
        len += 1;
    }
    (out, len)
}

#[derive(uniffi::Object)]
pub struct CoreGame {
    state: Mutex<GameState>,
}

#[uniffi::export]
impl CoreGame {
    #[uniffi::constructor]
    pub fn new(config: CoreConfig) -> Arc<Self> {
        Arc::new(Self {
            state: Mutex::new(GameState::new(config)),
        })
    }

    pub fn apply(&self, action: CoreAction) -> CoreSnapshot {
        let mut state = self.lock();
        state.begin_action();
        match action {
            CoreAction::Reveal { index } => state.reveal(index as usize, true, true),
            CoreAction::ToggleFlag { index } => state.toggle_flag(index as usize),
            CoreAction::Chord { index } => state.chord(index as usize),
        }
        state.make_snapshot(true, true)
    }

    pub fn snapshot(&self) -> CoreSnapshot {
        self.lock().make_snapshot(false, false)
    }

    pub fn advance_time(&self, seconds: u32) -> u32 {
        let mut state = self.lock();
        if state.status == CoreGameStatus::Playing && state.started {
            state.elapsed = state.elapsed.saturating_add(seconds).min(99 * 60 + 59);
        }
        state.elapsed
    }
}

impl CoreGame {
    fn lock(&self) -> MutexGuard<'_, GameState> {
        match self.state.lock() {
            Ok(guard) => guard,
            Err(poisoned) => poisoned.into_inner(),
        }
    }
}

struct GameState {
    config: CoreConfig,
    geometry: Geometry,
    cells: Vec<Cell>,
    neighbour_counts: Vec<u8>,
    reveal_delays: Vec<u16>,
    status: CoreGameStatus,
    seed: i64,
    elapsed: u32,
    started: bool,
    first_click: bool,
    flags_count: u32,
    flags_on_mines: u32,
    mines_count: u32,
    safe_revealed: u32,
    mine_indices: Vec<u16>,
    moves: Vec<CoreMove>,
    move_start: Option<Instant>,
    pending_record: Option<CoreRecord>,
    effects: Vec<CoreEffect>,
    scratch_available: Vec<u16>,
    scratch_safe: Vec<bool>,
}

#[derive(Clone, Copy, Default)]
struct Cell {
    flags: u8,
}

impl Cell {
    #[inline]
    fn is_mine(self) -> bool {
        self.flags & FLAG_MINE != 0
    }

    #[inline]
    fn is_revealed(self) -> bool {
        self.flags & FLAG_REVEALED != 0
    }

    #[inline]
    fn is_flagged(self) -> bool {
        self.flags & FLAG_FLAGGED != 0
    }
}

impl GameState {
    fn new(config: CoreConfig) -> Self {
        let rows = config.difficulty.rows();
        let cols = config.difficulty.cols();
        let count = rows * cols;
        let seed = config
            .seed
            .unwrap_or_else(|| generate_environmental_seed(config.battery_percent));
        Self {
            config,
            geometry: Geometry::new(rows, cols),
            cells: vec![Cell::default(); count],
            neighbour_counts: vec![0; count],
            reveal_delays: vec![0; count],
            status: CoreGameStatus::Playing,
            seed,
            elapsed: 0,
            started: false,
            first_click: true,
            flags_count: 0,
            flags_on_mines: 0,
            mines_count: 0,
            safe_revealed: 0,
            mine_indices: Vec::with_capacity(256),
            moves: Vec::with_capacity(512),
            move_start: None,
            pending_record: None,
            effects: Vec::with_capacity(8),
            scratch_available: Vec::with_capacity(count),
            scratch_safe: vec![false; count],
        }
    }

    #[inline]
    fn count(&self) -> usize {
        self.geometry.len()
    }

    #[inline]
    fn safe_total(&self) -> u32 {
        (self.count() as u32).saturating_sub(self.mines_count)
    }

    fn begin_action(&mut self) {
        self.effects.clear();
        self.reveal_delays.fill(0);
    }

    fn mark_started(&mut self) {
        if self.move_start.is_none() {
            self.move_start = Some(Instant::now());
        }
    }

    fn record_move(&mut self, index: usize, move_type: &str) {
        self.mark_started();
        let timestamp = self
            .move_start
            .map(|start| Instant::now().duration_since(start).as_secs_f64())
            .unwrap_or(0.0);
        self.moves.push(CoreMove {
            timestamp,
            index: index as u32,
            move_type: move_type.to_string(),
        });
    }

    fn reveal(&mut self, index: usize, record_move: bool, emit_haptic: bool) {
        self.reveal_internal(index, record_move, emit_haptic);
    }

    fn reveal_internal(&mut self, index: usize, record_move: bool, emit_haptic: bool) {
        if self.status != CoreGameStatus::Playing || index >= self.count() {
            return;
        }
        let cell = self.cells[index];
        if cell.is_revealed() || cell.is_flagged() {
            return;
        }
        if record_move {
            self.record_move(index, "reveal");
        } else {
            self.mark_started();
        }

        if self.first_click {
            self.first_click = false;
            self.started = true;
            if self.config.nanagokyuu {
                self.inject_nanagokyuu_mines(index);
            } else {
                self.place_mines(index);
            }
        }

        if self.cells[index].is_mine() {
            self.trigger_loss(index);
            return;
        }

        self.flood_fill(index);
        if emit_haptic {
            self.effects.push(CoreEffect::Haptic {
                kind: CoreHapticKind::Light,
                delay_ms: 0,
            });
        }
        self.check_win_after_reveal();
        self.check_win_after_flag();
    }

    fn toggle_flag(&mut self, index: usize) {
        if self.status != CoreGameStatus::Playing || index >= self.count() {
            return;
        }
        let cell = self.cells[index];
        if cell.is_revealed() {
            return;
        }
        self.mark_started();
        let was_flagged = cell.is_flagged();
        if was_flagged {
            self.cells[index].flags &= !FLAG_FLAGGED;
            self.flags_count = self.flags_count.saturating_sub(1);
            if self.cells[index].is_mine() {
                self.flags_on_mines = self.flags_on_mines.saturating_sub(1);
            }
        } else {
            self.cells[index].flags |= FLAG_FLAGGED;
            self.flags_count = self.flags_count.saturating_add(1);
            if self.cells[index].is_mine() {
                self.flags_on_mines = self.flags_on_mines.saturating_add(1);
            }
        }
        self.record_move(index, "flag");
        self.effects.push(CoreEffect::Haptic {
            kind: CoreHapticKind::Heavy,
            delay_ms: 0,
        });
        self.check_win_after_flag();
    }

    fn chord(&mut self, index: usize) {
        if self.status != CoreGameStatus::Playing || index >= self.count() {
            return;
        }
        let cell = self.cells[index];
        if !cell.is_revealed() {
            return;
        }
        let number = self.neighbour_counts[index] as usize;
        if number == 0 {
            return;
        }
        let (neighbours, len) = neighbour_array(&self.geometry, index);
        let mut flagged = 0usize;
        for &neighbour in &neighbours[..len] {
            if self.cells[neighbour as usize].is_flagged() {
                flagged += 1;
            }
        }
        if flagged != number {
            self.effects.push(CoreEffect::Haptic {
                kind: CoreHapticKind::Failure,
                delay_ms: 0,
            });
            return;
        }

        self.mark_started();
        // Record the chord before revealing its neighbours.  A chord can win
        // or lose the game inside `reveal_internal`; `finish` snapshots the
        // move list, so recording afterwards dropped the final chord from the
        // history record and the replay.
        self.record_move(index, "chord");

        let mut did_reveal = false;
        for &neighbour in &neighbours[..len] {
            if self.status != CoreGameStatus::Playing {
                break;
            }
            let neighbour = neighbour as usize;
            let target = self.cells[neighbour];
            if target.is_revealed() || target.is_flagged() {
                continue;
            }
            did_reveal = true;
            self.reveal_internal(neighbour, false, false);
        }
        if did_reveal && self.status == CoreGameStatus::Playing {
            self.effects.push(CoreEffect::Haptic {
                kind: CoreHapticKind::Light,
                delay_ms: 0,
            });
        }
    }

    fn check_win_after_reveal(&mut self) {
        if self.status == CoreGameStatus::Playing && self.safe_revealed >= self.safe_total() {
            // Let the last ripple wave play before covering the board with the
            // result sheet.
            let last_wave = self.reveal_delays.iter().copied().max().unwrap_or(0) as u32;
            self.finish(true, last_wave + 250);
        }
    }

    fn check_win_after_flag(&mut self) {
        if self.status != CoreGameStatus::Playing {
            return;
        }
        if self.mines_count > 0
            && self.flags_count == self.mines_count
            && self.flags_on_mines == self.mines_count
        {
            self.finish(true, 250);
        }
    }

    fn finish(&mut self, win: bool, result_delay_ms: u32) {
        if self.status != CoreGameStatus::Playing {
            return;
        }
        self.status = if win {
            CoreGameStatus::Won
        } else {
            CoreGameStatus::Lost
        };
        if win {
            self.reveal_all_safe();
            self.effects.push(CoreEffect::Haptic {
                kind: CoreHapticKind::Success,
                delay_ms: 0,
            });
        } else {
            self.effects.push(CoreEffect::Haptic {
                kind: CoreHapticKind::Failure,
                delay_ms: result_delay_ms,
            });
        }
        self.effects.push(CoreEffect::ShowResult {
            win,
            delay_ms: result_delay_ms,
        });
        self.make_record(win);
    }

    fn reveal_all_safe(&mut self) {
        for index in 0..self.count() {
            if !self.cells[index].is_mine() && !self.cells[index].is_revealed() {
                self.cells[index].flags |= FLAG_REVEALED;
                self.reveal_delays[index] = 0;
            }
        }
        self.safe_revealed = self.safe_total();
    }

    fn make_record(&mut self, win: bool) {
        if self.config.god_mode || self.config.nanagokyuu {
            return;
        }
        let mine_indices = self
            .mine_indices
            .iter()
            .map(|&index| index as u32)
            .collect::<Vec<_>>();
        self.pending_record = Some(CoreRecord {
            id: new_record_id(),
            date: now_reference_date(),
            duration: self.elapsed,
            difficulty_name: self.config.difficulty.code().to_string(),
            is_win: win,
            is_pinned: false,
            seed: Some(self.seed),
            rows: Some(self.geometry.rows as u32),
            cols: Some(self.geometry.cols as u32),
            mine_indices: Some(mine_indices),
            moves: Some(self.moves.clone()),
        });
    }

    fn trigger_loss(&mut self, center: usize) {
        self.cells[center].flags |= FLAG_REVEALED | FLAG_TRIGGERED;
        self.reveal_delays[center] = 0;

        let max_radius = self.geometry.rows.max(self.geometry.cols);
        let mut waves: Vec<Vec<u32>> = vec![Vec::new(); max_radius + 1];
        for index in 0..self.count() {
            if !self.cells[index].is_mine() {
                continue;
            }
            let distance = self.geometry.chebyshev(center, index);
            self.cells[index].flags |= FLAG_REVEALED;
            // Keep the per-cell visual delay in sync with the wave effect.
            // Explosion rings on hell boards can be slower than the flood-fill
            // cap, so do not reuse REVEAL_DELAY_MAX_MS here.
            self.reveal_delays[index] =
                (distance as u32 * EXPLOSION_WAVE_STEP_MS).min(u16::MAX as u32) as u16;
            waves[distance].push(index as u32);
        }

        self.effects.push(CoreEffect::Haptic {
            kind: CoreHapticKind::Heavy,
            delay_ms: 0,
        });

        let mut last_delay = 0u32;
        for (distance, indices) in waves.into_iter().enumerate() {
            if indices.is_empty() {
                continue;
            }
            let delay = distance as u32 * EXPLOSION_WAVE_STEP_MS;
            last_delay = last_delay.max(delay);
            self.effects.push(CoreEffect::ExplosionWave {
                delay_ms: delay,
                indices,
            });
        }
        self.finish(false, last_delay + EXPLOSION_RESULT_EXTRA_MS);
    }

    fn flood_fill(&mut self, start: usize) {
        if self.cells[start].is_mine() || self.cells[start].is_flagged() {
            return;
        }
        let mut queue: Vec<(u16, u16)> = Vec::with_capacity(64);
        queue.push((start as u16, 0));
        let mut head = 0usize;
        while head < queue.len() {
            let (index, depth) = queue[head];
            head += 1;
            let index = index as usize;
            let cell = self.cells[index];
            if cell.is_mine() || cell.is_flagged() || cell.is_revealed() {
                continue;
            }
            self.cells[index].flags |= FLAG_REVEALED;
            self.safe_revealed = self.safe_revealed.saturating_add(1);
            let delay =
                (depth as u32 * REVEAL_DELAY_STEP_MS as u32).min(REVEAL_DELAY_MAX_MS as u32) as u16;
            self.reveal_delays[index] = delay;

            if self.neighbour_counts[index] == 0 {
                let (neighbours, len) = neighbour_array(&self.geometry, index);
                for &neighbour in &neighbours[..len] {
                    let neighbour = neighbour as usize;
                    if !self.cells[neighbour].is_revealed() && !self.cells[neighbour].is_flagged() {
                        queue.push((neighbour as u16, depth.saturating_add(1)));
                    }
                }
            }
        }
    }

    fn place_mines(&mut self, safe_index: usize) {
        let total_mines = self
            .config
            .difficulty
            .mines()
            .min(self.count().saturating_sub(1));
        let attempts = if self.config.no_guessing { 2000 } else { 1 };
        let mut rng = SeededRng::new(self.seed);
        let count = self.count();

        // Safe zone: the clicked cell plus its neighbours.  If the board is
        // too dense for that, only protect the clicked cell.
        self.scratch_safe.fill(false);
        self.scratch_safe[safe_index] = true;
        for &neighbour in self.geometry.neighbours(safe_index) {
            self.scratch_safe[neighbour as usize] = true;
        }
        let mut safe_size = self.scratch_safe.iter().filter(|&&safe| safe).count();
        if total_mines > count.saturating_sub(safe_size) {
            self.scratch_safe.fill(false);
            self.scratch_safe[safe_index] = true;
            safe_size = 1;
        }

        let mut final_mines = 0usize;
        for _attempt in 0..attempts {
            for cell in &mut self.cells {
                cell.flags &= !FLAG_MINE;
            }
            self.mine_indices.clear();
            self.neighbour_counts.fill(0);
            self.scratch_available.clear();
            for index in 0..count {
                if !self.scratch_safe[index] {
                    self.scratch_available.push(index as u16);
                }
            }
            let mines_to_place = total_mines.min(self.scratch_available.len());
            for i in 0..mines_to_place {
                let remaining = self.scratch_available.len() - i;
                let pick = i + rng.range(remaining);
                self.scratch_available.swap(i, pick);
                let index = self.scratch_available[i] as usize;
                self.cells[index].flags |= FLAG_MINE;
                self.mine_indices.push(index as u16);
            }
            self.neighbour_counts.fill(0);
            for &mine in &self.mine_indices {
                let (neighbours, len) = neighbour_array(&self.geometry, mine as usize);
                for &neighbour in &neighbours[..len] {
                    self.neighbour_counts[neighbour as usize] =
                        self.neighbour_counts[neighbour as usize].saturating_add(1);
                }
            }
            final_mines = mines_to_place;
            if !self.config.no_guessing
                || solver::is_solvable(
                    &self.geometry,
                    &self.neighbour_counts,
                    safe_index,
                    mines_to_place,
                )
            {
                break;
            }
        }

        self.mines_count = final_mines as u32;
        self.recompute_flags_on_mines();
        debug_assert!(safe_size > 0);
    }

    fn inject_nanagokyuu_mines(&mut self, clicked: usize) {
        let mut rng = SeededRng::new(self.seed ^ 0x5A5A_5A5A);
        for cell in &mut self.cells {
            cell.flags &= !FLAG_MINE;
        }
        self.mine_indices.clear();
        self.neighbour_counts.fill(0);
        self.cells[clicked].flags |= FLAG_MINE;
        self.mine_indices.push(clicked as u16);
        for index in 0..self.count() {
            if index != clicked && rng.chance(50) {
                self.cells[index].flags |= FLAG_MINE;
                self.mine_indices.push(index as u16);
            }
        }
        for &mine in &self.mine_indices {
            let (neighbours, len) = neighbour_array(&self.geometry, mine as usize);
            for &neighbour in &neighbours[..len] {
                self.neighbour_counts[neighbour as usize] =
                    self.neighbour_counts[neighbour as usize].saturating_add(1);
            }
        }
        self.mines_count = self.mine_indices.len() as u32;
        self.recompute_flags_on_mines();
    }

    fn recompute_flags_on_mines(&mut self) {
        self.flags_on_mines = self
            .cells
            .iter()
            .filter(|cell| cell.is_flagged() && cell.is_mine())
            .count() as u32;
    }

    fn make_snapshot(&mut self, take_effects: bool, take_record: bool) -> CoreSnapshot {
        let mut cell_flags = Vec::with_capacity(self.count());
        for cell in &self.cells {
            cell_flags.push(cell.flags);
        }
        let effects = if take_effects {
            std::mem::take(&mut self.effects)
        } else {
            Vec::new()
        };
        let finished_record = if take_record {
            self.pending_record.take()
        } else {
            None
        };
        let mines_count = if self.mines_count == 0 {
            self.config.difficulty.mines() as u32
        } else {
            self.mines_count
        };
        CoreSnapshot {
            rows: self.geometry.rows as u32,
            cols: self.geometry.cols as u32,
            cell_flags,
            neighbor_counts: self.neighbour_counts.clone(),
            reveal_delays_ms: self.reveal_delays.clone(),
            status: self.status,
            seed: self.seed,
            elapsed: self.elapsed,
            flags_count: self.flags_count,
            mines_count,
            started: self.started,
            effects,
            finished_record,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn game(difficulty: CoreDifficulty, seed: i64, no_guessing: bool) -> Arc<CoreGame> {
        CoreGame::new(CoreConfig {
            difficulty,
            seed: Some(seed),
            battery_percent: 100,
            no_guessing,
            god_mode: false,
            nanagokyuu: false,
        })
    }

    fn first_click(game: &CoreGame, index: u32) -> CoreSnapshot {
        game.apply(CoreAction::Reveal { index })
    }

    #[test]
    fn first_click_is_safe() {
        for seed in 0..25 {
            let game = game(CoreDifficulty::Easy, seed, true);
            let snapshot = first_click(&game, 40);
            assert_eq!(snapshot.status, CoreGameStatus::Playing);
            let flags = snapshot.cell_flags[40];
            assert_eq!(flags & FLAG_REVEALED, FLAG_REVEALED);
            assert_eq!(flags & FLAG_MINE, 0);
        }
    }

    #[test]
    fn reveal_never_reveals_a_mine_on_the_first_click() {
        for seed in 0..25 {
            let game = game(CoreDifficulty::Medium, seed, false);
            let snapshot = first_click(&game, 0);
            assert_ne!(snapshot.status, CoreGameStatus::Lost);
            assert_eq!(snapshot.cell_flags[0] & FLAG_MINE, 0);
        }
    }

    #[test]
    fn flood_fill_reveals_a_zero_region() {
        let game = game(CoreDifficulty::Easy, 123, false);
        let snapshot = first_click(&game, 40);
        let revealed = snapshot
            .cell_flags
            .iter()
            .filter(|&&flags| flags & FLAG_REVEALED != 0)
            .count();
        assert!(revealed > 9, "expected a ripple, got {revealed} cells");
    }

    #[test]
    fn win_by_flags_is_detected_immediately() {
        let game = game(CoreDifficulty::Easy, 8, false);
        let mut snapshot = first_click(&game, 40);
        let mines: Vec<u32> = snapshot
            .cell_flags
            .iter()
            .enumerate()
            .filter(|(_, flags)| **flags & FLAG_MINE != 0)
            .map(|(index, _)| index as u32)
            .collect();
        assert_eq!(mines.len(), 10);
        for mine in mines {
            snapshot = game.apply(CoreAction::ToggleFlag { index: mine });
        }
        assert_eq!(snapshot.status, CoreGameStatus::Won);
        assert!(snapshot.finished_record.is_some());
        // Every safe cell is revealed by the win path.
        assert!(snapshot
            .cell_flags
            .iter()
            .enumerate()
            .all(|(index, flags)| flags & FLAG_MINE != 0
                || flags & FLAG_REVEALED != 0
                || index == 0));
    }

    #[test]
    fn win_by_revealing_the_last_safe_cell_is_immediate() {
        let game = game(CoreDifficulty::Easy, 123, false);
        let mut snapshot = first_click(&game, 40);
        let mines: Vec<usize> = snapshot
            .cell_flags
            .iter()
            .enumerate()
            .filter(|(_, flags)| **flags & FLAG_MINE != 0)
            .map(|(index, _)| index)
            .collect();
        for index in 0..snapshot.cell_flags.len() {
            if mines.contains(&index) {
                continue;
            }
            if snapshot.status != CoreGameStatus::Playing {
                break;
            }
            snapshot = game.apply(CoreAction::Reveal {
                index: index as u32,
            });
        }
        assert_eq!(snapshot.status, CoreGameStatus::Won);
        assert!(snapshot.finished_record.is_some());
        assert!(snapshot
            .cell_flags
            .iter()
            .enumerate()
            .all(|(index, flags)| flags & FLAG_MINE != 0
                || flags & FLAG_REVEALED != 0
                || index == 0));
    }

    #[test]
    fn loss_reveals_all_mines_and_emits_waves() {
        let game = game(CoreDifficulty::Easy, 9, false);
        let mut snapshot = first_click(&game, 40);
        let mine = (0..81)
            .find(|&index| snapshot.cell_flags[index] & FLAG_MINE != 0)
            .unwrap();
        snapshot = game.apply(CoreAction::Reveal { index: mine as u32 });
        assert_eq!(snapshot.status, CoreGameStatus::Lost);
        assert_eq!(snapshot.cell_flags[mine] & FLAG_TRIGGERED, FLAG_TRIGGERED);
        assert!(snapshot
            .cell_flags
            .iter()
            .enumerate()
            .all(|(index, flags)| flags & FLAG_MINE == 0
                || flags & FLAG_REVEALED != 0
                || index == mine));
        assert!(snapshot
            .effects
            .iter()
            .any(|effect| matches!(effect, CoreEffect::ExplosionWave { .. })));
        assert!(snapshot.finished_record.is_some());
    }

    #[test]
    fn flags_can_be_toggled_and_counted() {
        let game = game(CoreDifficulty::Easy, 3, false);
        let snapshot = game.apply(CoreAction::ToggleFlag { index: 0 });
        assert_eq!(snapshot.flags_count, 1);
        assert_eq!(snapshot.cell_flags[0] & FLAG_FLAGGED, FLAG_FLAGGED);
        let snapshot = game.apply(CoreAction::ToggleFlag { index: 0 });
        assert_eq!(snapshot.flags_count, 0);
        assert_eq!(snapshot.cell_flags[0] & FLAG_FLAGGED, 0);
    }

    #[test]
    fn nanagokyuu_loses_on_first_click_and_skips_history() {
        let game = CoreGame::new(CoreConfig {
            difficulty: CoreDifficulty::Easy,
            seed: Some(5),
            battery_percent: 100,
            no_guessing: false,
            god_mode: false,
            nanagokyuu: true,
        });
        let snapshot = game.apply(CoreAction::Reveal { index: 40 });
        assert_eq!(snapshot.status, CoreGameStatus::Lost);
        assert!(snapshot.finished_record.is_none());
    }

    #[test]
    fn god_mode_skips_history() {
        let game = CoreGame::new(CoreConfig {
            difficulty: CoreDifficulty::Easy,
            seed: Some(5),
            battery_percent: 100,
            no_guessing: false,
            god_mode: true,
            nanagokyuu: false,
        });
        let mut snapshot = game.apply(CoreAction::Reveal { index: 40 });
        let mine = (0..81)
            .find(|&index| snapshot.cell_flags[index] & FLAG_MINE != 0)
            .unwrap();
        snapshot = game.apply(CoreAction::Reveal { index: mine as u32 });
        assert_eq!(snapshot.status, CoreGameStatus::Lost);
        assert!(snapshot.finished_record.is_none());
    }

    #[test]
    fn requested_seed_is_exposed() {
        let game = game(CoreDifficulty::Easy, 777, false);
        let snapshot = game.snapshot();
        assert_eq!(snapshot.seed, 777);
        assert_eq!(snapshot.status, CoreGameStatus::Playing);
        assert_eq!(snapshot.elapsed, 0);
    }

    #[test]
    fn advance_time_only_counts_while_playing() {
        let game = game(CoreDifficulty::Easy, 1, false);
        let snapshot = first_click(&game, 40);
        assert!(snapshot.started);
        assert_eq!(game.advance_time(3), 3);
        assert_eq!(game.advance_time(2), 5);
    }

    #[test]
    fn winning_chord_is_recorded_before_finish() {
        let game = game(CoreDifficulty::Easy, 1, false);
        let mut state = game.lock();

        // 9x9, one mine at 41.  Cell 40 is a revealed "1"; its only mine
        // neighbour is flagged and its only unrevealed safe neighbour is 39.
        // Revealing 39 via chord completes the board and wins.
        let mine = 41usize;
        let safe = 39usize;
        let chord = 40usize;
        for index in 0..81 {
            if index == mine {
                state.cells[index].flags = FLAG_MINE | FLAG_FLAGGED;
            } else if index == safe {
                state.cells[index].flags = 0;
            } else {
                state.cells[index].flags = FLAG_REVEALED;
            }
        }
        state.cells[mine].flags |= FLAG_REVEALED;
        state.neighbour_counts.fill(0);
        state.neighbour_counts[chord] = 1;
        state.mines_count = 1;
        state.flags_count = 1;
        state.flags_on_mines = 1;
        state.safe_revealed = 79;
        state.mine_indices.clear();
        state.mine_indices.push(mine as u16);
        state.moves.clear();
        state.pending_record = None;
        state.status = CoreGameStatus::Playing;
        state.started = true;
        state.first_click = false;

        state.chord(chord);

        assert_eq!(state.status, CoreGameStatus::Won);
        let record = state.pending_record.as_ref().expect("winning record");
        let moves = record.moves.as_ref().expect("moves");
        assert_eq!(moves.len(), 1);
        assert_eq!(moves[0].move_type, "chord");
        assert_eq!(moves[0].index, chord as u32);
    }
}
