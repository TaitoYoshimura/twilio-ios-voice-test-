//
//  AppEnvironment.swift
//  twilio-ios-voice-test
//
//  Created by Codex on 2026/06/10.
//

import Foundation

struct AppEnvironment {
    let tokenEndpoint: String
    let defaultIdentity: String
    let defaultToNumber: String
    let callerID: String
    let accountSID: String
    let apiKeySID: String
    let apiKeySecret: String
    let twimlAppSID: String

    var localTokenFactory: TwilioVoiceAccessTokenFactory? {
        guard !accountSID.isEmpty,
              !apiKeySID.isEmpty,
              !apiKeySecret.isEmpty,
              !twimlAppSID.isEmpty else {
            return nil
        }

        return TwilioVoiceAccessTokenFactory(
            accountSID: accountSID,
            apiKeySID: apiKeySID,
            apiKeySecret: apiKeySecret,
            twimlAppSID: twimlAppSID
        )
    }

    var hasLocalTokenCredentials: Bool {
        localTokenFactory != nil
    }

    static func load(bundle: Bundle = .main) -> AppEnvironment {
        var values = ProcessInfo.processInfo.environment

        if let envFileValues = loadBundledEnv(bundle: bundle) {
            values.merge(envFileValues) { _, fileValue in fileValue }
        }

        return AppEnvironment(
            tokenEndpoint: values.envValue("TOKEN_ENDPOINT"),
            defaultIdentity: values.envValue("DEFAULT_IDENTITY", default: "ios_poc_user"),
            defaultToNumber: values.envValue("DEFAULT_TO_NUMBER"),
            callerID: values.envValue("CALLER_ID"),
            accountSID: values.envValue("ACCOUNT_SID", fallback: "TWILIO_ACCOUNT_SID"),
            apiKeySID: values.envValue("API_KEY_SID", fallback: "TWILIO_API_KEY_SID"),
            apiKeySecret: values.envValue("API_KEY_SECRET", fallback: "TWILIO_API_KEY_SECRET"),
            twimlAppSID: values.envValue("TWIML_APP_SID", fallback: "TWILIO_TWIML_APP_SID")
        )
    }

    private static func loadBundledEnv(bundle: Bundle) -> [String: String]? {
        let envURL = bundle.bundleURL.appendingPathComponent(".env")
        guard let contents = try? String(contentsOf: envURL, encoding: .utf8) else {
            return nil
        }

        return EnvParser.parse(contents)
    }
}

private enum EnvParser {
    static func parse(_ contents: String) -> [String: String] {
        contents
            .split(whereSeparator: \.isNewline)
            .reduce(into: [String: String]()) { result, rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty,
                      !line.hasPrefix("#"),
                      let separatorIndex = line.firstIndex(of: "=") else {
                    return
                }

                let key = String(line[..<separatorIndex])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let rawValue = String(line[line.index(after: separatorIndex)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !key.isEmpty else {
                    return
                }

                result[key] = unquote(rawValue)
            }
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else {
            return value
        }

        let first = value.first
        let last = value.last
        if first == "\"", last == "\"" {
            return String(value.dropFirst().dropLast())
        }
        if first == "'", last == "'" {
            return String(value.dropFirst().dropLast())
        }

        return value
    }
}

private extension Dictionary where Key == String, Value == String {
    func envValue(_ key: String, fallback: String? = nil, default defaultValue: String = "") -> String {
        let value = self[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value, !value.isEmpty {
            return value
        }

        if let fallback {
            let fallbackValue = self[fallback]?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let fallbackValue, !fallbackValue.isEmpty {
                return fallbackValue
            }
        }

        return defaultValue
    }
}
