//
//  ControlPanel.swift
//  cleanroot
//

import SwiftUI

struct ControlPanel: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 8) {
            startButton
            HStack(spacing: 8) {
                stopButton
                reloadLikesButton
            }
        }
    }

    // MARK: - Start

    private var startButton: some View {
        Button(action: { appState.start() }) {
            HStack(spacing: 7) {
                Image(systemName: appState.isRunning ? "waveform" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .symbolEffect(.variableColor, isActive: appState.isRunning)
                Text(appState.isRunning ? "Running…" : "Start Unliking")
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundStyle(.white)
            .background(buttonBackground)
        }
        .buttonStyle(.plain)
        .disabled(appState.isRunning || !appState.isPageReady)
        .animation(.easeInOut(duration: 0.18), value: appState.isRunning)
        .animation(.easeInOut(duration: 0.18), value: appState.isPageReady)
    }

    private var buttonBackground: some View {
        let disabled = appState.isRunning || !appState.isPageReady
        return RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(
                disabled
                ? AnyShapeStyle(Color.primary.opacity(0.15))
                : AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.97, green: 0.46, blue: 0.22),
                            Color(red: 0.88, green: 0.19, blue: 0.42),
                            Color(red: 0.51, green: 0.23, blue: 0.71)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
    }

    // MARK: - Stop

    private var stopButton: some View {
        Button(action: { appState.stop() }) {
            HStack(spacing: 6) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Stop")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(appState.isRunning ? Color.red : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(
                        appState.isRunning ? Color.red.opacity(0.4) : Color.primary.opacity(0.1),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!appState.isRunning)
        .animation(.easeInOut(duration: 0.15), value: appState.isRunning)
    }

    // MARK: - Reload Likes

    private var reloadLikesButton: some View {
        Button(action: { appState.goToLikes() }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .bold))
                Text("Reload")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(.secondary)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(!appState.isPageReady || appState.isRunning)
        .help("Reload the Likes page")
    }
}

#Preview {
    ControlPanel()
        .environmentObject(AppState())
        .padding()
        .frame(width: 280)
}
