//
//  MacReplayView.swift
//  MinesweeperMac
//
//  Replay sheet: instant seeks through the Rust replay engine, scrubbing with
//  the slider, and a single play/pause control.
//

import Combine
import SwiftUI

struct MacReplayView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @StateObject private var viewModel: ReplayViewModel

    let theme: GameTheme
    @Environment(\.dismiss) private var dismiss

    init(record: CoreRecord, theme: GameTheme) {
        self.theme = theme
        _viewModel = StateObject(wrappedValue: ReplayViewModel(record: record))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            GeometryReader { proxy in
                let metrics = BoardMetrics.fitted(
                    in: proxy.size,
                    rows: viewModel.rows,
                    cols: viewModel.cols,
                    minCell: 10,
                    maxCell: 64,
                    padding: 12,
                    spacing: 2
                )
                let contentSize = metrics.size(rows: viewModel.rows, cols: viewModel.cols)

                MacBoardCanvas(
                    cells: viewModel.grid,
                    rows: viewModel.rows,
                    cols: viewModel.cols,
                    theme: theme,
                    isGodMode: false,
                    metrics: metrics,
                    hoveredIndex: nil,
                    animated: false
                )
                .frame(width: contentSize.width, height: contentSize.height)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)
            }

            Divider()

            controls
        }
        .frame(minWidth: 720, minHeight: 620)
        .background(Color.groupedBackground)
        .onDisappear {
            viewModel.stop()
        }
    }

    private var header: some View {
        HStack {
            Button(localization.text(.close)) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Text(localization.text(.replayTitle))
                .font(.headline)

            Spacer()

            Button {
                viewModel.cycleSpeed()
            } label: {
                Text("\(String(format: "%.1f", viewModel.playbackSpeed))×")
                    .font(.callout.monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.07))
                    )
            }
            .buttonStyle(.plain)
            .help(localization.text(.playbackSpeed))
        }
        .padding(12)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Slider(
                value: Binding(
                    get: { viewModel.progress },
                    set: { value in
                        viewModel.seek(to: Int(value * Double(viewModel.movesCount)))
                    }
                )
            )
            .tint(.blue)

            HStack(spacing: 18) {
                Button {
                    viewModel.togglePlay()
                    HapticManager.shared.light()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 34))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .help(viewModel.isPlaying ? "Pause" : "Play")

                Text("\(localization.text(.stepCount)) \(viewModel.currentStepIndex) / \(viewModel.movesCount)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    viewModel.seek(to: 0)
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                .buttonStyle(.borderless)
                .help("0")

                Button {
                    viewModel.seek(to: viewModel.movesCount)
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .buttonStyle(.borderless)
                .help("\(viewModel.movesCount)")
            }
        }
        .padding(16)
    }
}
