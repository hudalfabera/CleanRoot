//
//  LogEntry.swift
//  cleanroot
//

import SwiftUI

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let level: Level

    enum Level: String {
        case info, success, warning, error, system

        var color: Color {
            switch self {
            case .info:    return Color(nsColor: .systemBlue)
            case .success: return Color(nsColor: .systemGreen)
            case .warning: return Color(nsColor: .systemOrange)
            case .error:   return Color(nsColor: .systemRed)
            case .system:  return Color(nsColor: .systemPurple)
            }
        }
    }

    static func inferring(from raw: String) -> LogEntry {
        let level: Level
        switch raw {
        case _ where raw.contains("❌") || raw.contains("Fatal"):  level = .error
        case _ where raw.contains("🛑") || raw.contains("Rate"):  level = .warning
        case _ where raw.contains("🎉") || raw.contains("✅") ||
                     raw.contains("🏁"):                            level = .success
        case _ where raw.contains("🚀"):                            level = .system
        default:                                                    level = .info
        }
        return LogEntry(timestamp: Date(), message: raw, level: level)
    }

    var formattedTimestamp: String {
        Self.formatter.string(from: timestamp)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
