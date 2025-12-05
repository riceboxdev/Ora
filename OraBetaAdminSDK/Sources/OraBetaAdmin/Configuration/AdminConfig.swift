import Foundation

/// Configuration for the OraBeta Admin SDK
public struct AdminConfig {
    /// The base URL of the admin API server
    public let baseURL: String
    
    /// The JWT token for authentication (obtained from login)
    public var token: String?
    
    /// Token expiry date (24 hours from login by default)
    public var tokenExpiryDate: Date?
    
    /// Whether caching is enabled
    public let cacheEnabled: Bool
    
    /// Default base URL for the admin API
    /// Note: On Render free tier, the backend may be asleep and take 30-60s to wake up on first request
    public static let defaultBaseURL = "https://ora-admin-api.onrender.com"
    
    /// Default token expiry duration (24 hours)
    public static let defaultTokenExpiry: TimeInterval = 24 * 60 * 60
    
    /// Initialize a new Admin configuration
    /// - Parameters:
    ///   - baseURL: Optional custom base URL (defaults to production)
    ///   - token: Optional JWT token (can be set after login)
    ///   - tokenExpiryDate: Optional token expiry date
    ///   - cacheEnabled: Whether to enable response caching (default: true)
    public init(baseURL: String = AdminConfig.defaultBaseURL, token: String? = nil, tokenExpiryDate: Date? = nil, cacheEnabled: Bool = true) {
        self.baseURL = baseURL
        self.token = token
        self.tokenExpiryDate = tokenExpiryDate
        self.cacheEnabled = cacheEnabled
    }
    
    /// Validates the configuration
    public var isValid: Bool {
        return !baseURL.isEmpty
    }
    
    /// Check if token is expired
    public var isTokenExpired: Bool {
        guard let expiryDate = tokenExpiryDate else {
            return false // If no expiry date, assume not expired
        }
        return Date() >= expiryDate
    }
    
    /// Create a new config with updated token
    /// - Parameter token: The new JWT token
    /// - Returns: New AdminConfig with updated token and expiry date
    public func withToken(_ token: String) -> AdminConfig {
        var config = self
        config.token = token
        // Set expiry to 24 hours from now
        config.tokenExpiryDate = Date().addingTimeInterval(AdminConfig.defaultTokenExpiry)
        return config
    }
    
    /// Create a new config with updated token and expiry date
    /// - Parameters:
    ///   - token: The new JWT token
    ///   - expiryDate: The token expiry date
    /// - Returns: New AdminConfig with updated token and expiry date
    public func withToken(_ token: String, expiryDate: Date) -> AdminConfig {
        var config = self
        config.token = token
        config.tokenExpiryDate = expiryDate
        return config
    }
}






