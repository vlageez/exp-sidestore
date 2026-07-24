//
//  AltStoreCoreLogging.swift
//  AltStoreCore
//
//  Created by Magesh K on 8/7/26.
//  Copyright © 2026 SideStore. All rights reserved.
//
import Foundation

internal enum AltStoreCoreLogging {
    internal private(set) static var isLoggingEnabled = false

    internal static func setLogging(_ enabled: Bool) {
        isLoggingEnabled = enabled
    }
}

private func getTag(level: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    let timestamp = formatter.string(from: Date())
    return "\(timestamp) \(level): "
}

@inline(__always)
internal func debugLog(_ text: @autoclosure () -> String) {
    let message = text()
    if !message.isEmpty && message.allSatisfy({ $0 == "\n" || $0 == "\r" }) {
        print(message, terminator: "")
    } else {
        print("\(getTag(level: "[D]"))\(message)")
    }
}

@inline(__always)
internal func verboseLog(_ text: @autoclosure () -> String) {
    if AltStoreCoreLogging.isLoggingEnabled {
        let message = text()
        if !message.isEmpty && message.allSatisfy({ $0 == "\n" || $0 == "\r" }) {
            print(message, terminator: "")
        } else {
            print("\(getTag(level: "[V]"))\(message)")
        }
    }
}
