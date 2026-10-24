//
//  MacHistoryView.swift
//  MinesweeperMac
//
//  Separate history window (Cmd-Y).  Double-click a record — or use the replay
//  button — to inspect the full move list.
//

import Combine
import SwiftUI

struct MacHistoryView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var history = HistoryManager.shared
    @ObservedObject private var settings = AppSettings.shared

    @State private var selectedRecord: CoreRecord?
    @State private var previewRecord: CoreRecord?

    var body: some View {
        Group {
            if history.records.isEmpty {
                emptyState
            } else {
                List(selection: $selectedRecord) {
                    ForEach(history.records) { record in
                        MacHistoryRow(record: record) {
                            previewRecord = record
                        }
                        .tag(record)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                previewRecord = record
                            }
                            .contextMenu {
                                Button {
                                    previewRecord = record
                                } label: {
                                    Label(localization.text(.replayTitle), systemImage: "play.rectangle")
                                }

                                Button {
                                    history.togglePin(record)
                                } label: {
                                    Label(
                                        record.isPinned
                                            ? localization.text(.unpin)
                                            : localization.text(.pin),
                                        systemImage: record.isPinned ? "pin.slash" : "pin"
                                    )
                                }

                                Divider()

                                Button(role: .destructive) {
                                    history.delete(record)
                                } label: {
                                    Label(localization.text(.delete), systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(localization.text(.historyTitle))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !history.records.isEmpty {
                    Text("\(history.records.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Button {
                    history.syncWithCloud()
                    history.reload()
                    HapticManager.shared.light()
                } label: {
                    Label(localization.text(.syncNow), systemImage: "arrow.triangle.2.circlepath")
                }
                .help(localization.text(.syncNow))
            }
        }
        .sheet(item: $previewRecord) { record in
            MacReplayView(record: record, theme: settings.currentTheme)
        }
        .onAppear {
            history.reload()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary.opacity(0.6))
            Text(localization.text(.noHistory))
                .font(.title3.weight(.semibold))
            Text(localization.text(.noHistoryDesc))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

struct MacHistoryRow: View {
    let record: CoreRecord
    let onReplay: () -> Void

    @ObservedObject private var localization = LocalizationManager.shared

    init(record: CoreRecord, onReplay: @escaping () -> Void) {
        self.record = record
        self.onReplay = onReplay
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.isWin ? "trophy.fill" : "xmark.octagon.fill")
                .font(.title3)
                .foregroundStyle(record.isWin ? .yellow : .red)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if record.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .rotationEffect(.degrees(45))
                    }
                    Text(localization.text(record.isWin ? .win : .lose))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(record.isWin ? .green : .red)
                    Text(record.localizedDifficultyName)
                        .font(.subheadline)
                }
                Text(record.dateValue.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let seed = record.seed {
                Text("#\(seed)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            Button(action: onReplay) {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .help(localization.text(.replayTitle))

            Text(MacReplayTime.format(record.durationSeconds))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}
