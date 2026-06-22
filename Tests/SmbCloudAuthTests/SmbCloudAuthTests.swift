import Foundation
import XCTest

import SmbCloudAuth

final class SmbCloudAuthTests: XCTestCase {
    func testWebAuthExposesConfiguration() {
        let webAuth = SmbCloudWebAuth(
            environment: .production,
            oidcClientId: "oidc-client-id",
            redirectURL: URL(string: "myapp://auth/callback")!
        )
        XCTAssertEqual(webAuth.oidcClientId, "oidc-client-id")
        XCTAssertEqual(webAuth.callbackScheme, "myapp")
        XCTAssertEqual(webAuth.environment, .production)
    }

    func testWebAuthCallbackSchemeNilWhenMissing() {
        let webAuth = SmbCloudWebAuth(
            oidcClientId: "x", redirectURL: URL(string: "/no-scheme")!)
        XCTAssertNil(webAuth.callbackScheme)
    }

    #if canImport(Security)
        func testCredentialsManagerUsesExplicitServiceWhenProvided() {
            let manager = SmbCloudCredentialsManager(service: "xyz.smbcloud.tests", account: "tester")
            XCTAssertEqual(manager.service, "xyz.smbcloud.tests")
            XCTAssertEqual(manager.account, "tester")
        }

        func testCredentialsManagerConformsToCredentialsStore() {
            let manager: SmbCloudCredentialsStore = SmbCloudCredentialsManager(service: "xyz.smbcloud.tests")
            XCTAssertNotNil(manager)
        }
    #endif
}
