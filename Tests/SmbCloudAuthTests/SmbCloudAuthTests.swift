import Foundation
import XCTest

import SmbCloudAuth

final class SmbCloudAuthTests: XCTestCase {
    func testWebAuthDefaultScopesMatchOidcDefaults() {
        XCTAssertEqual(SmbCloudWebAuth.defaultScopes, ["openid", "profile", "email"])
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

    func testWebAuthExposesUnderlyingAuthClient() throws {
        let webAuth = try SmbCloudWebAuth(
            domain: "api.smbcloud.xyz",
            clientId: "public-client-id",
            redirectURL: URL(string: "myapp://auth/callback")!
        )

        XCTAssertEqual(webAuth.client.clientId, "public-client-id")
        XCTAssertEqual(webAuth.client.callbackScheme, "myapp")
    }

    #if canImport(Security)
        func testCredentialsManagerUsesExplicitServiceWhenProvided() {
            let manager = SmbCloudCredentialsManager(
                service: "xyz.smbcloud.tests", account: "tester")

            XCTAssertEqual(manager.service, "xyz.smbcloud.tests")
            XCTAssertEqual(manager.account, "tester")
        }

        func testCredentialsManagerConformsToCredentialsStore() {
            let manager: SmbCloudCredentialsStore = SmbCloudCredentialsManager(
                service: "xyz.smbcloud.tests")
            XCTAssertNotNil(manager)
        }
    #endif
}
