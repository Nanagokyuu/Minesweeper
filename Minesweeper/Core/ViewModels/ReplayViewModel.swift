//
//  ReplayViewModel.swift
//  Minesweeper
//
//  Playback clock and SwiftUI bridge.  Seeking is a single synchronous Rust
//  call returning a complete snapshot, so there are no stale delayed callbacks.
//

import SwiftUI
import Combine

@MainActor
final class ReplayViewModel: ObservableObject {
    @Published private(set) var grid: [Cell] = []
    @Published private(set) var isPlaying: Bool = false
    @Published var playbackSpeed: Double = 1.0
    @Published private(set) var currentStepIndex: Int = 0

    let rows: Int
    let cols: Int
    let movesCount: Int

    private let replay: CoreReplay
    private var timerTask: Task<Void, Never>?

    var progress: Double {
        guard movesCount > 0 else { return 0 }
        return Double(currentStepIndex) / Double(movesCount)
    }

    init(record: CoreRecord) {
        replay = CoreReplay(record: record)
        movesCount = Int(replay.stepCount())
        let snapshot = replay.seek(step: 0)
        rows = Int(snapshot.rows)
        cols = Int(snapshot.cols)
        grid = snapshot.makeCells()
    }

    // MARK: - Playback controls
    func togglePlay() {
        if isPlaying {
            stopTimer()
            isPlaying = false
        } else {
            guard currentStepIndex < movesCount else { return }
            isPlaying = true
            startTimer()
        }
    }

    func seek(to step: Int) {
        stopTimer()
        isPlaying = false
        apply(step: max(0, min(step, movesCount)))
    }

    func stop() {
        stopTimer()
        isPlaying = false
    }

    func cycleSpeed() {
        if playbackSpeed == 1.0 {
            playbackSpeed = 2.0
        } else if playbackSpeed == 2.0 {
            playbackSpeed = 4.0
        } else {
            playbackSpeed = 1.0
        }
        if isPlaying {
            startTimer()
        }
    }

    // MARK: - Internal
    private func apply(step: Int) {
        let clamped = max(0, min(step, movesCount))
        let snapshot = replay.seek(step: UInt32(clamped))
        grid = snapshot.makeCells()
        currentStepIndex = clamped
    }

    private func startTimer() {
        stopTimer()
        let nanoseconds = UInt64((0.5 / playbackSpeed) * 1_000_000_000)
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard let self, !Task.isCancelled, self.isPlaying else { return }
                self.tick()
            }
        }
    }

    private func tick() {
        guard isPlaying else { return }
        if currentStepIndex < movesCount {
            apply(step: currentStepIndex + 1)
        } else {
            stopTimer()
            isPlaying = false
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
