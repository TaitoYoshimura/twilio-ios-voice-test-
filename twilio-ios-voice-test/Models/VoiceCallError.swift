//
//  VoiceCallError.swift
//  twilio-ios-voice-test
//

import Foundation

enum VoiceCallError: LocalizedError {
    case invalidTokenEndpoint
    case invalidTokenResponse(String)
    case missingTokenSource
    case microphoneDenied

    var errorDescription: String? {
        switch self {
        case .invalidTokenEndpoint:
            return "Token endpoint must be a valid HTTP or HTTPS URL."
        case .invalidTokenResponse(let message):
            return message
        case .missingTokenSource:
            return "Set TOKEN_ENDPOINT or local Twilio credentials in .env."
        case .microphoneDenied:
            return "Microphone permission is required for a voice call."
        }
    }
}
