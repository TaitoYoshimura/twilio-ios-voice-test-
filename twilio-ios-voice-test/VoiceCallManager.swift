//
//  VoiceCallManager.swift
//  twilio-ios-voice-test
//
//  Created by Codex on 2026/06/09.
//

import AVFoundation
import Combine
import Foundation
import TwilioVoice

@MainActor
final class VoiceCallManager: NSObject, ObservableObject {
    enum Phase: Equatable {
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

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lastError: String?
    @Published private(set) var activeCallUUID: String?
    @Published var isMuted = false {
        didSet {
            activeCall?.isMuted = isMuted
        }
    }
    @Published var isSpeakerEnabled = true {
        didSet {
            updateAudioRoute()
        }
    }

    private var activeCall: Call?
    private let audioDevice = DefaultAudioDevice()

    var canStartCall: Bool {
        activeCall == nil && !isBusy
    }

    var canHangUp: Bool {
        activeCall != nil
    }

    var isBusy: Bool {
        switch phase {
        case .requestingMicrophone, .fetchingToken, .connecting, .disconnecting:
            return true
        case .idle, .ringing, .connected, .reconnecting, .disconnected, .failed:
            return false
        }
    }

    override init() {
        super.init()
        TwilioVoiceSDK.audioDevice = audioDevice
    }

    func startCall(
        tokenEndpoint: String,
        localTokenFactory: TwilioVoiceAccessTokenFactory?,
        identity: String,
        phoneNumber: String,
        callerID: String
    ) async {
        guard canStartCall else {
            return
        }

        let trimmedNumber = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedNumber.isE164PhoneNumber else {
            fail(with: "Phone number must be E.164 format, for example +819012345678.")
            return
        }

        let trimmedCallerID = callerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCallerID.isEmpty || trimmedCallerID.isE164PhoneNumber else {
            fail(with: "Caller ID must be E.164 format, for example +819012345678.")
            return
        }

        do {
            lastError = nil
            phase = .requestingMicrophone

            guard await requestMicrophoneAccess() else {
                throw VoiceCallError.microphoneDenied
            }

            phase = .fetchingToken
            let trimmedIdentity = identity.trimmingCharacters(in: .whitespacesAndNewlines)
            let accessToken = try await resolveAccessToken(
                tokenEndpoint: tokenEndpoint,
                localTokenFactory: localTokenFactory,
                identity: trimmedIdentity
            )

            phase = .connecting
            let connectOptions = ConnectOptions(accessToken: accessToken) { builder in
                var params = ["To": trimmedNumber]
                if !trimmedCallerID.isEmpty {
                    params["CallerId"] = trimmedCallerID
                }

                builder.params = params
                builder.uuid = UUID()
            }

            let call = TwilioVoiceSDK.connect(options: connectOptions, delegate: self)
            activeCall = call
            activeCallUUID = call.uuid?.uuidString
            isMuted = false
            updateAudioRoute()
        } catch {
            fail(with: error.localizedDescription)
        }
    }

    func hangUp() {
        guard let activeCall else {
            return
        }

        phase = .disconnecting
        activeCall.disconnect()
    }

    private func resolveAccessToken(
        tokenEndpoint: String,
        localTokenFactory: TwilioVoiceAccessTokenFactory?,
        identity: String
    ) async throws -> String {
        let trimmedEndpoint = tokenEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEndpoint.isEmpty {
            return try await fetchAccessToken(from: trimmedEndpoint, identity: identity)
        }

        if let localTokenFactory {
            return try localTokenFactory.makeAccessToken(identity: identity)
        }

        throw VoiceCallError.missingTokenSource
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    private func fetchAccessToken(from endpoint: String, identity: String) async throws -> String {
        let tokenURL = try makeTokenURL(from: endpoint, identity: identity)
        let (data, response) = try await URLSession.shared.data(from: tokenURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceCallError.invalidTokenResponse("Token endpoint did not return an HTTP response.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw VoiceCallError.invalidTokenResponse("Token endpoint returned HTTP \(httpResponse.statusCode). \(body)")
        }

        if let tokenResponse = try? JSONDecoder().decode(TokenResponse.self, from: data),
           !tokenResponse.token.isEmpty {
            return tokenResponse.token
        }

        if let rawToken = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")),
           rawToken.split(separator: ".").count == 3 {
            return rawToken
        }

        throw VoiceCallError.invalidTokenResponse("Token endpoint response must include a token field.")
    }

    private func makeTokenURL(from endpoint: String, identity: String) throws -> URL {
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmedEndpoint),
              components.scheme == "https" || components.scheme == "http",
              components.host != nil else {
            throw VoiceCallError.invalidTokenEndpoint
        }

        if !identity.isEmpty {
            var queryItems = components.queryItems ?? []
            if !queryItems.contains(where: { $0.name == "identity" }) {
                queryItems.append(URLQueryItem(name: "identity", value: identity))
                components.queryItems = queryItems
            }
        }

        guard let url = components.url else {
            throw VoiceCallError.invalidTokenEndpoint
        }

        return url
    }

    private func updateAudioRoute() {
        audioDevice.block = { [isSpeakerEnabled] in
            do {
                try AVAudioSession.sharedInstance().overrideOutputAudioPort(isSpeakerEnabled ? .speaker : .none)
            } catch {
                NSLog("Failed to update audio route: \(error.localizedDescription)")
            }
        }
        audioDevice.block()
    }

    private func fail(with message: String) {
        activeCall = nil
        activeCallUUID = nil
        phase = .failed
        lastError = message
    }

    private func clearActiveCall(disconnectedWithError error: Error?) {
        activeCall = nil
        activeCallUUID = nil
        phase = error == nil ? .disconnected : .failed
        lastError = error?.localizedDescription
        isMuted = false
    }
}

extension VoiceCallManager: CallDelegate {
    nonisolated func callDidStartRinging(call: Call) {
        Task { @MainActor [weak self] in
            self?.phase = .ringing
            self?.activeCallUUID = call.uuid?.uuidString
        }
    }

    nonisolated func callDidConnect(call: Call) {
        Task { @MainActor [weak self] in
            self?.phase = .connected
            self?.activeCallUUID = call.uuid?.uuidString
            self?.updateAudioRoute()
        }
    }

    nonisolated func callIsReconnecting(call: Call, error: Error) {
        Task { @MainActor [weak self] in
            self?.phase = .reconnecting
            self?.lastError = error.localizedDescription
        }
    }

    nonisolated func callDidReconnect(call: Call) {
        Task { @MainActor [weak self] in
            self?.phase = .connected
            self?.lastError = nil
        }
    }

    nonisolated func callDidFailToConnect(call: Call, error: Error) {
        Task { @MainActor [weak self] in
            self?.clearActiveCall(disconnectedWithError: error)
        }
    }

    nonisolated func callDidDisconnect(call: Call, error: Error?) {
        Task { @MainActor [weak self] in
            self?.clearActiveCall(disconnectedWithError: error)
        }
    }
}

private struct TokenResponse: Decodable {
    let token: String
}

private enum VoiceCallError: LocalizedError {
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

private extension String {
    var isE164PhoneNumber: Bool {
        let pattern = #"^\+[1-9]\d{7,14}$"#
        return range(of: pattern, options: .regularExpression) != nil
    }
}
