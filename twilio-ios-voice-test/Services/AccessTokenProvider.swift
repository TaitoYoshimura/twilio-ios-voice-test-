//
//  AccessTokenProvider.swift
//  twilio-ios-voice-test
//

import Foundation

protocol AccessTokenProviding {
    func accessToken(identity: String) async throws -> String
}

struct LocalAccessTokenProvider: AccessTokenProviding {
    let factory: TwilioVoiceAccessTokenFactory

    func accessToken(identity: String) async throws -> String {
        PoCLogger.info("resolving access token from local .env credentials")
        return try factory.makeAccessToken(identity: identity)
    }
}

struct RemoteAccessTokenProvider: AccessTokenProviding {
    let endpoint: String

    func accessToken(identity: String) async throws -> String {
        PoCLogger.info("resolving access token from TOKEN_ENDPOINT")
        let tokenURL = try makeTokenURL(identity: identity)
        PoCLogger.info("fetching access token urlHost=\(tokenURL.host ?? "nil") path=\(tokenURL.path)")
        let (data, response) = try await URLSession.shared.data(from: tokenURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            PoCLogger.error("token endpoint did not return HTTP response")
            throw VoiceCallError.invalidTokenResponse("Token endpoint did not return an HTTP response.")
        }

        PoCLogger.info("token endpoint status=\(httpResponse.statusCode) bytes=\(data.count)")
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            PoCLogger.error("token endpoint failed status=\(httpResponse.statusCode) bodyLength=\(body.count)")
            throw VoiceCallError.invalidTokenResponse("Token endpoint returned HTTP \(httpResponse.statusCode). \(body)")
        }

        if let tokenResponse = try? JSONDecoder().decode(TokenResponse.self, from: data),
           !tokenResponse.token.isEmpty {
            PoCLogger.info("token endpoint returned JSON token")
            return tokenResponse.token
        }

        if let rawToken = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")),
           rawToken.split(separator: ".").count == 3 {
            PoCLogger.info("token endpoint returned raw JWT")
            return rawToken
        }

        PoCLogger.error("token endpoint response did not include a token")
        throw VoiceCallError.invalidTokenResponse("Token endpoint response must include a token field.")
    }

    private func makeTokenURL(identity: String) throws -> URL {
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmedEndpoint),
              components.scheme == "https" || components.scheme == "http",
              components.host != nil else {
            PoCLogger.error("invalid token endpoint URL: \(trimmedEndpoint)")
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
            PoCLogger.error("failed to construct token endpoint URL from components")
            throw VoiceCallError.invalidTokenEndpoint
        }

        PoCLogger.info("token URL prepared hasIdentityQuery=\(url.absoluteString.contains("identity="))")
        return url
    }
}

private struct TokenResponse: Decodable {
    let token: String
}
