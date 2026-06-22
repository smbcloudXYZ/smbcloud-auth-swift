import Foundation

/// The smbCloud environment to target.
///
/// Mirrors `smbcloud_network::environment::Environment` in the canonical Rust
/// SDK: `dev` points at the local auth service over plain HTTP loopback, and
/// `production` at the hosted service over HTTPS.
public enum SmbCloudEnvironment: Sendable, Equatable {
    case dev
    case production
    /// Escape hatch for self-hosted / staging deployments.
    case custom(scheme: String, host: String)

    /// `http` for `dev`, `https` for `production`.
    public var apiProtocol: String {
        switch self {
        case .dev: return "http"
        case .production: return "https"
        case .custom(let scheme, _): return scheme
        }
    }

    /// `localhost:8088` for `dev`, `api.smbcloud.xyz` for `production`.
    public var apiHost: String {
        switch self {
        case .dev: return "localhost:8088"
        case .production: return "api.smbcloud.xyz"
        case .custom(_, let host): return host
        }
    }

    /// The issuer base URL (`<scheme>://<host>/`), used by the OIDC endpoints.
    var baseURL: URL {
        URL(string: "\(apiProtocol)://\(apiHost)/")!
    }
}
