//
//  PlayerInitLogger.swift
//  Electric Slideshow
//
//  Thread-safe logger for collecting Spotify player initialization logs
//  to be displayed in an alert when initialization fails.
//

import Foundation
import Combine

/// Thread-safe logger for collecting player initialization logs
@MainActor
final class PlayerInitLogger: ObservableObject {
    static let shared = PlayerInitLogger()
    
    @Published private(set) var logs: [LogEntry] = []
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    private init() {}
    
    /// Appends a log message with timestamp and source
    /// - Parameters:
    ///   - message: The log message
    ///   - source: The source component (e.g., "SpotifyAuth", "InternalPlayerManager")
    func log(_ message: String, source: String) {
        let entry = LogEntry(
            timestamp: Date(),
            source: source,
            message: message
        )
        logs.append(entry)
    }
    
    /// Returns a formatted string of all logs suitable for display
    func formattedLogs() -> String {
        guard !logs.isEmpty else {
            return "No logs available"
        }
        
        return logs.map { entry in
            let time = dateFormatter.string(from: entry.timestamp)
            return "[\(time)] [\(entry.source)] \(entry.message)"
        }.joined(separator: "\n")
    }
    
    /// Clears all collected logs
    func clearLogs() {
        logs.removeAll()
    }
}

/// A single log entry with timestamp, source, and message
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let source: String
    let message: String
}