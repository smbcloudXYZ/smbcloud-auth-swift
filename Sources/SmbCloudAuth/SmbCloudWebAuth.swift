import Foundation

#if canImport(AuthenticationServices) && (os(iOS) || os(macOS) || os(visionOS))
    import AuthenticationServices

    public typealias SmbCloudPresentationAnchor = ASPresentationAnchor
#endif

public final class SmbCloudWebAuth: @unchecked Sendable {
    public static let defaultScopes: [String] = ["openid", "profile", "email"]

    private let clientId: String
    private let redirectURL: URL
    private let client: SmbCloudOpenIDConnectClient
    private let userInfoClient: SmbCloudUserInfoClient

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

    public func clearSession(credentialsManager: SmbCloudCredentialsManager? = nil) throws {
        try credentialsManager?.clear()
    }

    public func logout(credentialsManager: SmbCloudCredentialsManager? = nil) throws {
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
            credentialsManager: SmbCloudCredentialsManager? = nil
        ) async throws -> SmbCloudSession {
            guard activeAuthenticationSession == nil else {
                throw SmbCloudClientError.loginInProgress
            }

            let authorizationRequest = try client.authorizationRequest(
                clientId: clientId,
                redirectURL: redirectURL,
                scopes: scopes,
                audience: audience
            )

            let callbackScheme = redirectURL.scheme?.nilIfEmpty
            guard let callbackScheme else {
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

            let authorizationCode = try client.parseAuthorizationCode(
                from: callbackURL,
                expectedState: authorizationRequest.state
            )

            let session = try await client.exchangeCode(
                clientId: clientId,
                redirectURL: redirectURL,
                code: authorizationCode,
                codeVerifier: authorizationRequest.codeVerifier
            )

            if let credentialsManager {
                try credentialsManager.store(session)
            }

            return session
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
