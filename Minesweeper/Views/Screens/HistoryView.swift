//
//  HistoryView.swift
//  Minesweeper
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var localization = LocalizationManager.shared
    @ObservedObject var historyManager = HistoryManager.shared
    @ObservedObject var settings = AppSettings.shared

    @State private var selectedRecord: CoreRecord?

    var body: some View {
        Group {
            if historyManager.records.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(localization.text(.noHistory))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Text(localization.text(.noHistoryDesc))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                List {
                    ForEach(historyManager.records) { record in
                        Button(action: {
                            selectedRecord = record
                            HapticManager.shared.light()
                        }) {
                            HistoryRow(record: record)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                historyManager.togglePin(record)
                            } label: {
                                Label(
                                    record.isPinned ? localization.text(.unpin) : localization.text(.pin),
                                    systemImage: record.isPinned ? "pin.slash" : "pin"
                                )
                            }
                            .tint(.orange)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation {
                                    historyManager.delete(record)
                                }
                            } label: {
                                Label(localization.text(.delete), systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(localization.text(.historyTitle))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selectedRecord) { record in
            ReplayView(
                viewModel: ReplayViewModel(record: record),
                theme: settings.currentTheme
            )
        }
        .onAppear {
            historyManager.reload()
        }
    }
}

struct HistoryRow: View {
    @ObservedObject var localization = LocalizationManager.shared
    let record: CoreRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    if record.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .rotationEffect(.degrees(45))
                    }
                    Text(record.isWin ? localization.text(.win) : localization.text(.lose))
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(record.isWin ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .foregroundColor(record.isWin ? .green : .red)
                        .cornerRadius(4)

                    Text(record.localizedDifficultyName)
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                Text(record.dateValue.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text("\(record.durationSeconds)s")
                }
                .font(.subheadline)
                .monospacedDigit()

                if let seed = record.seed {
                    Text("#\(seed)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
