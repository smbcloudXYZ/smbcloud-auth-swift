import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

#if canImport(CryptoKit)
    import CryptoKit
#else
    import Crypto
#endif

/// OpenID Connect Authorization Code + PKCE flow (public client).
///
/// A faithful port of the canonical SDK's `oidc.rs`. Unlike the tenant
/// credential flow, this is a **public client**: it uses only an
/// `oidcClientId` — no `app_secret` — so it's appropriate for native and
/// browser apps. Drive the user agent yourself (or via `SmbCloudWebAuth` on
/// Apple) and feed the callback URL back into ``parseCallbackURL(_:)``.
public enum OIDC {
    /// A prepared OIDC authorization request. Open ``authorizeURL`` in a browser.
    public struct AuthorizationRequest: Sendable, Equatable {
        public let authorizeURL: URL
        public let redirectURI: String
        public let state: String
        public let codeVerifier: String
    }

    /// The `code` + `state` extracted from a redirect callback.
    public struct CallbackPayload: Sendable, Equatable {
        public let code: String
        public let state: String
    }

    /// The `oauth/token` response.
    public struct TokenResponse: Codable, Sendable, Equatable {
        public let accessToken: String
        public let tokenType: String
        public let expiresIn: Int?
        public let refreshToken: String?
        public let scope: String?
        public let idToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
            case scope
            case idToken = "id_token"
        }
    }

    /// The `oauth/userinfo` response.
    public struct UserInfo: Codable, Sendable, Equatable {
        public let sub: String
        public let email: String?
        public let emailVerified: Bool?
        public let tenantId: UInt64?
        public let tenantSlug: String?

        enum CodingKeys: String, CodingKey {
            case sub, email
            case emailVerified = "email_verified"
            case tenantId = "tenant_id"
            case tenantSlug = "tenant_slug"
        }
    }

    static let scopes = "openid profile email"

    /// Mirrors `oidc::build_authorization_request`.
    public static func buildAuthorizationRequest(
        environment: SmbCloudEnvironment,
        oidcClientId: String,
        redirectURI: String
    ) throws -> AuthorizationRequest {
        let codeVerifier = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let codeChallenge = base64URLNoPad(Data(SHA256.hash(data: Data(codeVerifier.utf8))))
        let state = UUID().uuidString

        guard
            var components = URLComponents(
                url: environment.baseURL.appendingPathComponent("oauth/authorize"),
                resolvingAgainstBaseURL: false
            )
        else {
            throw SmbCloudError(code: .parseError, message: "Failed to build the authorize URL.")
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: oidcClientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let url = components.url else {
            throw SmbCloudError(code: .parseError, message: "Failed to build the authorize URL.")
        }
        return AuthorizationRequest(
            authorizeURL: url,
            redirectURI: redirectURI,
            state: state,
            codeVerifier: codeVerifier
        )
    }

    /// Mirrors `oidc::parse_callback_url`.
    public static func parseCallbackURL(_ callbackURL: String) throws -> CallbackPayload {
        guard let components = URLComponents(string: callbackURL) else {
            throw SmbCloudError(code: .parseError, message: "The callback URL was not valid.")
        }
        let items = components.queryItems ?? []
        let code = items.first { $0.name == "code" }?.value
        let state = items.first { $0.name == "state" }?.value
        guard let code, let state else {
            throw SmbCloudError(code: .invalidParams, message: "Missing authorization code or state.")
        }
        return CallbackPayload(code: code, state: state)
    }

    /// Mirrors `oidc::exchange_code`.
    public static func exchangeCode(
        environment: SmbCloudEnvironment,
        oidcClientId: String,
        redirectURI: String,
        code: String,
        codeVerifier: String,
        session: URLSession = .shared
    ) async throws -> TokenResponse {
        var request = URLRequest(url: environment.baseURL.appendingPathComponent("oauth/token"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncoded([
            ("grant_type", "authorization_code"),
            ("client_id", oidcClientId),
            ("code", code),
            ("redirect_uri", redirectURI),
            ("code_verifier", codeVerifier),
        ])
        return try await HTTPTransport(session: session).requestJSON(request, as: TokenResponse.self)
    }

    /// Mirrors `oidc::get_userinfo`.
    public static func getUserInfo(
        environment: SmbCloudEnvironment,
        accessToken: String,
        tenantId: String? = nil,
        session: URLSession = .shared
    ) async throws -> UserInfo {
        var request = URLRequest(url: environment.baseURL.appendingPathComponent("oauth/userinfo"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let tenantId {
            request.setValue(tenantId, forHTTPHeaderField: "X-Smbcloud-Tenant-Id")
        }
        return try await HTTPTransport(session: session).requestJSON(request, as: UserInfo.self)
    }

    // MARK: - Helpers

    private static func base64URLNoPad(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func formEncoded(_ items: [(String, String)]) -> Data? {
        var components = URLComponents()
        components.queryItems = items.map { URLQueryItem(name: $0.0, value: $0.1) }
        return components.percentEncodedQuery?.data(using: .utf8)
    }
}
