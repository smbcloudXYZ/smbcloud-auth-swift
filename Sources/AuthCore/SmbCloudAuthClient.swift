import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// A prepared OAuth 2.0 Authorization Code + PKCE request.
///
/// Hold on to this value for the lifetime of a single login attempt. After the
/// user agent redirects back to your `redirectURL`, pass the callback URL and
/// this request to ``SmbCloudAuthClient/exchangeCallback(_:authorizationRequest:)``.
public struct SmbCloudAuthorizationRequest: Equatable, Hashable, Sendable {
    /// The fully formed `oauth/authorize` URL to load in a browser/user agent.
    public let authorizeURL: URL
    /// The opaque `state` value used to protect against CSRF / callback mix-ups.
    public let state: String
    /// The PKCE code verifier that must be presented when exchanging the code.
    public let codeVerifier: String

    public init(authorizeURL: URL, state: String, codeVerifier: String) {
        self.authorizeURL = authorizeURL
        self.state = state
        self.codeVerifier = codeVerifier
    }
}

/// Headless, cross-platform smbCloud Auth engine.
///
/// `SmbCloudAuthClient` performs the platform-independent parts of the hosted
/// login flow — building the PKCE authorization request, validating the
/// callback, exchanging the authorization code for a session, and fetching
/// user info. It does **not** present any UI and has no dependency on
/// `AuthenticationServices`, the Keychain, or UIKit/AppKit, so it builds and
/// runs on Apple platforms as well as Linux, Windows, and Android.
///
/// On Apple platforms, prefer `SmbCloudWebAuth` (from the `SmbCloudAuth`
/// product) for an end-to-end `ASWebAuthenticationSession`-based login. On
/// other platforms, drive the user agent yourself and feed the callback URL
/// back into ``exchangeCallback(_:authorizationRequest:)``.
public final class SmbCloudAuthClient: @unchecked Sendable {
    /// The default OpenID Connect scopes (`openid profile email`).
    public static let defaultScopes: [String] = SmbCloudOpenIDConnectClient.defaultScopes

    /// The public OAuth client identifier.
    public let clientId: String
    /// The redirect URL registered for this client.
    public let redirectURL: URL

    private let client: SmbCloudOpenIDConnectClient
    private let userInfoClient: SmbCloudUserInfoClient

    public init(
        environment: SmbCloudEnvironment = .production,
        clientId: String,
        redirectURL: URL
    ) {
        let baseURL = SmbCloudBaseURLFactory.makeURL(for: environment)
        self.clientId = clientId
        self.redirectURL = redirectURL
        self.client = SmbCloudOpenIDConnectClient(baseURL: baseURL)
        self.userInfoClient = SmbCloudUserInfoClient(baseURL: baseURL)
    }

    public init(baseURL: URL, clientId: String, redirectURL: URL) {
        self.clientId = clientId
        self.redirectURL = redirectURL
        self.client = SmbCloudOpenIDConnectClient(baseURL: baseURL)
        self.userInfoClient = SmbCloudUserInfoClient(baseURL: baseURL)
    }

    public convenience init(domain: String, clientId: String, redirectURL: URL) throws {
        let baseURL = try SmbCloudBaseURLFactory.makeURL(from: domain)
        self.init(baseURL: baseURL, clientId: clientId, redirectURL: redirectURL)
    }

    /// The callback scheme derived from ``redirectURL``, if any.
    ///
    /// Useful when configuring a platform web-authentication session.
    public var callbackScheme: String? {
        guard let scheme = redirectURL.scheme, scheme.isEmpty == false else {
            return nil
        }

        return scheme
    }

    /// Builds a fresh PKCE authorization request.
    public func authorizationRequest(
        scopes: [String] = SmbCloudAuthClient.defaultScopes,
        audience: String? = nil
    ) throws -> SmbCloudAuthorizationRequest {
        let request = try client.authorizationRequest(
            clientId: clientId,
            redirectURL: redirectURL,
            scopes: scopes,
            audience: audience
        )

        return SmbCloudAuthorizationRequest(
            authorizeURL: request.authorizeURL,
            state: request.state,
            codeVerifier: request.codeVerifier
        )
    }

    /// Validates a redirect callback URL and extracts the authorization code.
    public func authorizationCode(from callbackURL: URL, expectedState: String) throws -> String {
        try client.parseAuthorizationCode(from: callbackURL, expectedState: expectedState)
    }

    /// Exchanges an authorization code for a session using the PKCE verifier.
    public func exchangeCode(_ code: String, codeVerifier: String) async throws -> SmbCloudSession {
        try await client.exchangeCode(
            clientId: clientId,
            redirectURL: redirectURL,
            code: code,
            codeVerifier: codeVerifier
        )
    }

    /// Completes the flow: validates the callback URL against `authorizationRequest`
    /// and exchanges the code for a session.
    public func exchangeCallback(
        _ callbackURL: URL,
        authorizationRequest: SmbCloudAuthorizationRequest
    ) async throws -> SmbCloudSession {
        let code = try authorizationCode(
            from: callbackURL,
            expectedState: authorizationRequest.state
        )

        return try await exchangeCode(code, codeVerifier: authorizationRequest.codeVerifier)
    }

    /// Convenience overload that persists the resulting session to a store.
    @discardableResult
    public func exchangeCallback(
        _ callbackURL: URL,
        authorizationRequest: SmbCloudAuthorizationRequest,
        credentialsStore: SmbCloudCredentialsStore?
    ) async throws -> SmbCloudSession {
        let session = try await exchangeCallback(
            callbackURL,
            authorizationRequest: authorizationRequest
        )

        try credentialsStore?.store(session)
        return session
    }

    public func userInfo(accessToken: String, tenantId: String? = nil) async throws
        -> SmbCloudUserInfo
    {
        try await userInfoClient.userInfo(accessToken: accessToken, tenantId: tenantId)
    }

    public func userInfo(session: SmbCloudSession, tenantId: String? = nil) async throws
        -> SmbCloudUserInfo
    {
        try await userInfo(accessToken: session.accessToken, tenantId: tenantId)
    }

    /// Clears any locally stored session. Hosted-login logout currently only
    /// removes the local session; it does not revoke tokens server-side.
    public func logout(credentialsStore: SmbCloudCredentialsStore? = nil) throws {
        try credentialsStore?.clear()
    }
}
