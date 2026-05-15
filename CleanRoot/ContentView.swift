//
//  ContentView.swift
//  CleanRoot
//
//  Created by Hüdalfa Bera on 15.05.2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 300)
                .background(SidebarBackground())

            Divider()
                .background(Color.primary.opacity(0.08))

            WebViewContainer()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 980, minHeight: 640)
        .background(WindowAccessor())
    }
}

private struct SidebarBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
            Rectangle().fill(.thinMaterial)
        }
        .ignoresSafeArea()
    }
}

private struct WebViewContainer: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            WebViewRepresentable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(0.5)

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("instagram.com")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.isPageReady ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(appState.isPageReady ? "Connected" : "Loading")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.thinMaterial)
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            if let window = v.window {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)
                window.isMovableByWindowBackground = true
            }
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .frame(width: 1280, height: 820)
}
