//
//  CallViewModel.swift
//  twilio-ios-voice-test
//

import Combine
import Foundation

@MainActor
final class CallViewModel: ObservableObject {
    @Published var tokenEndpoint: String
    @Published var identity: String
    @Published var phoneNumber: String
    @Published var callerID: String

    @Published private(set) var phase: CallPhase = .idle {
        didSet {
            guard oldValue != phase else {
                return
            }
            PoCLogger.info("phase \(oldValue.label) -> \(phase.label)")
        }
    }
    @Published private(set) var lastError: String?
    @Published private(set) var activeCallUUID: String?
    @Published private(set) var hasActiveCall = false
    @Published var isMuted = false {
        didSet {
            callService.setMuted(isMuted)
        }
    }
    @Published var isSpeakerEnabled = true {
        didSet {
            callService.setSpeakerEnabled(isSpeakerEnabled)
        }
    }

    private let environment: AppEnvironment
    private let callService: VoiceCallService
    private let microphoneService: MicrophonePermissionService

    init(
        environment: AppEnvironment? = nil,
        callService: VoiceCallService? = nil,
        microphoneService: MicrophonePermissionService? = nil
    ) {
        let environment = environment ?? .load()
        self.environment = environment
        self.callService = callService ?? VoiceCallService()
        self.microphoneService = microphoneService ?? MicrophonePermissionService()
        tokenEndpoint = environment.tokenEndpoint
        identity = environment.defaultIdentity
        phoneNumber = environment.defaultToNumber
        callerID = environment.callerID

        self.callService.onEvent = { [weak self] event in
            self?.handle(event)
        }
    }

    var canStartCall: Bool {
        !hasActiveCall &&
        !isBusy &&
        hasTokenSource &&
        !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canHangUp: Bool {
        hasActiveCall
    }

    var isBusy: Bool {
        switch phase {
        case .requestingMicrophone, .fetchingToken, .connecting, .disconnecting:
            return true
        case .idle, .ringing, .connected, .reconnecting, .disconnected, .failed:
            return false
        }
    }

    var tokenSourceLabel: String {
        if !tokenEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Token URL"
        }

        if environment.hasLocalTokenCredentials {
            return "Local .env"
        }

        return "Missing"
    }

    private var hasTokenSource: Bool {
        environment.hasLocalTokenCredentials ||
        !tokenEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func startCall() async {
        guard !hasActiveCall && !isBusy else {
            PoCLogger.info("startCall ignored because another call operation is active phase=\(phase.label)")
            return
        }

        let trimmedNumber = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCallerID = callerID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIdentity = identity.trimmingCharacters(in: .whitespacesAndNewlines)
        PoCLogger.info(
            "startCall requested identity=\(trimmedIdentity) " +
            "to=\(trimmedNumber) callerID=\(trimmedCallerID.isEmpty ? "empty" : trimmedCallerID) " +
            "tokenEndpoint=\(PoCLogger.present(tokenEndpoint)) " +
            "localTokenFactory=\(environment.hasLocalTokenCredentials ? "set" : "missing")"
        )

        guard trimmedNumber.isE164PhoneNumber else {
            PoCLogger.error("invalid To number format: \(trimmedNumber)")
            fail(with: "Phone number must be E.164 format, for example +819012345678.")
            return
        }

        guard trimmedCallerID.isEmpty || trimmedCallerID.isE164PhoneNumber else {
            PoCLogger.error("invalid Caller ID format: \(trimmedCallerID)")
            fail(with: "Caller ID must be E.164 format, for example +819012345678.")
            return
        }

        do {
            lastError = nil
            phase = .requestingMicrophone

            guard await microphoneService.requestAccess() else {
                throw VoiceCallError.microphoneDenied
            }

            phase = .fetchingToken
            let tokenProvider = try makeAccessTokenProvider()
            let accessToken = try await tokenProvider.accessToken(identity: trimmedIdentity)
            PoCLogger.info("access token resolved length=\(accessToken.count)")

            phase = .connecting
            activeCallUUID = callService.connect(
                accessToken: accessToken,
                to: trimmedNumber,
                callerID: trimmedCallerID.isEmpty ? nil : trimmedCallerID
            )
            hasActiveCall = true
            isMuted = false
        } catch {
            PoCLogger.error("startCall failed: \(error.localizedDescription)")
            fail(with: error.localizedDescription)
        }
    }

    func hangUp() {
        guard hasActiveCall else {
            PoCLogger.info("hangUp ignored because activeCall is nil")
            return
        }

        phase = .disconnecting
        callService.disconnect()
    }

    private func makeAccessTokenProvider() throws -> AccessTokenProviding {
        let trimmedEndpoint = tokenEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEndpoint.isEmpty {
            return RemoteAccessTokenProvider(endpoint: trimmedEndpoint)
        }

        if let factory = environment.localTokenFactory {
            return LocalAccessTokenProvider(factory: factory)
        }

        PoCLogger.error("missing token source: TOKEN_ENDPOINT and local credentials are both missing")
        throw VoiceCallError.missingTokenSource
    }

    private func handle(_ event: CallEvent) {
        switch event {
        case .ringing(let callUUID):
            phase = .ringing
            activeCallUUID = callUUID
        case .connected(let callUUID):
            phase = .connected
            activeCallUUID = callUUID
        case .reconnecting(let error):
            phase = .reconnecting
            lastError = error.localizedDescription
        case .reconnected:
            phase = .connected
            lastError = nil
        case .failedToConnect(let error):
            clearActiveCall(disconnectedWithError: error)
        case .disconnected(let error):
            clearActiveCall(disconnectedWithError: error)
        }
    }

    private func fail(with message: String) {
        PoCLogger.error("call failed: \(message)")
        activeCallUUID = nil
        hasActiveCall = false
        phase = .failed
        lastError = message
    }

    private func clearActiveCall(disconnectedWithError error: Error?) {
        activeCallUUID = nil
        hasActiveCall = false
        phase = error == nil ? .disconnected : .failed
        lastError = error?.localizedDescription
        isMuted = false
    }
}
