//
//  ContentView.swift
//  twilio-ios-voice-test
//
//  Created by yoshimura on 2026/06/09.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var callManager = VoiceCallManager()

    private let appEnvironment: AppEnvironment

    @State private var tokenEndpoint: String
    @State private var identity: String
    @State private var phoneNumber: String
    @State private var callerID: String

    init(appEnvironment: AppEnvironment = .load()) {
        self.appEnvironment = appEnvironment
        _tokenEndpoint = State(initialValue: appEnvironment.tokenEndpoint)
        _identity = State(initialValue: appEnvironment.defaultIdentity)
        _phoneNumber = State(initialValue: appEnvironment.defaultToNumber)
        _callerID = State(initialValue: appEnvironment.callerID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Token") {
                    TextField("https://example.twil.io/token", text: $tokenEndpoint)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Identity", text: $identity)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Call") {
                    TextField("To number (+819012345678)", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)

                    TextField("Caller ID (+819012345678)", text: $callerID)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)

                    Button {
                        Task {
                            await callManager.startCall(
                                tokenEndpoint: tokenEndpoint,
                                localTokenFactory: appEnvironment.localTokenFactory,
                                identity: identity,
                                phoneNumber: phoneNumber,
                                callerID: callerID
                            )
                        }
                    } label: {
                        Label("Call", systemImage: "phone.fill")
                    }
                    .disabled(!canStartCall)

                    Button(role: .destructive) {
                        callManager.hangUp()
                    } label: {
                        Label("Hang Up", systemImage: "phone.down.fill")
                    }
                    .disabled(!callManager.canHangUp)

                    Toggle(isOn: $callManager.isSpeakerEnabled) {
                        Label("Speaker", systemImage: "speaker.wave.2.fill")
                    }
                    .disabled(!callManager.canHangUp)

                    Toggle(isOn: $callManager.isMuted) {
                        Label("Mute", systemImage: "mic.slash.fill")
                    }
                    .disabled(!callManager.canHangUp)
                }

                Section("Status") {
                    LabeledContent("State", value: callManager.phase.label)
                    LabeledContent("Token Source", value: tokenSourceLabel)

                    if let activeCallUUID = callManager.activeCallUUID {
                        LabeledContent("Call UUID", value: activeCallUUID)
                    }

                    if let lastError = callManager.lastError {
                        Text(lastError)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Twilio Voice")
        }
    }

    private var canStartCall: Bool {
        callManager.canStartCall &&
        hasTokenSource &&
        !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasTokenSource: Bool {
        appEnvironment.hasLocalTokenCredentials ||
        !tokenEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var tokenSourceLabel: String {
        if !tokenEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Token URL"
        }

        if appEnvironment.hasLocalTokenCredentials {
            return "Local .env"
        }

        return "Missing"
    }
}

#Preview {
    ContentView()
}
