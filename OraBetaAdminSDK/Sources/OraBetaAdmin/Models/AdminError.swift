import Foundation

/// Admin SDK-specific errors
public enum AdminError: Error, LocalizedError {
    case invalidConfiguration
    case invalidInput(String)
    case networkError(Error)
    case serverError(String)
    case unauthorized
    case forbidden
    case notFound
    case unknown
    case rateLimited(retryAfter: Int?)
    case validationError(field: String, message: String)
    case conflict(message: String)
    case timeout
    case badRequest(message: String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid SDK configuration. Please check your base URL and configuration."
        case .invalidInput(let message):
            return "Invalid input: \(message). Please check your parameters and try again."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription). Please check your internet connection and try again."
        case .serverError(let message):
            return "Server error: \(message). Please try again later or contact support if the problem persists."
        case .unauthorized:
            return "Unauthorized: Your session has expired. Please login again."
        case .forbidden:
            return "Forbidden: You don't have permission to perform this action. Contact your administrator if you believe this is an error."
        case .notFound:
            return "Resource not found. The requested item may have been deleted or doesn't exist."
        case .unknown:
            return "Unknown error occurred. Please try again or contact support if the problem persists."
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limit exceeded. Please wait \(retryAfter) seconds before trying again."
            } else {
                return "Rate limit exceeded. Please wait a moment before trying again."
            }
        case .validationError(let field, let message):
            return "Validation error in field '\(field)': \(message). Please correct the input and try again."
        case .conflict(let message):
            return "Conflict: \(message). The resource may have been modified by another user."
        case .timeout:
            return "Request timeout. The server took too long to respond. Please check your connection and try again."
        case .badRequest(let message):
            return "Bad request: \(message). Please check your parameters and try again."
        }
    }
    
    /// HTTP status code associated with the error
    public var statusCode: Int? {
        switch self {
        case .badRequest:
            return 400
        case .unauthorized:
            return 401
        case .forbidden:
            return 403
        case .notFound:
            return 404
        case .conflict:
            return 409
        case .rateLimited:
            return 429
        case .timeout:
            return 408
        case .serverError:
            return 500
        default:
            return nil
        }
    }
}






