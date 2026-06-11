//
//  VoiceCallService.swift
//  twilio-ios-voice-test
//

import AVFoundation
import Foundation
import TwilioVoice

enum CallEvent {
    case ringing(callUUID: String?)
    case connected(callUUID: String?)
    case reconnecting(error: Error)
    case reconnected
    case failedToConnect(error: Error)
    case disconnected(error: Error?)
}

@MainActor
final class VoiceCallService: NSObject {
    var onEvent: ((CallEvent) -> Void)?

    private var activeCall: Call?
    private let audioDevice = DefaultAudioDevice()
    private var isSpeakerEnabled = true

    override init() {
        super.init()
        TwilioVoiceSDK.audioDevice = audioDevice
        PoCLogger.info("VoiceCallService initialized")
    }

    var hasActiveCall: Bool {
        activeCall != nil
    }

    func connect(accessToken: String, to phoneNumber: String, callerID: String?) -> String? {
        let connectOptions = ConnectOptions(accessToken: accessToken) { builder in
            var params = ["To": phoneNumber]
            if let callerID {
                params["CallerId"] = callerID
            }

            builder.params = params
            // Do NOT set builder.uuid here: it is a CallKit-only property.
            // Setting it makes the SDK skip starting the audio device and wait
            // for CXProviderDelegate.didActivateAudioSession, which this app
            // does not implement — the call connects but stays silent.
            PoCLogger.info("ConnectOptions prepared params=\(params.keys.sorted())")
        }

        let call = TwilioVoiceSDK.connect(options: connectOptions, delegate: self)
        activeCall = call
        applyAudioRoute()
        PoCLogger.info("TwilioVoiceSDK.connect returned callUUID=\(call.uuid?.uuidString ?? "nil")")
        return call.uuid?.uuidString
    }

    func disconnect() {
        guard let activeCall else {
            PoCLogger.info("hangUp ignored because activeCall is nil")
            return
        }

        PoCLogger.info("hangUp requested callUUID=\(activeCall.uuid?.uuidString ?? "nil")")
        activeCall.disconnect()
    }

    func setMuted(_ muted: Bool) {
        activeCall?.isMuted = muted
    }

    func setSpeakerEnabled(_ enabled: Bool) {
        isSpeakerEnabled = enabled
        applyAudioRoute()
    }

    private func applyAudioRoute() {
        audioDevice.block = { [isSpeakerEnabled] in
            DefaultAudioDevice.DefaultAVAudioSessionConfigurationBlock()
            do {
                try AVAudioSession.sharedInstance().overrideOutputAudioPort(isSpeakerEnabled ? .speaker : .none)
                PoCLogger.info("audio route updated speaker=\(isSpeakerEnabled)")
            } catch {
                PoCLogger.error("failed to update audio route: \(error.localizedDescription)")
            }
        }
        audioDevice.block()
    }

    private func clearActiveCall(disconnectedWithError error: Error?) {
        if let error {
            PoCLogger.error("clearing active call with error: \(error.localizedDescription)")
        } else {
            PoCLogger.info("clearing active call without error")
        }
        activeCall = nil
    }
}

extension VoiceCallService: CallDelegate {
    nonisolated func callDidStartRinging(call: Call) {
        Task { @MainActor [weak self] in
            PoCLogger.info("callDidStartRinging callUUID=\(call.uuid?.uuidString ?? "nil")")
            self?.onEvent?(.ringing(callUUID: call.uuid?.uuidString))
        }
    }

    nonisolated func callDidConnect(call: Call) {
        Task { @MainActor [weak self] in
            PoCLogger.info("callDidConnect callUUID=\(call.uuid?.uuidString ?? "nil")")
            self?.applyAudioRoute()
            self?.onEvent?(.connected(callUUID: call.uuid?.uuidString))
        }
    }

    nonisolated func callIsReconnecting(call: Call, error: Error) {
        Task { @MainActor [weak self] in
            PoCLogger.error("callIsReconnecting callUUID=\(call.uuid?.uuidString ?? "nil") error=\(error.localizedDescription)")
            self?.onEvent?(.reconnecting(error: error))
        }
    }

    nonisolated func callDidReconnect(call: Call) {
        Task { @MainActor [weak self] in
            PoCLogger.info("callDidReconnect callUUID=\(call.uuid?.uuidString ?? "nil")")
            self?.onEvent?(.reconnected)
        }
    }

    nonisolated func callDidFailToConnect(call: Call, error: Error) {
        Task { @MainActor [weak self] in
            PoCLogger.error("callDidFailToConnect callUUID=\(call.uuid?.uuidString ?? "nil") error=\(error.localizedDescription)")
            self?.clearActiveCall(disconnectedWithError: error)
            self?.onEvent?(.failedToConnect(error: error))
        }
    }

    nonisolated func callDidDisconnect(call: Call, error: Error?) {
        Task { @MainActor [weak self] in
            if let error {
                PoCLogger.error("callDidDisconnect callUUID=\(call.uuid?.uuidString ?? "nil") error=\(error.localizedDescription)")
            } else {
                PoCLogger.info("callDidDisconnect callUUID=\(call.uuid?.uuidString ?? "nil")")
            }
            self?.clearActiveCall(disconnectedWithError: error)
            self?.onEvent?(.disconnected(error: error))
        }
    }
}
