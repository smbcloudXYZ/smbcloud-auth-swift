import Foundation

/// A tenant auth app's credentials.
///
/// Mirrors `client_credentials::ClientCredentials`. On every `/v1/client/*`
/// request these are sent as the `client_id` and `client_secret` **query
/// parameters** (see `tenantURL(path:)`).
///
/// The `appSecret` is confidential: hold it server-side (a Backend-for-Frontend
/// such as a Vapor service). Do not ship it in a distributed client binary or
/// browser bundle — native/public clients should use the OIDC or Apple flows,
/// or route through a backend.
public struct ClientCredentials: Sendable, Equatable {
    public let appId: String
    public let appSecret: String

    public init(appId: String, appSecret: String) {
        self.appId = appId
        self.appSecret = appSecret
    }
}

extension ClientCredentials {
    /// Builds `<scheme>://<host>/<path>?client_id=…&client_secret=…`, plus any
    /// extra query items, matching the Rust SDK's `base_url_builder`.
    func tenantURL(
        environment: SmbCloudEnvironment,
        path: String,
        extraQuery: [URLQueryItem] = []
    ) -> URL {
        var components = URLComponents()
        components.scheme = environment.apiProtocol
        // host may carry a port (e.g. "localhost:8088"); URLComponents.host
        // can't hold the port, so set them via the full string instead.
        let hostAndPort = environment.apiHost.split(separator: ":", maxSplits: 1)
        components.host = String(hostAndPort[0])
        if hostAndPort.count == 2 { components.port = Int(hostAndPort[1]) }
        components.path = "/" + path
        components.queryItems =
            [
                URLQueryItem(name: "client_id", value: appId),
                URLQueryItem(name: "client_secret", value: appSecret),
            ] + extraQuery
        return components.url!
    }
}
