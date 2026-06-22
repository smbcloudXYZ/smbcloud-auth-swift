import Foundation

/// An error returned by the smbCloud Auth API.
///
/// Mirrors `smbcloud_model::error_codes::ErrorResponse::Error { error_code,
/// message }` from the canonical SDK.
public struct SmbCloudError: Error, Sendable, Equatable {
    public let code: SmbCloudErrorCode
    public let message: String

    public init(code: SmbCloudErrorCode, message: String? = nil) {
        self.code = code
        self.message = message ?? code.defaultMessage
    }
}

extension SmbCloudError: LocalizedError {
    public var errorDescription: String? { message }
}

/// Mirrors `smbcloud_model::error_codes::ErrorCode` (the `i32`-repr enum).
public enum SmbCloudErrorCode: Int, Sendable, Equatable {
    // Generic
    case unknown = 0
    case parseError = 1
    case networkError = 2
    case inputError = 3
    case missingConfig = 4
    case cancel = 5
    // Account / access
    case unauthorized = 100
    case invalidParams = 101
    // Account-not-ready
    case emailNotFound = 1000
    case emailNotVerified = 1001
    case emailConfirmationFailed = 1002
    case passwordNotSet = 1003
    case gitHubEmailNotConnected = 1004
    case emailAlreadyExist = 1005
    case invalidPassword = 1006
    // Projects
    case projectNotFound = 2000
    case unsupportedRunner = 2001

    public var defaultMessage: String {
        switch self {
        case .unknown: return "Unknown error."
        case .parseError: return "Parse error."
        case .networkError:
            return "Network error. Please check your internet connection and try again."
        case .inputError: return "Input error."
        case .missingConfig: return "Missing config."
        case .cancel: return "Cancelled."
        case .unauthorized: return "Unauthorized access."
        case .invalidParams: return "Invalid parameters."
        case .emailNotFound: return "Email not found."
        case .emailNotVerified: return "Email not verified."
        case .emailConfirmationFailed: return "Email confirmation failed."
        case .passwordNotSet: return "Password is not set."
        case .gitHubEmailNotConnected: return "GitHub email is not connected."
        case .emailAlreadyExist: return "Email already exists."
        case .invalidPassword: return "Invalid password."
        case .projectNotFound: return "Project not found."
        case .unsupportedRunner: return "Unsupported runner."
        }
    }
}

/// Account-status error codes used inside ``AccountStatus/incomplete(status:)``.
///
/// Mirrors `smbcloud_model::account::ErrorCode` (the `u32`-repr enum), which is
/// distinct from ``SmbCloudErrorCode``.
public enum AccountErrorCode: Int, Sendable, Equatable {
    case emailNotFound = 1000
    case emailUnverified = 1001
    case emailConfirmationFailed = 1002
    case passwordNotSet = 1003
    case githubNotLinked = 1004
    case emailAlreadyExist = 1005
    case invalidPassword = 1006
    case hostedMailAccountUnverified = 1007
}
