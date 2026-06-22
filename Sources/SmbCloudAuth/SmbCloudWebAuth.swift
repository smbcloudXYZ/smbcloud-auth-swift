import AuthCore
import Foundation

#if canImport(AuthenticationServices) && (os(iOS) || os(macOS) || os(visionOS))
    import AuthenticationServices

    public typealias SmbCloudPresentationAnchor = ASPresentationAnchor
#endif

/// Errors specific to the Apple hosted-login UI.
public enum SmbCloudWebAuthError: Error, LocalizedError, Sendable {
    case loginInProgress
    case cancelled
    case invalidRedirectURL(String)
    case stateMismatch
    case missingCallbackURL
    case authenticationFailed(String?)

    public var errorDescription: String? {
        switch self {
        case .loginInProgress: return "A web authentication session is already in progress."
        case .cancelled: return "The authentication session was cancelled."
        case .invalidRedirectURL(let message): return message
        case .stateMismatch: return "The callback state did not match."
        case .missingCallbackURL: return "The authentication session completed without a callback URL."
        case .authenticationFailed(let message): return message ?? "The authentication session failed."
        }
    }
}

/// Apple-platform hosted login built on `AuthCore`'s OIDC public-client flow.
///
/// `SmbCloudWebAuth` is the **public client** entry point: it uses only an
/// `oidcClientId` (no `app_secret`) and drives an `ASWebAuthenticationSession`
/// through smbCloud's OIDC Authorization Code + PKCE flow. This is the
/// recommended native sign-in path. Email/password sign-in (which needs the
/// confidential `app_secret`) belongs on a backend via ``AuthCoreClient``.
///
/// For headless or non-Apple usage, use ``OIDC`` (or ``AuthCoreClient``) from
/// the `AuthCore` product directly.
public final class SmbCloudWebAuth: @unchecked Sendable {
    public let environment: SmbCloudEnvironment
    public let oidcClientId: String
    public let redirectURL: URL

    #if canImport(AuthenticationServices) && (os(iOS) || os(macOS) || os(visionOS))
        @MainActor private var activeAuthenticationSession: ASWebAuthenticationSession?
        @MainActor private var activePresentationContextProvider: SmbCloudPresentationContextProvider?
    #endif

    public init(
        environment: SmbCloudEnvironment = .production,
        oidcClientId: String,
        redirectURL: URL
    ) {
        self.environment = environment
        self.oidcClientId = oidcClientId
        self.redirectURL = redirectURL
    }

    /// The callback scheme derived from ``redirectURL``.
    public var callbackScheme: String? {
        guard let scheme = redirectURL.scheme, !scheme.isEmpty else { return nil }
        return scheme
    }

    // Non-interactive helpers, available wherever the package builds.

    public func userInfo(accessToken: String, tenantId: String? = nil) async throws
        -> OIDC.UserInfo
    {
        try await OIDC.getUserInfo(
            environment: environment, accessToken: accessToken, tenantId: tenantId)
    }

    public func userInfo(session: SmbCloudSession, tenantId: String? = nil) async throws
        -> OIDC.UserInfo
    {
        try await userInfo(accessToken: session.accessToken, tenantId: tenantId)
    }

    public func clearSession(credentialsManager: SmbCloudCredentialsStore? = nil) throws {
        try credentialsManager?.clear()
    }

    public func logout(credentialsManager: SmbCloudCredentialsStore? = nil) throws {
        try clearSession(credentialsManager: credentialsManager)
    }
}

#if canImport(AuthenticationServices) && (os(iOS) || os(macOS) || os(visionOS))
    extension SmbCloudWebAuth {
        /// Presents the hosted OIDC login and returns the resulting session.
        @MainActor
        public func login(
            presentationAnchorProvider: @escaping () -> SmbCloudPresentationAnchor,
            prefersEphemeralSession: Bool = false,
            credentialsManager: SmbCloudCredentialsStore? = nil
        ) async throws -> SmbCloudSession {
            guard activeAuthenticationSession == nil else {
                throw SmbCloudWebAuthError.loginInProgress
            }
            guard let callbackScheme else {
                throw SmbCloudWebAuthError.invalidRedirectURL(
                    "The redirect URL must include a callback scheme.")
            }

            let authRequest = try OIDC.buildAuthorizationRequest(
                environment: environment,
                oidcClientId: oidcClientId,
                redirectURI: redirectURL.absoluteString
            )

            let presentationContextProvider = SmbCloudPresentationContextProvider(
                presentationAnchorProvider: presentationAnchorProvider)

            defer {
                activeAuthenticationSession = nil
                activePresentationContextProvider = nil
            }

            let callbackURL = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<URL, Error>) in
                    let session = ASWebAuthenticationSession(
                        url: authRequest.authorizeURL,
                        callbackURLScheme: callbackScheme
                    ) { callbackURL, error in
                        if let error {
                            continuation.resume(throwing: Self.authenticationError(from: error))
                            return
                        }
                        guard let callbackURL else {
                            continuation.resume(throwing: SmbCloudWebAuthError.missingCallbackURL)
                            return
                        }
                        continuation.resume(returning: callbackURL)
                    }

                    session.prefersEphemeralWebBrowserSession = prefersEphemeralSession
                    session.presentationContextProvider = presentationContextProvider

                    activePresentationContextProvider = presentationContextProvider
                    activeAuthenticationSession = session

                    guard session.start() else {
                        activeAuthenticationSession = nil
                        activePresentationContextProvider = nil
                        continuation.resume(
                            throwing: SmbCloudWebAuthError.authenticationFailed(
                                "Failed to start the smbCloud web authentication session."))
                        return
                    }
                }
            } onCancel: { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.activeAuthenticationSession?.cancel()
                    self.activeAuthenticationSession = nil
                    self.activePresentationContextProvider = nil
                }
            }

            let payload = try OIDC.parseCallbackURL(callbackURL.absoluteString)
            guard payload.state == authRequest.state else {
                throw SmbCloudWebAuthError.stateMismatch
            }

            let tokens = try await OIDC.exchangeCode(
                environment: environment,
                oidcClientId: oidcClientId,
                redirectURI: redirectURL.absoluteString,
                code: payload.code,
                codeVerifier: authRequest.codeVerifier
            )

            let session = SmbCloudSession(tokenResponse: tokens)
            try credentialsManager?.store(session)
            return session
        }

        private static func authenticationError(from error: Error) -> SmbCloudWebAuthError {
            if let authError = error as? ASWebAuthenticationSessionError,
                authError.code == .canceledLogin
            {
                return .cancelled
            }
            return .authenticationFailed(error.localizedDescription)
        }
    }

    private final class SmbCloudPresentationContextProvider:
        NSObject, ASWebAuthenticationPresentationContextProviding
    {
        private let presentationAnchorProvider: () -> SmbCloudPresentationAnchor

        init(presentationAnchorProvider: @escaping () -> SmbCloudPresentationAnchor) {
            self.presentationAnchorProvider = presentationAnchorProvider
        }

        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            presentationAnchorProvider()
        }
    }
#endif
