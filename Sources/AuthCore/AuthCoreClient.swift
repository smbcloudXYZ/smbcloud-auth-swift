import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Headless smbCloud Auth client for a tenant auth app.
///
/// A faithful Swift port of the canonical `smbcloud-auth-sdk` tenant client
/// surface (`login`, `signup`, `me`, `logout`, `remove`, and the Apple provider
/// helpers). It performs no UI and has no dependency on AuthenticationServices
/// or the Keychain, so it builds on Apple platforms, Linux, Windows, and
/// Android — including inside a server.
///
/// This client uses confidential ``ClientCredentials`` (`appId` + `appSecret`).
/// Construct and use it where the secret is safe (a backend / BFF). For native
/// or browser public clients, use ``OIDC`` or the Apple flow, or call your own
/// backend.
public struct AuthCoreClient: Sendable {
    public let environment: SmbCloudEnvironment
    public let credentials: ClientCredentials
    private let http: HTTPTransport

    public init(environment: SmbCloudEnvironment, credentials: ClientCredentials) {
        self.environment = environment
        self.credentials = credentials
        self.http = HTTPTransport()
    }

    init(
        environment: SmbCloudEnvironment,
        credentials: ClientCredentials,
        session: URLSession
    ) {
        self.environment = environment
        self.credentials = credentials
        self.http = HTTPTransport(session: session)
    }

    // MARK: - Email / password (tenant credential flow)

    /// `POST /v1/client/users/sign_in` — mirrors `login_with_client`.
    public func login(username: String, password: String) async throws -> AccountStatus {
        let url = credentials.tenantURL(environment: environment, path: "v1/client/users/sign_in")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(credentials.appId, forHTTPHeaderField: "User-agent")
        request.httpBody = try JSONEncoder().encode(
            UserEnvelope(user: .init(email: username, password: password))
        )
        return try await http.requestLogin(request)
    }

    /// `POST /v1/client/users` — mirrors `signup_with_client`.
    public func signup(email: String, password: String) async throws -> SignupResult {
        let url = credentials.tenantURL(environment: environment, path: "v1/client/users")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(credentials.appId, forHTTPHeaderField: "User-agent")
        request.httpBody = try JSONEncoder().encode(
            UserEnvelope(user: .init(email: email, password: password))
        )
        return try await http.requestJSON(request, as: SignupResult.self)
    }

    /// `GET /v1/client/me` — mirrors `me_with_client`.
    ///
    /// `accessToken` is the value returned in ``AccountStatus/ready(accessToken:)``
    /// and is sent verbatim as the `Authorization` header (it already carries
    /// the `Bearer ` prefix).
    public func me(accessToken: String) async throws -> User {
        let url = credentials.tenantURL(environment: environment, path: "v1/client/me")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        return try await http.requestJSON(request, as: User.self)
    }

    /// `DELETE /v1/client/users/sign_out` — mirrors `logout_with_client`.
    public func logout(accessToken: String) async throws {
        let url = credentials.tenantURL(environment: environment, path: "v1/client/users/sign_out")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        do {
            try await http.requestVoid(request)
        } catch {
            // Mirror the Rust SDK: any non-OK is surfaced as unauthorized.
            throw SmbCloudError(code: .unauthorized)
        }
    }

    /// `DELETE /v1/client/me` — mirrors `remove_with_client`.
    public func remove(accessToken: String) async throws {
        let url = credentials.tenantURL(environment: environment, path: "v1/client/me")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        request.setValue(credentials.appId, forHTTPHeaderField: "User-agent")
        try await http.requestVoid(request)
    }

    // MARK: - Account recovery
    //
    // NOTE: these wrap backend endpoints that the canonical `smbcloud-auth-sdk`
    // crate does not expose yet (only the CLI-internal `smbcloud-auth` crate
    // does). They're faithful to the backend contract; upstream them to
    // `smbcloud-auth-sdk` to restore full cross-binding parity. Each returns the
    // server's user-facing message.

    /// `POST /v1/client/users/reset_password` — sends reset instructions.
    @discardableResult
    public func requestPasswordReset(email: String) async throws -> String {
        try await postMessage(path: "v1/client/users/reset_password", body: EmailEnvelope(user: .init(email: email)))
    }

    /// `POST /v1/client/users/reset_password/complete` — sets a new password
    /// using the token from the reset email.
    @discardableResult
    public func completePasswordReset(
        token: String,
        password: String,
        passwordConfirmation: String? = nil
    ) async throws -> String {
        let body = ResetPasswordComplete(
            resetPasswordToken: token,
            password: password,
            passwordConfirmation: passwordConfirmation ?? password
        )
        return try await postMessage(path: "v1/client/users/reset_password/complete", body: body)
    }

    /// `POST /v1/client/users/resend_confirmation` — re-sends the confirmation email.
    @discardableResult
    public func resendConfirmation(email: String) async throws -> String {
        try await postMessage(path: "v1/client/users/resend_confirmation", body: EmailEnvelope(user: .init(email: email)))
    }

    private func postMessage<Body: Encodable>(path: String, body: Body) async throws -> String {
        let url = credentials.tenantURL(environment: environment, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(credentials.appId, forHTTPHeaderField: "User-agent")
        request.httpBody = try JSONEncoder().encode(body)
        return try await http.requestJSON(request, as: MessageResponse.self).message
    }

    // MARK: - Apple provider (tenant)

    /// Builds the tenant Apple authorization request — mirrors
    /// `apple::build_authorization_request_with_client`.
    public func buildAppleAuthorizationRequest(
        redirectURI: String,
        state: String? = nil
    ) -> AppleAuthorizationRequest {
        let resolvedState = state ?? UUID().uuidString
        let url = credentials.tenantURL(
            environment: environment,
            path: "v1/client/oauth/apple/authorize",
            extraQuery: [
                URLQueryItem(name: "redirect_uri", value: redirectURI),
                URLQueryItem(name: "state", value: resolvedState),
            ]
        )
        return AppleAuthorizationRequest(
            authorizeURL: url,
            redirectURI: redirectURI,
            state: resolvedState
        )
    }

    /// Parses an Apple callback URL into a session — mirrors `apple::parse_callback_url`.
    public func parseAppleCallbackURL(
        _ callbackURL: String,
        expectedState: String? = nil
    ) throws -> AppleAuthSession {
        guard let components = URLComponents(string: callbackURL) else {
            throw SmbCloudError(code: .parseError, message: "Invalid Apple callback URL.")
        }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }

        if let error = value("error") {
            throw SmbCloudError(code: .invalidParams, message: error)
        }
        let state = value("state")
        if let expectedState, state != expectedState {
            throw SmbCloudError(code: .invalidParams, message: "Apple callback state mismatch.")
        }
        guard let accessToken = value("access_token") else {
            throw SmbCloudError(code: .invalidParams, message: "Missing `access_token` in Apple callback URL.")
        }
        guard let providerAccountId = value("provider_account_id") else {
            throw SmbCloudError(code: .invalidParams, message: "Missing `provider_account_id` in Apple callback URL.")
        }
        return AppleAuthSession(
            accessToken: accessToken,
            refreshToken: value("refresh_token"),
            email: value("email"),
            name: value("name"),
            provider: value("provider") ?? "apple",
            providerAccountId: providerAccountId,
            state: state
        )
    }
}

// MARK: - Request bodies

private struct UserEnvelope: Encodable {
    struct Credentials: Encodable {
        let email: String
        let password: String
    }
    let user: Credentials
}

private struct EmailEnvelope: Encodable {
    struct EmailOnly: Encodable { let email: String }
    let user: EmailOnly
}

private struct ResetPasswordComplete: Encodable {
    let resetPasswordToken: String
    let password: String
    let passwordConfirmation: String

    enum CodingKeys: String, CodingKey {
        case resetPasswordToken = "reset_password_token"
        case password
        case passwordConfirmation = "password_confirmation"
    }
}

/// `{ "message": "…" }` — the recovery endpoints' response envelope.
private struct MessageResponse: Decodable {
    let message: String
}
