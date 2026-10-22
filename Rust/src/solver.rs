//! No-guess board validation.
//!
//! This is a fast single-cell constraint propagation solver.  It is
//! deliberately conservative: if it cannot prove the board without guessing
//! it returns `false` and the generator retries.  The implementation keeps
//! per-cell unknown/mine counters and a work queue, so each edge is relaxed a
//! constant number of times instead of rescanning every known-safe cell.

use crate::geometry::Geometry;

pub struct SolveOutcome {
    pub known_safe: Vec<bool>,
    pub known_mine: Vec<bool>,
    pub safe_count: usize,
}

pub fn solve(geometry: &Geometry, neighbour_counts: &[u8], start: usize) -> SolveOutcome {
    let n = geometry.len();
    let mut known_safe = vec![false; n];
    let mut known_mine = vec![false; n];
    let mut unknown = vec![0u8; n];
    let mut mines_around = vec![0u8; n];
    let mut in_queue = vec![false; n];
    let mut queue: Vec<u16> = Vec::with_capacity(n);

    for (i, slot) in unknown.iter_mut().enumerate() {
        *slot = geometry.degree(i) as u8;
    }

    let mut safe_count = 0usize;
    let push = |index: usize, in_queue: &mut Vec<bool>, queue: &mut Vec<u16>| {
        if !in_queue[index] {
            in_queue[index] = true;
            queue.push(index as u16);
        }
    };

    // Mark the first click safe.  Every neighbour now has one fewer unknown
    // cell.
    known_safe[start] = true;
    safe_count += 1;
    for &neighbour in geometry.neighbours(start) {
        unknown[neighbour as usize] = unknown[neighbour as usize].saturating_sub(1);
    }
    push(start, &mut in_queue, &mut queue);

    let mut head = 0usize;
    while head < queue.len() {
        let index = queue[head] as usize;
        head += 1;
        in_queue[index] = false;

        if known_mine[index] || !known_safe[index] {
            continue;
        }
        let number = neighbour_counts[index] as usize;
        let unknown_count = unknown[index] as usize;
        if unknown_count == 0 {
            continue;
        }
        let mut known_mines = mines_around[index] as usize;

        // Rule A: all remaining unknown neighbours are mines.
        if unknown_count == number.saturating_sub(known_mines) {
            for &neighbour in geometry.neighbours(index) {
                let neighbour = neighbour as usize;
                if known_safe[neighbour] || known_mine[neighbour] {
                    continue;
                }
                known_mine[neighbour] = true;
                for &other in geometry.neighbours(neighbour) {
                    let other = other as usize;
                    unknown[other] = unknown[other].saturating_sub(1);
                    if known_safe[other] {
                        mines_around[other] = mines_around[other].saturating_add(1);
                        push(other, &mut in_queue, &mut queue);
                    }
                }
            }
            known_mines = mines_around[index] as usize;
        }

        // Rule B: all mines around this cell are already known, therefore all
        // remaining unknown neighbours are safe.
        if known_mines == number {
            for &neighbour in geometry.neighbours(index) {
                let neighbour = neighbour as usize;
                if known_safe[neighbour] || known_mine[neighbour] {
                    continue;
                }
                known_safe[neighbour] = true;
                safe_count += 1;
                // A cell can become safe after some of its neighbours were
                // already identified as mines; initialise its counter.
                let mut mines = 0u8;
                for &other in geometry.neighbours(neighbour) {
                    if known_mine[other as usize] {
                        mines += 1;
                    }
                }
                mines_around[neighbour] = mines;
                for &other in geometry.neighbours(neighbour) {
                    let other = other as usize;
                    unknown[other] = unknown[other].saturating_sub(1);
                    if known_safe[other] {
                        push(other, &mut in_queue, &mut queue);
                    }
                }
                push(neighbour, &mut in_queue, &mut queue);
            }
        }

        if safe_count == n {
            break;
        }
    }

    SolveOutcome {
        known_safe,
        known_mine,
        safe_count,
    }
}

pub fn is_solvable(
    geometry: &Geometry,
    neighbour_counts: &[u8],
    start: usize,
    total_mines: usize,
) -> bool {
    let safe_total = geometry.len().saturating_sub(total_mines);
    let outcome = solve(geometry, neighbour_counts, start);
    if outcome.safe_count < safe_total {
        return false;
    }
    // Soundness check: never treat a mine as safe.
    for (index, &is_safe) in outcome.known_safe.iter().enumerate() {
        if is_safe && outcome.known_mine[index] {
            return false;
        }
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::geometry::Geometry;

    fn counts_from_mines(geometry: &Geometry, mines: &[usize]) -> Vec<u8> {
        let mut counts = vec![0u8; geometry.len()];
        for &mine in mines {
            for &neighbour in geometry.neighbours(mine) {
                counts[neighbour as usize] += 1;
            }
        }
        counts
    }

    #[test]
    fn single_mine_board_is_solvable() {
        // 3x3, mine in the top-right corner.  Starting from the bottom-left
        // corner should reveal everything without guessing.
        let geometry = Geometry::new(3, 3);
        let counts = counts_from_mines(&geometry, &[2]);
        assert!(is_solvable(&geometry, &counts, 6, 1));
    }

    #[test]
    fn ambiguous_board_can_be_rejected() {
        // 1x4 with one mine: a 1 next to an unrevealed edge leaves two
        // possible positions, so basic propagation cannot solve it.
        let geometry = Geometry::new(1, 4);
        let counts = counts_from_mines(&geometry, &[0]);
        // Start at index 1, which is adjacent to the mine.
        assert!(!is_solvable(&geometry, &counts, 1, 1));
    }

    #[test]
    fn solver_is_sound_on_hard_boards() {
        let geometry = Geometry::new(16, 16);
        let mut rng = crate::rng::SeededRng::new(77);
        for _ in 0..100 {
            let mut mines = Vec::with_capacity(45);
            while mines.len() < 45 {
                let candidate = rng.range(256);
                if !mines.contains(&candidate) {
                    mines.push(candidate);
                }
            }
            let counts = counts_from_mines(&geometry, &mines);
            let start = (0..256).find(|i| !mines.contains(i)).unwrap();
            let outcome = solve(&geometry, &counts, start);
            for (i, &safe) in outcome.known_safe.iter().enumerate() {
                if safe {
                    assert!(!mines.contains(&i));
                }
            }
            for (i, &mine) in outcome.known_mine.iter().enumerate() {
                if mine {
                    assert!(mines.contains(&i));
                }
            }
        }
    }

    #[test]
    fn solver_never_marks_an_actual_mine_as_safe() {
        let geometry = Geometry::new(9, 9);
        let mut rng = crate::rng::SeededRng::new(1234);
        for _ in 0..50 {
            let mut mines = Vec::new();
            while mines.len() < 10 {
                let candidate = rng.range(81);
                if !mines.contains(&candidate) {
                    mines.push(candidate);
                }
            }
            let counts = counts_from_mines(&geometry, &mines);
            // Pick a safe start.
            let start = (0..81).find(|i| !mines.contains(i)).unwrap();
            let outcome = solve(&geometry, &counts, start);
            for (i, &safe) in outcome.known_safe.iter().enumerate() {
                if safe {
                    assert!(!mines.contains(&i), "solver marked mine {i} safe");
                }
            }
            for (i, &mine) in outcome.known_mine.iter().enumerate() {
                if mine {
                    assert!(mines.contains(&i), "solver invented mine {i}");
                }
            }
        }
    }
}
