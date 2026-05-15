//
//  SidebarView.swift
//  Cleanroot
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Top padding for traffic lights
            Color.clear.frame(height: 36)

            header
                .padding(.horizontal, 18)
                .padding(.bottom, 16)

            statsCard
                .padding(.horizontal, 18)
                .padding(.bottom, 14)

            ControlPanel()
                .padding(.horizontal, 18)
                .padding(.bottom, 18)

            Divider().opacity(0.5)
                .padding(.horizontal, 18)

            LogConsoleView()
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 14)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 11) {
            Image("SidebarIcon")
                .resizable()
                .interpolation(.high)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 1) {
                Text("Cleanroot")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("clean your feed")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusPill(isRunning: appState.isRunning, isPageReady: appState.isPageReady)
        }
    }

    // MARK: - Stats card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UNLIKED THIS SESSION")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.7)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(appState.unlikedCount)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(value: Double(appState.unlikedCount)))
                    .animation(.spring(response: 0.4), value: appState.unlikedCount)
                Text("posts")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Animated progress shimmer when running
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.97, green: 0.46, blue: 0.22),
                                    Color(red: 0.51, green: 0.23, blue: 0.71)
                                ],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: appState.isRunning ? geo.size.width : 0, height: 3)
                        .animation(.easeOut(duration: 0.4), value: appState.isRunning)
                }
            }
            .frame(height: 3)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Status pill

private struct StatusPill: View {
    let isRunning: Bool
    let isPageReady: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(color.opacity(0.12))
        )
    }

    private var color: Color {
        if isRunning { return .green }
        if isPageReady { return .blue }
        return .orange
    }

    private var text: String {
        if isRunning { return "Running" }
        if isPageReady { return "Ready" }
        return "Loading"
    }
}

#Preview {
    SidebarView()
        .environmentObject(AppState())
        .frame(width: 300, height: 820)
}
