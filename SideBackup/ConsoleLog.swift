//
//  ConsoleLog.swift
//  SideBackup
//
//  Created by Magesh K on 2/7/26.
//  Copyright © 2026 SideStore. All rights reserved.

import Foundation
import OSLog

final class ConsoleLog: Sendable {
    static let shared = ConsoleLog()
    
    private let logger = Logger(subsystem: "io.sidestore.SideBackup", category: "General")
    private let logFileURL: URL?
    
    private init() {
        self.logFileURL = Self.determineLogFileURL()
        
        // Auto-clear the log file on first initialization of the singleton
        if let url = self.logFileURL {
            try? "".write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private static func determineLogFileURL() -> URL? {
        guard let appGroup = Bundle.main.altstoreAppGroup,
              let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return nil
        }
        let logsDir = containerURL.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        return logsDir.appendingPathComponent("SideBackup.log")
    }
    
    func log(_ message: String, terminator: String = "\n") {
        // 1. Log to Apple's OSLog
        logger.info("\(message)")
        
        // 2. Append to shared file in App Group
        guard let url = logFileURL else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            if let data = (message + terminator).data(using: .utf8) {
                try? handle.write(contentsOf: data)
            }
        } else {
            // Create file if it doesn't exist
            try? (message + terminator).write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

private func getTag(level: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    let timestamp = formatter.string(from: Date())
    let padding = level == "DEBUG" ? " " : "  "
    return "\(timestamp) \(level)\(padding): "
}

// Global print override to shadow Swift's standard print
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let message = items.map { "\($0)" }.joined(separator: separator)
    if !message.isEmpty && message.allSatisfy({ $0 == "\n" || $0 == "\r" }) {
        ConsoleLog.shared.log(message, terminator: "")
    } else {
        ConsoleLog.shared.log("\(getTag(level: "[D]"))\(message)", terminator: terminator)
    }
}
