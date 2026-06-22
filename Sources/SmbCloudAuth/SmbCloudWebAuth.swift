import AuthCore
import Foundation

#if canImport(AuthenticationServices) && (os(iOS) || os(macOS) || os(visionOS))
    import AuthenticationServices

    public typealias SmbCloudPresentationAnchor = ASPresentationAnchor
#endif

/// Apple-platform hosted login built on `AuthCore`.
///
/// `SmbCloudWebAuth` wraps the cross-platform ``SmbCloudAuthClient`` engine and
/// adds an `ASWebAuthenticationSession`-driven `login(...)` for iOS, macOS, and
/// visionOS. The non-interactive helpers (`userInfo`, `logout`, `clearSession`)
/// are available wherever the package builds.
///
/// For headless or non-Apple usage (Linux, Windows, Android, servers, tests),
/// use ``SmbCloudAuthClient`` from the `AuthCore` product directly.
public final class SmbCloudWebAuth: @unchecked Sendable {
    public static let defaultScopes: [String] = SmbCloudAuthClient.defaultScopes

    private let authClient: SmbCloudAuthClient

    #if canImport(AuthenticationServices) && (os(iOS) || os(macOS) || os(visionOS))
        @MainActor
        private var activeAuthenticationSession: ASWebAuthenticationSession?

        @MainActor
        private var activePresentationContextProvider: SmbCloudPresentationContextProvider?
    #endif

    public init(
        environment: SmbCloudEnvironment = .production,
        clientId: String,
        redirectURL: URL
    ) {
        self.authClient = SmbCloudAuthClient(
            environment: environment,
            clientId: clientId,
            redirectURL: redirectURL
        )
    }

    public init(baseURL: URL, clientId: String, redirectURL: URL) {
        self.authClient = SmbCloudAuthClient(
            baseURL: baseURL,
            clientId: clientId,
            redirectURL: redirectURL
        )
    }

    public convenience init(domain: String, clientId: String, redirectURL: URL) throws {
        let authClient = try SmbCloudAuthClient(
            domain: domain,
            clientId: clientId,
            redirectURL: redirectURL
        )
        self.init(authClient: authClient)
    }

    private init(authClient: SmbCloudAuthClient) {
        self.authClient = authClient
    }

    /// The underlying headless engine, exposed for advanced/cross-cutting use.
    public var client: SmbCloudAuthClient {
        authClient
    }

    public func userInfo(accessToken: String, tenantId: String? = nil) async throws
        -> SmbCloudUserInfo
    {
        try await authClient.userInfo(accessToken: accessToken, tenantId: tenantId)
    }

    public func userInfo(session: SmbCloudSession, tenantId: String? = nil) async throws
        -> SmbCloudUserInfo
    {
        try await authClient.userInfo(session: session, tenantId: tenantId)
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
        @MainActor
        public func login(
            presentationAnchorProvider: @escaping () -> SmbCloudPresentationAnchor,
            scopes: [String] = SmbCloudWebAuth.defaultScopes,
            audience: String? = nil,
            prefersEphemeralSession: Bool = false,
            credentialsManager: SmbCloudCredentialsStore? = nil
        ) async throws -> SmbCloudSession {
            guard activeAuthenticationSession == nil else {
                throw SmbCloudClientError.loginInProgress
            }

            let authorizationRequest = try authClient.authorizationRequest(
                scopes: scopes,
                audience: audience
            )

            guard let callbackScheme = authClient.callbackScheme else {
                throw SmbCloudClientError.invalidRedirectURL(
                    "The redirect URL must include a callback scheme."
                )
            }

            let presentationContextProvider = SmbCloudPresentationContextProvider(
                presentationAnchorProvider: presentationAnchorProvider
            )

            defer {
                activeAuthenticationSession = nil
                activePresentationContextProvider = nil
            }

            let callbackURL = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<URL, Error>) in
                    let session = ASWebAuthenticationSession(
                        url: authorizationRequest.authorizeURL,
                        callbackURLScheme: callbackScheme
                    ) { callbackURL, error in
                        if let error {
                            continuation.resume(throwing: Self.authenticationError(from: error))
                            return
                        }

                        guard let callbackURL else {
                            continuation.resume(
                                throwing: SmbCloudClientError.authenticationFailed(
                                    "The authentication session completed without a callback URL."
                                )
                            )
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
                            throwing: SmbCloudClientError.authenticationFailed(
                                "Failed to start the smbCloud web authentication session."
                            )
                        )
                        return
                    }
                }
            } onCancel: { [weak self] in
                guard let self else {
                    return
                }

                Task { @MainActor in
                    self.activeAuthenticationSession?.cancel()
                    self.activeAuthenticationSession = nil
                    self.activePresentationContextProvider = nil
                }
            }

            return try await authClient.exchangeCallback(
                callbackURL,
                authorizationRequest: authorizationRequest,
                credentialsStore: credentialsManager
            )
        }

        private static func authenticationError(from error: Error) -> SmbCloudClientError {
            if let authenticationError = error as? ASWebAuthenticationSessionError,
                authenticationError.code == .canceledLogin
            {
                return .cancelled
            }

            return .authenticationFailed(error.localizedDescription)
        }
    }

    private final class SmbCloudPresentationContextProvider:
        NSObject,
        ASWebAuthenticationPresentationContextProviding
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
