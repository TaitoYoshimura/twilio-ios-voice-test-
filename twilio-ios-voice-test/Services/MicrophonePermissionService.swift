//
//  MicrophonePermissionService.swift
//  twilio-ios-voice-test
//

import AVFoundation

struct MicrophonePermissionService {
    func requestAccess() async -> Bool {
        let recordPermission = AVAudioApplication.shared.recordPermission
        PoCLogger.info("microphone permission current=\(String(describing: recordPermission))")
        switch recordPermission {
        case .granted:
            PoCLogger.info("microphone permission already granted")
            return true
        case .denied:
            PoCLogger.error("microphone permission denied")
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    PoCLogger.info("microphone permission request result=\(granted)")
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            PoCLogger.error("microphone permission unknown status")
            return false
        }
    }
}
