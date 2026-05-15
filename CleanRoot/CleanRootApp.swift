//
//  CleanRootApp.swift
//  CleanRoot
//
//  Created by Hüdalfa Bera on 15.05.2026.
//
import SwiftUI

@main
struct CleanRootApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1280, height: 800)
    }
}
