//
//  MinesweeperGame.swift
//  Minesweeper
//
//  Thin SwiftUI adapter around the Rust `CoreGame`.  All rules, board
//  generation, win/loss checks, replay data and history records live in Rust.
//

import SwiftUI
import Combine

@MainActor
final class MinesweeperGame: ObservableObject {
    // MARK: - Published state
    @Published private(set) var difficulty: Difficulty
    /// One atomic publish for cells/status/counters.  The clock is separate so
    /// its once-per-second updates do not invalidate the board.
    @Published private(set) var state = GameBoardState()
    @Published var showResult: Bool = false

    let currentTheme: GameTheme
    let isGodMode: Bool
    let isNanagokyuuMode: Bool
    let clock = GameClock()

    // MARK: - Rust core
    private var core: CoreGame
    private var timerTask: Task<Void, Never>?
    private var effectTasks: [Task<Void, Never>] = []
    private var generation: Int = 0

    // MARK: - Init
    init(
        difficulty: Difficulty = .easy,
        theme: GameTheme? = nil,
        seed: Int? = nil,
        isGodMode: Bool = false,
        isNanagokyuuMode: Bool = false
    ) {
        self.difficulty = difficulty
        self.currentTheme = theme ?? .classic
        self.isGodMode = isGodMode
        self.isNanagokyuuMode = isNanagokyuuMode
        self.core = Self.makeCore(
            difficulty: difficulty,
            seed: seed,
            godMode: isGodMode,
            nanagokyuu: isNanagokyuuMode
        )
        apply(core.snapshot(), handleEffects: false)
    }

    // MARK: - Read-only view state
    var rows: Int { state.rows > 0 ? state.rows : difficulty.rows }
    var cols: Int { state.cols > 0 ? state.cols : difficulty.cols }
    var grid: [Cell] { state.cells }
    var gameStatus: GameStatus { state.status }
    var currentSeed: Int { state.seed }
    var remainingMines: Int { state.remainingMines }
    var started: Bool { state.started }
    var timeElapsed: Int { clock.elapsed }

    // MARK: - Public API used by the views
    func startNewGame(with seed: Int? = nil) {
        cancelEffects()
        stopTimer()
        clock.reset()
        showResult = false
        generation &+= 1
        core = Self.makeCore(
            difficulty: difficulty,
            seed: seed,
            godMode: isGodMode,
            nanagokyuu: isNanagokyuuMode
        )
        apply(core.snapshot(), handleEffects: false)
    }

    func revealCell(at index: Int) {
        guard gameStatus == .playing, index >= 0, index < state.cells.count else { return }
        apply(core.apply(action: .reveal(index: UInt32(index))), handleEffects: true)
    }

    func toggleFlag(at index: Int) {
        guard gameStatus == .playing, index >= 0, index < state.cells.count else { return }
        apply(core.apply(action: .toggleFlag(index: UInt32(index))), handleEffects: true)
    }

    func quickReveal(at index: Int) {
        guard gameStatus == .playing, index >= 0, index < state.cells.count else { return }
        apply(core.apply(action: .chord(index: UInt32(index))), handleEffects: true)
    }

    // MARK: - Lifecycle
    func stop() {
        cancelEffects()
        stopTimer()
    }

    func pause() {
        stopTimer()
    }

    func resume() {
        guard gameStatus == .playing, started else { return }
        startTimerIfNeeded()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            resume()
        case .inactive, .background:
            pause()
        @unknown default:
            break
        }
    }

    // MARK: - Snapshot application
    private func apply(_ snapshot: CoreSnapshot, handleEffects: Bool) {
        var cells = snapshot.makeCells()
        if state.cells.count == cells.count {
            // Keep the delay that already played for previously revealed
            // cells.  Otherwise every flag tap would reset all delays and make
            // every CellView non-equal, forcing a 720-cell re-render.
            for index in cells.indices where state.cells[index].isRevealed && cells[index].isRevealed {
                cells[index].animationDelay = state.cells[index].animationDelay
            }
        }

        let status: GameStatus
        switch snapshot.status {
        case .playing:
            status = .playing
        case .won:
            status = .won
        case .lost:
            // Keep the board interaction-disabled while the Rust explosion
            // plan is played by Swift.  `ShowResult` flips this to .lost.
            status = snapshot.effects.isEmpty ? .lost : .exploding
        }

        // A single atomic publish for all board-related state.
        state = GameBoardState(
            cells: cells,
            status: status,
            seed: Int(snapshot.seed),
            remainingMines: max(0, Int(snapshot.minesCount) - Int(snapshot.flagsCount)),
            started: snapshot.started,
            rows: Int(snapshot.rows),
            cols: Int(snapshot.cols)
        )

        // The clock is a separate observable, observed only by the header.
        // Rust caps elapsed time; mirror it exactly instead of letting the
        // header and the saved record drift apart.
        clock.set(Int(snapshot.elapsed))

        switch status {
        case .playing:
            if snapshot.started {
                startTimerIfNeeded()
            }
        case .won, .lost, .exploding:
            stopTimer()
        }

        if let record = snapshot.finishedRecord {
            HistoryManager.shared.save(record)
        }
        if handleEffects {
            handle(effects: snapshot.effects)
        }
    }

    // MARK: - Effects (the only place Rust decisions touch platform APIs)
    private func handle(effects: [CoreEffect]) {
        let currentGeneration = generation
        for effect in effects {
            switch effect {
            case let .haptic(kind, delayMs):
                schedule(delayMs, generation: currentGeneration) {
                    switch kind {
                    case .light: HapticManager.shared.light()
                    case .heavy: HapticManager.shared.heavy()
                    case .success: HapticManager.shared.success()
                    case .failure: HapticManager.shared.failure()
                    }
                }

            case let .explosionWave(delayMs, indices):
                schedule(delayMs, generation: currentGeneration) { [weak self] in
                    guard let self else { return }
                    self.setExploding(indices, true)
                    self.schedule(250, generation: currentGeneration) { [weak self] in
                        self?.setExploding(indices, false)
                    }
                }

            case let .showResult(win, delayMs):
                schedule(delayMs, generation: currentGeneration) { [weak self] in
                    guard let self else { return }
                    var updated = self.state
                    updated.status = win ? .won : .lost
                    if updated != self.state {
                        self.state = updated
                    }
                    withAnimation(.spring()) {
                        self.showResult = true
                    }
                }
            }
        }
    }

    private func schedule(
        _ delayMs: UInt32,
        generation: Int,
        _ action: @escaping @MainActor () -> Void
    ) {
        if delayMs == 0 {
            guard generation == self.generation else { return }
            action()
            return
        }
        let task = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            guard let self, !Task.isCancelled, self.generation == generation else { return }
            action()
        }
        effectTasks.append(task)
    }

    private func setExploding(_ indices: [UInt32], _ value: Bool) {
        var updated = state
        var changed = false
        for rawIndex in indices {
            let index = Int(rawIndex)
            if index >= 0 && index < updated.cells.count && updated.cells[index].isExploding != value {
                updated.cells[index].isExploding = value
                changed = true
            }
        }
        if changed {
            // One publish for the whole wave instead of one per cell.
            state = updated
        }
    }

    private func cancelEffects() {
        generation &+= 1
        effectTasks.forEach { $0.cancel() }
        effectTasks.removeAll(keepingCapacity: true)
        if state.cells.contains(where: { $0.isExploding }) {
            var updated = state
            for index in updated.cells.indices {
                updated.cells[index].isExploding = false
            }
            state = updated
        }
    }

    // MARK: - Timer
    private func startTimerIfNeeded() {
        guard timerTask == nil, gameStatus == .playing, started else { return }
        timerTask = Task { @MainActor [weak self] in
            var last = Date()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled, self.gameStatus == .playing else { return }
                let now = Date()
                let delta = max(1, min(Int(now.timeIntervalSince(last).rounded()), 5))
                last = now
                self.tick(seconds: delta)
            }
        }
    }

    private func tick(seconds: Int) {
        // Rust owns the clock and the 99:59 cap; using its return value keeps
        // the header and the history record in sync.
        let elapsed = core.advanceTime(seconds: UInt32(seconds))
        clock.set(Int(elapsed))
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Config
    private static func makeCore(
        difficulty: Difficulty,
        seed: Int?,
        godMode: Bool,
        nanagokyuu: Bool
    ) -> CoreGame {
        CoreGame(
            config: CoreConfig(
                difficulty: difficulty.core,
                seed: seed.map(Int64.init),
                batteryPercent: batteryPercent,
                noGuessing: difficulty != .hell && AppSettings.shared.isNoGuessingEnabled,
                godMode: godMode,
                nanagokyuu: nanagokyuu
            )
        )
    }

    private static var batteryPercent: Int32 {
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return level >= 0 ? Int32((level * 100).rounded()) : 100
        #else
        // Macs have no battery input for the seed mix; the seed already uses
        // time and nanoseconds, so a constant here only changes distribution.
        return 100
        #endif
    }
}
