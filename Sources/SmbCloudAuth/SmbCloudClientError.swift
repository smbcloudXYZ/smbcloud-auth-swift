import Foundation

public enum SmbCloudClientError: Error, LocalizedError, Sendable {
    case invalidBaseURL(String)
    case invalidRedirectURL(String)
    case invalidCallbackURL(String)
    case missingAuthorizationCode
    case missingAuthorizationState
    case stateMismatch(expected: String, received: String)
    case unsupportedPlatform
    case loginInProgress
    case cancelled
    case authenticationFailed(String?)
    case transportError(String)
    case invalidResponse
    case decodingFailed(String)
    case apiError(statusCode: Int?, errorCode: Int?, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let message):
            return message
        case .invalidRedirectURL(let message):
            return message
        case .invalidCallbackURL(let message):
            return message
        case .missingAuthorizationCode:
            return "The callback URL did not include an authorization code."
        case .missingAuthorizationState:
            return "The callback URL did not include an authorization state value."
        case .stateMismatch:
            return "The callback state did not match."
        case .unsupportedPlatform:
            return "Hosted web authentication is not supported on this platform."
        case .loginInProgress:
            return "A web authentication session is already in progress."
        case .cancelled:
            return "The authentication session was cancelled."
        case .authenticationFailed(let message):
            return message ?? "The authentication session failed."
        case .transportError(let message):
            return message
        case .invalidResponse:
            return "The server returned an invalid response."
        case .decodingFailed(let message):
            return message
        case .apiError(let statusCode, let errorCode, let message):
            let parts = [
                statusCode.map { "HTTP \($0)" },
                errorCode.map { "API \($0)" },
                message.nilIfEmpty,
            ].compactMap { $0 }

            return parts.isEmpty
                ? "The smbCloud Auth API returned an error." : parts.joined(separator: " — ")
        }
    }
}
