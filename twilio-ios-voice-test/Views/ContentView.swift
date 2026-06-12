//
//  ContentView.swift
//  twilio-ios-voice-test
//
//  Created by yoshimura on 2026/06/09.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CallViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Token") {
                    TextField("https://example.twil.io/token", text: $viewModel.tokenEndpoint)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Identity", text: $viewModel.identity)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Call") {
                    TextField("To number (+819012345678)", text: $viewModel.phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)

                    TextField("Caller ID (+819012345678)", text: $viewModel.callerID)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)

                    Button {
                        Task {
                            await viewModel.startCall()
                        }
                    } label: {
                        Label("Call", systemImage: "phone.fill")
                    }
                    .disabled(!viewModel.canStartCall)

                    Button(role: .destructive) {
                        viewModel.hangUp()
                    } label: {
                        Label("Hang Up", systemImage: "phone.down.fill")
                    }
                    .disabled(!viewModel.canHangUp)

                    Toggle(isOn: $viewModel.isSpeakerEnabled) {
                        Label("Speaker", systemImage: "speaker.wave.2.fill")
                    }
                    .disabled(!viewModel.canHangUp)

                    Toggle(isOn: $viewModel.isMuted) {
                        Label("Mute", systemImage: "mic.slash.fill")
                    }
                    .disabled(!viewModel.canHangUp)

                    Picker("Signal Sound", selection: $viewModel.selectedSignalSoundID) {
                        ForEach(viewModel.signalSoundIDs, id: \.self) { soundID in
                            Text("ID \(soundID)")
                                .tag(soundID)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button {
                        viewModel.playSelectedSignalSound()
                    } label: {
                        Label("Send Signal \(viewModel.selectedSignalSoundID)", systemImage: "waveform")
                    }
                    .disabled(!viewModel.canPlaySignalSound)
                }

                Section("Status") {
                    LabeledContent("State", value: viewModel.phase.label)
                    LabeledContent("Token Source", value: viewModel.tokenSourceLabel)

                    if let activeCallUUID = viewModel.activeCallUUID {
                        LabeledContent("Call UUID", value: activeCallUUID)
                    }

                    if let lastError = viewModel.lastError {
                        Text(lastError)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Twilio Voice")
        }
    }
}

#Preview {
    ContentView()
}
