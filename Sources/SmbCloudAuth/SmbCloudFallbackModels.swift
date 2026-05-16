import Foundation

#if !SMBCLOUD_AUTH_FFI_AVAILABLE
    public enum SmbCloudEnvironment: Sendable {
        case dev
        case production
    }

    public struct SmbCloudUserInfo: Codable, Equatable, Hashable, Sendable {
        public let sub: String
        public let email: String?
        public let emailVerified: Bool?
        public let tenantId: UInt64?
        public let tenantSlug: String?

        public init(
            sub: String,
            email: String? = nil,
            emailVerified: Bool? = nil,
            tenantId: UInt64? = nil,
            tenantSlug: String? = nil
        ) {
            self.sub = sub
            self.email = email
            self.emailVerified = emailVerified
            self.tenantId = tenantId
            self.tenantSlug = tenantSlug
        }
    }
#endif
