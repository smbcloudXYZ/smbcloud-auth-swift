import Foundation
import XCTest

@testable import SmbCloudAuth

final class SmbCloudAuthTests: XCTestCase {
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

    func testCredentialsManagerUsesExplicitServiceWhenProvided() {
        let manager = SmbCloudCredentialsManager(service: "xyz.smbcloud.tests", account: "tester")

        XCTAssertEqual(manager.service, "xyz.smbcloud.tests")
        XCTAssertEqual(manager.account, "tester")
    }

    func testInvalidUserInfoDomainThrowsInvalidBaseUrlError() {
        XCTAssertThrowsError(try SmbCloudUserInfoClient(domain: " ")) { error in
            guard case SmbCloudClientError.invalidBaseURL = error else {
                return XCTFail("Expected invalidBaseURL error, got: \(error)")
            }
        }
    }

    func testInvalidWebAuthDomainThrowsInvalidBaseUrlError() {
        XCTAssertThrowsError(
            try SmbCloudWebAuth(
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

    func testDefaultScopesMatchOidcDefaults() {
        XCTAssertEqual(SmbCloudWebAuth.defaultScopes, ["openid", "profile", "email"])
    }
}
