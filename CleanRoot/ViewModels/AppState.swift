//
//  AppState.swift
//  CleanRoot
//

import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published State

    @Published private(set) var logs: [LogEntry] = []
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isPageReady: Bool = false
    @Published private(set) var isLoggedIn: Bool = false
    @Published private(set) var unlikedCount: Int = 0

    // MARK: - Internal

    private var hasAutoNavigatedToLikes: Bool = false
    private let maxLogLines: Int = 1_000

    // MARK: - Command signals to WebView

    let startSignal     = PassthroughSubject<Void, Never>()
    let stopSignal      = PassthroughSubject<Void, Never>()
    let goToLikesSignal = PassthroughSubject<Void, Never>()

    // MARK: - Public API

    func appendLog(_ raw: String) {
        let entry = LogEntry.inferring(from: raw)
        append(entry)
        if raw.contains("Removed") {
            if let n = extractFirstInt(from: raw) {
                unlikedCount += n
            }
        }
    }

    func appendLog(_ message: String, level: LogEntry.Level) {
        append(LogEntry(timestamp: Date(), message: message, level: level))
    }

    func appendLog(_ message: String, levelRaw: String) {
        let level: LogEntry.Level
        switch levelRaw.lowercased() {
        case "success": level = .success
        case "warning": level = .warning
        case "error":   level = .error
        case "system":  level = .system
        default:        level = .info
        }
        appendLog(message, level: level)
        if message.contains("Removed") {
            if let n = extractFirstInt(from: message) {
                unlikedCount += n
            }
        }
    }

    func clearLogs() {
        logs.removeAll()
        appendLog("Log cleared.", level: .system)
    }

    func resetCounter() {
        unlikedCount = 0
    }

    func start() {
        guard !isRunning else { return }
        guard isPageReady else {
            appendLog("Page is still loading — please wait.", level: .warning)
            return
        }
        isRunning = true
        appendLog("Starting unliker…", level: .system)
        startSignal.send()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        appendLog("Stop requested by user.", level: .warning)
        stopSignal.send()
    }

    func goToLikes() {
        appendLog("Navigating to Likes…", level: .system)
        goToLikesSignal.send()
    }

    func reportRunFinished(reason: String) {
        isRunning = false
        let message: String
        let level: LogEntry.Level
        switch reason {
        case "completed": message = "Run finished successfully."; level = .success
        case "stopped":   message = "Run stopped.";              level = .warning
        case "error":     message = "Run ended with an error.";  level = .error
        default:          message = "Run finished: \(reason).";  level = .info
        }
        appendLog(message, level: level)
    }

    func reportRunFinished() {
        guard isRunning else { return }
        isRunning = false
    }

    func setPageReady(_ ready: Bool) {
        isPageReady = ready
    }

    func reportLoginState(_ loggedIn: Bool) -> Bool {
        isLoggedIn = loggedIn
        if loggedIn && !hasAutoNavigatedToLikes {
            hasAutoNavigatedToLikes = true
            appendLog("Login detected — opening Likes page.", level: .system)
            return true
        }
        return false
    }

    func resetAutoNavigation() {
        hasAutoNavigatedToLikes = false
    }

    // MARK: - Private

    private func append(_ entry: LogEntry) {
        logs.append(entry)
        if logs.count > maxLogLines {
            logs.removeFirst(logs.count - maxLogLines)
        }
    }

    private func extractFirstInt(from text: String) -> Int? {
        let pattern = #"\d+"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return Int(text[range])
    }
}
