//
//  String+E164.swift
//  twilio-ios-voice-test
//

import Foundation

extension String {
    var isE164PhoneNumber: Bool {
        let pattern = #"^\+[1-9]\d{7,14}$"#
        return range(of: pattern, options: .regularExpression) != nil
    }
}
