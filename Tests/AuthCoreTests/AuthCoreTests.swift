import Foundation
import XCTest

@testable import AuthCore

final class AuthCoreTests: XCTestCase {
    func testSessionScopeJoinsScopesWithSpaces() {
        let session = SmbCloudSession(
            accessToken: "token",
            scopes: ["openid", "profile", "email"]
        )

        XCTAssertEqual(session.scope, "openid profile email")
        XCTAssertEqual(session.authorizationHeaderValue, "Bearer token")
    }

    func testSessionValidityReflectsExpiryDate() {
        let futureSession = SmbCloudSession(
            accessToken: "future-token",
            expiresAt: Date().addingTimeInterval(300)
        )
        let pastSession = SmbCloudSession(
            accessToken: "past-token",
            expiresAt: Date().addingTimeInterval(-300)
        )

        XCTAssertTrue(futureSession.isValid())
        XCTAssertFalse(futureSession.isExpired)
        XCTAssertFalse(pastSession.isValid(leeway: 0))
        XCTAssertTrue(pastSession.isExpired)
    }

    func testSessionCodableRoundTripPreservesValues() throws {
        let originalSession = SmbCloudSession(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            idToken: "id-token",
            tokenType: "Bearer",
            expiresAt: Date(timeIntervalSince1970: 1_750_000_000),
            scopes: ["openid", "profile", "email"]
        )

        let encodedSession = try JSONEncoder().encode(originalSession)
        let decodedSession = try JSONDecoder().decode(SmbCloudSession.self, from: encodedSession)

        XCTAssertEqual(decodedSession, originalSession)
    }

    func testInMemoryCredentialsStoreRoundTrips() throws {
        let store = SmbCloudInMemoryCredentialsStore()
        XCTAssertNil(try store.current())

        let session = SmbCloudSession(
            accessToken: "access-token",
            expiresAt: Date().addingTimeInterval(300),
            scopes: ["openid", "openid", " profile "]
        )
        try store.store(session)

        // storedRepresentation() normalizes/uniques scopes.
        XCTAssertEqual(try store.current()?.scopes, ["openid", "profile"])
        XCTAssertTrue(try store.hasValidSession())
        XCTAssertNotNil(try store.currentValidSession())

        try store.clear()
        XCTAssertNil(try store.current())
        XCTAssertFalse(try store.hasValidSession())
    }

    func testExpiredSessionIsNotReturnedAsValid() throws {
        let store = SmbCloudInMemoryCredentialsStore(
            session: SmbCloudSession(
                accessToken: "stale",
                expiresAt: Date().addingTimeInterval(-300)
            )
        )

        XCTAssertNotNil(try store.current())
        XCTAssertNil(try store.currentValidSession())
        XCTAssertFalse(try store.hasValidSession())
    }

    func testInvalidUserInfoDomainThrowsInvalidBaseUrlError() {
        XCTAssertThrowsError(try SmbCloudUserInfoClient(domain: " ")) { error in
            guard case SmbCloudClientError.invalidBaseURL = error else {
                return XCTFail("Expected invalidBaseURL error, got: \(error)")
            }
        }
    }

    func testInvalidAuthClientDomainThrowsInvalidBaseUrlError() {
        XCTAssertThrowsError(
            try SmbCloudAuthClient(
                domain: " ",
                clientId: "public-client-id",
                redirectURL: URL(string: "myapp://auth/callback")!
            )
        ) { error in
            guard case SmbCloudClientError.invalidBaseURL = error else {
                return XCTFail("Expected invalidBaseURL error, got: \(error)")
            }
        }
    }

    func testHttpLoopbackDomainIsAllowed() {
        XCTAssertNoThrow(
            try SmbCloudAuthClient(
                domain: "http://localhost:8088",
                clientId: "public-client-id",
                redirectURL: URL(string: "myapp://auth/callback")!
            )
        )
        XCTAssertNoThrow(try SmbCloudUserInfoClient(domain: "http://127.0.0.1:8088"))
    }

    func testHttpRemoteDomainThrowsInvalidBaseUrlError() {
        XCTAssertThrowsError(try SmbCloudUserInfoClient(domain: "http://api.smbcloud.xyz")) {
            error in
            guard case SmbCloudClientError.invalidBaseURL = error else {
                return XCTFail("Expected invalidBaseURL error, got: \(error)")
            }
        }

        XCTAssertThrowsError(
            try SmbCloudAuthClient(
                domain: "http://api.smbcloud.xyz",
                clientId: "public-client-id",
                redirectURL: URL(string: "myapp://auth/callback")!
            )
        ) { error in
            guard case SmbCloudClientError.invalidBaseURL = error else {
                return XCTFail("Expected invalidBaseURL error, got: \(error)")
            }
        }
    }

    func testAuthorizationRequestProducesPkceChallenge() throws {
        let client = SmbCloudAuthClient(
            baseURL: URL(string: "https://api.smbcloud.xyz")!,
            clientId: "public-client-id",
            redirectURL: URL(string: "myapp://auth/callback")!
        )

        let request = try client.authorizationRequest()
        let components = URLComponents(
            url: request.authorizeURL,
            resolvingAgainstBaseURL: false
        )
        let queryItems = components?.queryItems ?? []

        XCTAssertEqual(queryItems.firstValue(named: "response_type"), "code")
        XCTAssertEqual(queryItems.firstValue(named: "code_challenge_method"), "S256")
        XCTAssertEqual(queryItems.firstValue(named: "client_id"), "public-client-id")
        XCTAssertEqual(queryItems.firstValue(named: "state"), request.state)
        XCTAssertEqual(queryItems.firstValue(named: "scope"), "openid profile email")
        XCTAssertFalse(request.codeVerifier.isEmpty)
        XCTAssertNotNil(queryItems.firstValue(named: "code_challenge"))
    }

    func testCallbackScheme() {
        let client = SmbCloudAuthClient(
            baseURL: URL(string: "https://api.smbcloud.xyz")!,
            clientId: "public-client-id",
            redirectURL: URL(string: "myapp://auth/callback")!
        )

        XCTAssertEqual(client.callbackScheme, "myapp")
    }

    func testStateMismatchErrorDescriptionDoesNotExposeStateValues() {
        let error = SmbCloudClientError.stateMismatch(
            expected: "expected-state",
            received: "received-state"
        )

        XCTAssertEqual(error.errorDescription, "The callback state did not match.")
    }

    func testDefaultScopesMatchOidcDefaults() {
        XCTAssertEqual(SmbCloudAuthClient.defaultScopes, ["openid", "profile", "email"])
    }
}
