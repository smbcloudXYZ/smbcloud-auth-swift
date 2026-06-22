import Foundation
import XCTest

@testable import AuthCore

final class AuthCoreTests: XCTestCase {

    // MARK: - Session

    func testSessionScopeJoinsScopesWithSpaces() {
        let session = SmbCloudSession(accessToken: "token", scopes: ["openid", "profile", "email"])
        XCTAssertEqual(session.scope, "openid profile email")
        XCTAssertEqual(session.authorizationHeaderValue, "Bearer token")
    }

    func testSessionValidityReflectsExpiryDate() {
        let future = SmbCloudSession(accessToken: "f", expiresAt: Date().addingTimeInterval(300))
        let past = SmbCloudSession(accessToken: "p", expiresAt: Date().addingTimeInterval(-300))
        XCTAssertTrue(future.isValid())
        XCTAssertFalse(future.isExpired)
        XCTAssertFalse(past.isValid(leeway: 0))
        XCTAssertTrue(past.isExpired)
    }

    func testSessionCodableRoundTripPreservesValues() throws {
        let original = SmbCloudSession(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            idToken: "id-token",
            tokenType: "Bearer",
            expiresAt: Date(timeIntervalSince1970: 1_750_000_000),
            scopes: ["openid", "profile", "email"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SmbCloudSession.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testSessionFromTokenResponseMapsFields() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let token = OIDC.TokenResponse(
            accessToken: "at", tokenType: "Bearer", expiresIn: 3600,
            refreshToken: "rt", scope: "openid profile openid", idToken: "it")
        let session = SmbCloudSession(tokenResponse: token, now: now)
        XCTAssertEqual(session.accessToken, "at")
        XCTAssertEqual(session.refreshToken, "rt")
        XCTAssertEqual(session.idToken, "it")
        XCTAssertEqual(session.expiresAt, now.addingTimeInterval(3600))
        XCTAssertEqual(session.scopes, ["openid", "profile"])  // deduped
    }

    // MARK: - Credentials store

    func testInMemoryCredentialsStoreRoundTrips() throws {
        let store = SmbCloudInMemoryCredentialsStore()
        XCTAssertNil(try store.current())

        try store.store(
            SmbCloudSession(
                accessToken: "access-token",
                expiresAt: Date().addingTimeInterval(300),
                scopes: ["openid", "openid", " profile "]))

        XCTAssertEqual(try store.current()?.scopes, ["openid", "profile"])
        XCTAssertTrue(try store.hasValidSession())
        XCTAssertNotNil(try store.currentValidSession())

        try store.clear()
        XCTAssertNil(try store.current())
    }

    func testExpiredSessionIsNotReturnedAsValid() throws {
        let store = SmbCloudInMemoryCredentialsStore(
            session: SmbCloudSession(accessToken: "stale", expiresAt: Date().addingTimeInterval(-300)))
        XCTAssertNotNil(try store.current())
        XCTAssertNil(try store.currentValidSession())
        XCTAssertFalse(try store.hasValidSession())
    }

    // MARK: - Environment

    func testEnvironmentHostsAndProtocols() {
        XCTAssertEqual(SmbCloudEnvironment.dev.apiProtocol, "http")
        XCTAssertEqual(SmbCloudEnvironment.dev.apiHost, "localhost:8088")
        XCTAssertEqual(SmbCloudEnvironment.production.apiProtocol, "https")
        XCTAssertEqual(SmbCloudEnvironment.production.apiHost, "api.smbcloud.xyz")
        XCTAssertEqual(SmbCloudEnvironment.production.baseURL.absoluteString, "https://api.smbcloud.xyz/")
    }

    // MARK: - ClientCredentials URL building

    func testTenantURLCarriesCredentialsAsQuery() {
        let creds = ClientCredentials(appId: "app-1", appSecret: "secret-1")
        let url = creds.tenantURL(environment: .production, path: "v1/client/me")
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        XCTAssertEqual(comps?.scheme, "https")
        XCTAssertEqual(comps?.host, "api.smbcloud.xyz")
        XCTAssertEqual(comps?.path, "/v1/client/me")
        XCTAssertEqual(query(url, "client_id"), "app-1")
        XCTAssertEqual(query(url, "client_secret"), "secret-1")
    }

    func testTenantURLDevPreservesPort() {
        let creds = ClientCredentials(appId: "a", appSecret: "s")
        let url = creds.tenantURL(environment: .dev, path: "v1/client/users/sign_in")
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        XCTAssertEqual(comps?.host, "localhost")
        XCTAssertEqual(comps?.port, 8088)
        XCTAssertEqual(comps?.scheme, "http")
    }

    // MARK: - OIDC

    func testOIDCAuthorizationRequestProducesPkceChallenge() throws {
        let request = try OIDC.buildAuthorizationRequest(
            environment: .production, oidcClientId: "oidc-1", redirectURI: "myapp://auth/callback")
        let url = request.authorizeURL
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.path, "/oauth/authorize")
        XCTAssertEqual(query(url, "response_type"), "code")
        XCTAssertEqual(query(url, "code_challenge_method"), "S256")
        XCTAssertEqual(query(url, "client_id"), "oidc-1")
        XCTAssertEqual(query(url, "scope"), "openid profile email")
        XCTAssertEqual(query(url, "state"), request.state)
        XCTAssertNotNil(query(url, "code_challenge"))
        XCTAssertEqual(request.codeVerifier.count, 64)  // two uuid-simple strings
    }

    func testOIDCParseCallbackURL() throws {
        let payload = try OIDC.parseCallbackURL("myapp://cb?code=abc&state=xyz")
        XCTAssertEqual(payload.code, "abc")
        XCTAssertEqual(payload.state, "xyz")
    }

    func testOIDCParseCallbackURLMissingParamsThrows() {
        XCTAssertThrowsError(try OIDC.parseCallbackURL("myapp://cb?code=abc")) { error in
            XCTAssertEqual((error as? SmbCloudError)?.code, .invalidParams)
        }
    }

    // MARK: - Apple provider

    func testBuildAppleAuthorizationRequest() {
        let client = AuthCoreClient(
            environment: .production, credentials: .init(appId: "app-1", appSecret: "secret-1"))
        let request = client.buildAppleAuthorizationRequest(redirectURI: "myapp://cb", state: "the-state")
        XCTAssertEqual(request.state, "the-state")
        XCTAssertEqual(
            URLComponents(url: request.authorizeURL, resolvingAgainstBaseURL: false)?.path,
            "/v1/client/oauth/apple/authorize")
        XCTAssertEqual(query(request.authorizeURL, "client_id"), "app-1")
        XCTAssertEqual(query(request.authorizeURL, "redirect_uri"), "myapp://cb")
        XCTAssertEqual(query(request.authorizeURL, "state"), "the-state")
    }

    func testParseAppleCallbackURL() throws {
        let client = AuthCoreClient(
            environment: .production, credentials: .init(appId: "a", appSecret: "s"))
        let session = try client.parseAppleCallbackURL(
            "myapp://cb?access_token=AT&provider_account_id=PA&email=e@x.com&state=S",
            expectedState: "S")
        XCTAssertEqual(session.accessToken, "AT")
        XCTAssertEqual(session.providerAccountId, "PA")
        XCTAssertEqual(session.email, "e@x.com")
        XCTAssertEqual(session.provider, "apple")
        XCTAssertEqual(session.state, "S")
    }

    func testParseAppleCallbackURLStateMismatchThrows() {
        let client = AuthCoreClient(
            environment: .production, credentials: .init(appId: "a", appSecret: "s"))
        XCTAssertThrowsError(
            try client.parseAppleCallbackURL(
                "myapp://cb?access_token=AT&provider_account_id=PA&state=S", expectedState: "other")
        ) { error in
            XCTAssertEqual((error as? SmbCloudError)?.code, .invalidParams)
        }
    }

    func testParseAppleCallbackURLPropagatesError() {
        let client = AuthCoreClient(
            environment: .production, credentials: .init(appId: "a", appSecret: "s"))
        XCTAssertThrowsError(
            try client.parseAppleCallbackURL("myapp://cb?error=access_denied")
        ) { error in
            XCTAssertEqual((error as? SmbCloudError)?.code, .invalidParams)
            XCTAssertEqual((error as? SmbCloudError)?.message, "access_denied")
        }
    }

    // MARK: - Errors

    func testErrorCodeRawValuesMatchContract() {
        XCTAssertEqual(SmbCloudErrorCode.unauthorized.rawValue, 100)
        XCTAssertEqual(SmbCloudErrorCode.emailNotVerified.rawValue, 1001)
        XCTAssertEqual(AccountErrorCode.emailUnverified.rawValue, 1001)
        XCTAssertEqual(SmbCloudError(code: .unauthorized).message, "Unauthorized access.")
    }

    // MARK: - Helpers

    private func query(_ url: URL, _ name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == name }?.value
    }
}
