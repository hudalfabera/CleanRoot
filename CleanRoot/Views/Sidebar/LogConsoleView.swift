//
//  LogConsoleView.swift
//  cleanroot
//

import SwiftUI

struct LogConsoleView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            consoleBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("ACTIVITY")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.7)
            Spacer()
            Button {
                appState.clearLogs()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Clear log")
            .disabled(appState.logs.isEmpty)
        }
        .padding(.horizontal, 6)
    }

    // MARK: - Body

    private var consoleBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    if appState.logs.isEmpty {
                        emptyState
                    } else {
                        ForEach(appState.logs) { entry in
                            LogRow(entry: entry).id(entry.id)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            .onChange(of: appState.logs.count) { _, _ in
                guard let lastID = appState.logs.last?.id else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Waiting for activity")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Log row

private struct LogRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(entry.level.color)
                .frame(width: 5, height: 5)
                .padding(.top, 7)

            Text(entry.formattedTimestamp)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.top, 3)

            Text(cleanedMessage)
                .font(.system(size: 11.5))
                .foregroundStyle(.primary.opacity(0.85))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 1)
        }
        .padding(.vertical, 2)
    }

    private var cleanedMessage: String {
        let scalars = entry.message.unicodeScalars
        guard let firstScalar = scalars.first,
              firstScalar.properties.isEmojiPresentation || firstScalar.properties.isEmoji else {
            return entry.message
        }
        return entry.message
            .drop(while: { !$0.isLetter && !$0.isNumber })
            .description
    }
}

#Preview {
    let state = AppState()
    state.appendLog("🚀 Advanced Mass Unliker started")
    state.appendLog("📌 Selecting 10 likes")
    state.appendLog("🗑️ Deleting selected items")
    state.appendLog("🛑 Rate limit detected! Waiting 10s")
    state.appendLog("🎉 No more likes found")
    return LogConsoleView()
        .environmentObject(state)
        .frame(width: 280, height: 400)
}
