import CryptoKit
import Foundation

internal struct SmbCloudOpenIDConnectAuthorizationRequest {
    let authorizeURL: URL
    let state: String
    let codeVerifier: String
}

internal struct SmbCloudTokenPayload: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int32?
    let refreshToken: String?
    let scope: String?
    let idToken: String?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case idToken = "id_token"
    }
}

internal struct SmbCloudUserInfoPayload: Decodable {
    let sub: String
    let email: String?
    let emailVerified: Bool?
    let tenantId: UInt64?
    let tenantSlug: String?

    private enum CodingKeys: String, CodingKey {
        case sub
        case email
        case emailVerified = "email_verified"
        case tenantId = "tenant_id"
        case tenantSlug = "tenant_slug"
    }

    var userInfo: SmbCloudUserInfo {
        SmbCloudUserInfo(
            sub: sub,
            email: email,
            emailVerified: emailVerified,
            tenantId: tenantId,
            tenantSlug: tenantSlug
        )
    }
}

internal struct SmbCloudAPIErrorPayload: Decodable {
    let errorCode: Int?
    let message: String

    private enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case message
    }
}

internal struct SmbCloudOAuthErrorPayload: Decodable {
    let error: String
    let errorDescription: String?

    private enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

internal struct SmbCloudOpenIDConnectClient {
    static let defaultScopes = ["openid", "profile", "email"]

    let baseURL: URL
    let urlSession: URLSession

    init(baseURL: URL, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    func authorizationRequest(
        clientId: String,
        redirectURL: URL,
        scopes: [String],
        audience: String?
    ) throws -> SmbCloudOpenIDConnectAuthorizationRequest {
        guard redirectURL.scheme?.nilIfEmpty != nil else {
            throw SmbCloudClientError.invalidRedirectURL(
                "The redirect URL must include a callback scheme."
            )
        }

        let state = Self.randomURLSafeString(byteCount: 16)
        let codeVerifier = Self.randomURLSafeString(byteCount: 32)
        let codeChallenge = Self.sha256Base64URL(from: codeVerifier)
        let normalizedScopes = Self.normalizedScopes(scopes)

        guard
            var components = URLComponents(
                url: endpointURL(path: "oauth/authorize"),
                resolvingAgainstBaseURL: false
            )
        else {
            throw SmbCloudClientError.invalidBaseURL(
                "Failed to build the smbCloud authorization URL."
            )
        }

        var queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURL.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: normalizedScopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        if let audience = audience?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "audience", value: audience))
        }

        components.queryItems = queryItems

        guard let authorizeURL = components.url else {
            throw SmbCloudClientError.invalidBaseURL(
                "Failed to build the smbCloud authorization URL."
            )
        }

        return SmbCloudOpenIDConnectAuthorizationRequest(
            authorizeURL: authorizeURL,
            state: state,
            codeVerifier: codeVerifier
        )
    }

    func parseAuthorizationCode(from callbackURL: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        else {
            throw SmbCloudClientError.invalidCallbackURL(
                "The callback URL was not valid."
            )
        }

        let queryItems = components.queryItems ?? []

        if let error = queryItems.firstValue(named: "error") {
            let description = queryItems.firstValue(named: "error_description") ?? error
            throw SmbCloudClientError.authenticationFailed(description)
        }

        guard let code = queryItems.firstValue(named: "code") else {
            throw SmbCloudClientError.missingAuthorizationCode
        }

        guard let state = queryItems.firstValue(named: "state") else {
            throw SmbCloudClientError.missingAuthorizationState
        }

        guard state == expectedState else {
            throw SmbCloudClientError.stateMismatch(expected: expectedState, received: state)
        }

        return code
    }

    func exchangeCode(
        clientId: String,
        redirectURL: URL,
        code: String,
        codeVerifier: String
    ) async throws -> SmbCloudSession {
        var request = URLRequest(url: endpointURL(path: "oauth/token"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncodedData(
            from: [
                URLQueryItem(name: "grant_type", value: "authorization_code"),
                URLQueryItem(name: "client_id", value: clientId),
                URLQueryItem(name: "code", value: code),
                URLQueryItem(name: "redirect_uri", value: redirectURL.absoluteString),
                URLQueryItem(name: "code_verifier", value: codeVerifier),
            ]
        )

        let payload: SmbCloudTokenPayload = try await send(
            request, decodeAs: SmbCloudTokenPayload.self)
        return SmbCloudSession(tokenResponse: payload)
    }

    func userInfo(accessToken: String, tenantId: String?) async throws -> SmbCloudUserInfo {
        var request = URLRequest(url: endpointURL(path: "oauth/userinfo"))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        if let tenantId = tenantId?.nilIfEmpty {
            request.setValue(tenantId, forHTTPHeaderField: "X-Smbcloud-Tenant-Id")
        }

        let payload: SmbCloudUserInfoPayload = try await send(
            request, decodeAs: SmbCloudUserInfoPayload.self)
        return payload.userInfo
    }

    func endpointURL(path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }

    func send<Response: Decodable>(_ request: URLRequest, decodeAs: Response.Type) async throws
        -> Response
    {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw SmbCloudClientError.transportError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SmbCloudClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw apiError(from: data, statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw SmbCloudClientError.decodingFailed(
                "Failed to decode the smbCloud Auth response: \(error.localizedDescription)"
            )
        }
    }

    func apiError(from data: Data, statusCode: Int) -> SmbCloudClientError {
        if let payload = try? JSONDecoder().decode(SmbCloudAPIErrorPayload.self, from: data) {
            return .apiError(
                statusCode: statusCode,
                errorCode: payload.errorCode,
                message: payload.message
            )
        }

        if let payload = try? JSONDecoder().decode(SmbCloudOAuthErrorPayload.self, from: data) {
            return .apiError(
                statusCode: statusCode,
                errorCode: nil,
                message: payload.errorDescription?.nilIfEmpty ?? payload.error
            )
        }

        let fallbackMessage =
            String(data: data, encoding: .utf8)?.nilIfEmpty
            ?? HTTPURLResponse.localizedString(forStatusCode: statusCode)

        return .apiError(statusCode: statusCode, errorCode: nil, message: fallbackMessage)
    }

    static func normalizedScopes(from scope: String?) -> [String] {
        normalizedScopes((scope ?? "").split(separator: " ").map(String.init))
    }

    static func normalizedScopes(_ scopes: [String]) -> [String] {
        let sanitizedScopes = scopes.smbCloudUniqued()
        return sanitizedScopes.isEmpty ? defaultScopes : sanitizedScopes
    }

    static func randomURLSafeString(byteCount: Int) -> String {
        let randomBytes = Data((0..<byteCount).map { _ in UInt8.random(in: .min ... .max) })
        return randomBytes.base64URLEncodedString()
    }

    static func sha256Base64URL(from value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return Data(digest).base64URLEncodedString()
    }

    static func formEncodedData(from items: [URLQueryItem]) -> Data? {
        var components = URLComponents()
        components.queryItems = items
        return components.percentEncodedQuery?.data(using: .utf8)
    }
}

internal enum SmbCloudBaseURLFactory {
    static func makeURL(for environment: SmbCloudEnvironment) -> URL {
        switch environment {
        case .dev:
            return URL(string: "http://localhost:8088")!
        case .production:
            return URL(string: "https://api.smbcloud.xyz")!
        }
    }

    static func makeURL(from domain: String) throws -> URL {
        let trimmedDomain = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedDomain.isEmpty == false else {
            throw SmbCloudClientError.invalidBaseURL("The smbCloud Auth domain cannot be empty.")
        }

        let candidate = trimmedDomain.contains("://") ? trimmedDomain : "https://\(trimmedDomain)"
        guard let url = URL(string: candidate),
            url.scheme?.nilIfEmpty != nil,
            url.host?.nilIfEmpty != nil
        else {
            throw SmbCloudClientError.invalidBaseURL(
                "The smbCloud Auth domain or base URL is invalid: \(domain)"
            )
        }

        return url
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
