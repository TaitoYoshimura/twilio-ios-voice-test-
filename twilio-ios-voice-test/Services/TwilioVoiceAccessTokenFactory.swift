//
//  TwilioVoiceAccessTokenFactory.swift
//  twilio-ios-voice-test
//
//  Created by Codex on 2026/06/10.
//

import CryptoKit
import Foundation

struct TwilioVoiceAccessTokenFactory {
    let accountSID: String
    let apiKeySID: String
    let apiKeySecret: String
    let twimlAppSID: String
    let ttl: TimeInterval

    init(
        accountSID: String,
        apiKeySID: String,
        apiKeySecret: String,
        twimlAppSID: String,
        ttl: TimeInterval = 3600
    ) {
        self.accountSID = accountSID
        self.apiKeySID = apiKeySID
        self.apiKeySecret = apiKeySecret
        self.twimlAppSID = twimlAppSID
        self.ttl = ttl
    }

    func makeAccessToken(identity: String, now: Date = Date()) throws -> String {
        let issuedAt = Int(now.timeIntervalSince1970)
        let expiresAt = issuedAt + Int(ttl)
        PoCLogger.info(
            "creating local access token identity=\(identity) " +
            "accountSID=\(PoCLogger.maskedSID(accountSID)) " +
            "apiKeySID=\(PoCLogger.maskedSID(apiKeySID)) " +
            "twimlAppSID=\(PoCLogger.maskedSID(twimlAppSID)) " +
            "ttl=\(Int(ttl))s"
        )

        let header: [String: Any] = [
            "alg": "HS256",
            "cty": "twilio-fpa;v=1",
            "typ": "JWT"
        ]

        let payload: [String: Any] = [
            "exp": expiresAt,
            "grants": [
                "identity": identity,
                "voice": [
                    "incoming": [
                        "allow": false
                    ],
                    "outgoing": [
                        "application_sid": twimlAppSID
                    ]
                ]
            ],
            "iss": apiKeySID,
            "jti": "\(apiKeySID)-\(issuedAt)",
            "sub": accountSID
        ]

        let signingInput = try [
            Self.base64URLEncodedJSON(header),
            Self.base64URLEncodedJSON(payload)
        ].joined(separator: ".")

        let key = SymmetricKey(data: Data(apiKeySecret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(signingInput.utf8),
            using: key
        )

        PoCLogger.info("local access token created exp=\(expiresAt)")
        return "\(signingInput).\(Data(signature).base64URLEncodedString())"
    }

    private static func base64URLEncodedJSON(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        return data.base64URLEncodedString()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
