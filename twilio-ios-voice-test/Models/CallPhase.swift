//
//  CallPhase.swift
//  twilio-ios-voice-test
//

import Foundation

enum CallPhase: Equatable {
    case idle
    case requestingMicrophone
    case fetchingToken
    case connecting
    case ringing
    case connected
    case reconnecting
    case disconnecting
    case disconnected
    case failed

    var label: String {
        switch self {
        case .idle:
            return "Idle"
        case .requestingMicrophone:
            return "Requesting microphone"
        case .fetchingToken:
            return "Fetching access token"
        case .connecting:
            return "Connecting"
        case .ringing:
            return "Ringing"
        case .connected:
            return "Connected"
        case .reconnecting:
            return "Reconnecting"
        case .disconnecting:
            return "Disconnecting"
        case .disconnected:
            return "Disconnected"
        case .failed:
            return "Failed"
        }
    }
}
