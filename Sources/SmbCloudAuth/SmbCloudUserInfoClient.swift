import Foundation

public struct SmbCloudUserInfoClient {
    private let client: SmbCloudOpenIDConnectClient

    public init(environment: SmbCloudEnvironment = .production) {
        self.client = SmbCloudOpenIDConnectClient(
            baseURL: SmbCloudBaseURLFactory.makeURL(for: environment)
        )
    }

    public init(baseURL: URL) {
        self.client = SmbCloudOpenIDConnectClient(baseURL: baseURL)
    }

    public init(domain: String) throws {
        self.client = SmbCloudOpenIDConnectClient(
            baseURL: try SmbCloudBaseURLFactory.makeURL(from: domain)
        )
    }

    public func userInfo(accessToken: String, tenantId: String? = nil) async throws
        -> SmbCloudUserInfo
    {
        try await client.userInfo(accessToken: accessToken, tenantId: tenantId)
    }

    public func userInfo(session: SmbCloudSession, tenantId: String? = nil) async throws
        -> SmbCloudUserInfo
    {
        try await userInfo(accessToken: session.accessToken, tenantId: tenantId)
    }
}
