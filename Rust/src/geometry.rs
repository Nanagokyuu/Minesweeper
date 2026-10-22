//! Precomputed board topology.  Building the neighbour table once per game
//! removes a large amount of index arithmetic from the hot paths (no-guess
//! generation can run the solver thousands of times for one first click).

#[derive(Clone, Debug)]
pub struct Geometry {
    pub rows: usize,
    pub cols: usize,
    offsets: Vec<u32>,
    neighbours: Vec<u16>,
}

impl Geometry {
    pub fn new(rows: usize, cols: usize) -> Self {
        let count = rows * cols;
        let mut offsets = Vec::with_capacity(count + 1);
        let mut neighbours = Vec::with_capacity(count * 8);
        offsets.push(0);
        for index in 0..count {
            let r = index / cols;
            let c = index % cols;
            for dr in -1i32..=1 {
                for dc in -1i32..=1 {
                    if dr == 0 && dc == 0 {
                        continue;
                    }
                    let nr = r as i32 + dr;
                    let nc = c as i32 + dc;
                    if nr >= 0 && nr < rows as i32 && nc >= 0 && nc < cols as i32 {
                        neighbours.push((nr as usize * cols + nc as usize) as u16);
                    }
                }
            }
            offsets.push(neighbours.len() as u32);
        }
        Self {
            rows,
            cols,
            offsets,
            neighbours,
        }
    }

    #[inline]
    pub fn len(&self) -> usize {
        self.rows * self.cols
    }

    #[inline]
    pub fn neighbours(&self, index: usize) -> &[u16] {
        let start = self.offsets[index] as usize;
        let end = self.offsets[index + 1] as usize;
        &self.neighbours[start..end]
    }

    #[inline]
    pub fn degree(&self, index: usize) -> usize {
        (self.offsets[index + 1] - self.offsets[index]) as usize
    }

    #[inline]
    pub fn row_col(&self, index: usize) -> (usize, usize) {
        (index / self.cols, index % self.cols)
    }

    #[inline]
    pub fn chebyshev(&self, a: usize, b: usize) -> usize {
        let (ar, ac) = self.row_col(a);
        let (br, bc) = self.row_col(b);
        ar.abs_diff(br).max(ac.abs_diff(bc))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn corners_have_three_neighbours() {
        let g = Geometry::new(9, 9);
        assert_eq!(g.neighbours(0).len(), 3);
        assert_eq!(g.neighbours(8).len(), 3);
        assert_eq!(g.neighbours(72).len(), 3);
        assert_eq!(g.neighbours(80).len(), 3);
    }

    #[test]
    fn interior_has_eight_neighbours() {
        let g = Geometry::new(9, 9);
        assert_eq!(g.neighbours(40).len(), 8);
        assert!(g.neighbours(40).contains(&(31)));
    }

    #[test]
    fn chebyshev_distance_is_ring_distance() {
        let g = Geometry::new(9, 9);
        assert_eq!(g.chebyshev(0, 0), 0);
        assert_eq!(g.chebyshev(0, 1), 1);
        assert_eq!(g.chebyshev(0, 10), 1);
    }
}
