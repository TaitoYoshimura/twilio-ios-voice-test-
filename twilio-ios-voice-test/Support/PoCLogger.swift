//
//  PoCLogger.swift
//  twilio-ios-voice-test
//
//  Created by Codex on 2026/06/10.
//

import Foundation

enum PoCLogger {
    static func info(_ message: String) {
        print("[TwilioVoicePoC] \(message)")
    }

    static func error(_ message: String) {
        print("[TwilioVoicePoC][ERROR] \(message)")
    }

    static func present(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "missing" : "set"
    }

    static func maskedSID(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else {
            return trimmed.isEmpty ? "missing" : "set"
        }

        return "\(trimmed.prefix(2))...\(trimmed.suffix(6))"
    }
}
