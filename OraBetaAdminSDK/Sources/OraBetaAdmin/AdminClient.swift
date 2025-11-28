import Foundation

/// Main client for interacting with the OraBeta Admin API
@available(iOS 15.0, macOS 12.0, *)
public final class AdminClient: @unchecked Sendable {
    private var config: AdminConfig
    private let session: URLSession
    private let maxRetries: Int
    private let retryDelay: TimeInterval
    private let cache: AdminCache
    
    /// Initialize a new Admin client
    /// - Parameters:
    ///   - config: The admin configuration
    ///   - session: Optional custom URLSession (defaults to `.shared`)
    ///   - maxRetries: Maximum number of retries for failed requests (default: 3)
    ///   - retryDelay: Initial delay between retries in seconds (default: 1.0)
    public init(config: AdminConfig, session: URLSession = .shared, maxRetries: Int = 3, retryDelay: TimeInterval = 1.0) {
        self.config = config
        self.session = session
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.cache = AdminCache()
    }
    
    /// Clear the cache
    public func clearCache() {
        cache.clear()
    }
    
    /// Update the authentication token
    /// - Parameter token: The JWT token from login
    public func setToken(_ token: String) {
        config = config.withToken(token)
    }
    
    // MARK: - Authentication
    
    /// Login with Firebase token
    /// - Parameter firebaseToken: Firebase ID token from Firebase Auth
    /// - Returns: AdminLoginResponse containing JWT token and admin info
    /// - Throws: AdminError if login fails
    public func login(firebaseToken: String) async throws -> AdminLoginResponse {
        guard config.isValid else {
            throw AdminError.invalidConfiguration
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "firebaseToken": firebaseToken
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AdminError.unknown
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                let decoder = JSONDecoder()
                let result = try decoder.decode(AdminLoginResponse.self, from: data)
                // Store token for future requests
                setToken(result.token)
                return result
            } else if httpResponse.statusCode == 401 {
                throw AdminError.unauthorized
            } else if httpResponse.statusCode == 403 {
                throw AdminError.forbidden
            } else {
                // Try to decode error message
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                let message = errorMessage?["message"] ?? errorMessage?["error"] ?? "Server error"
                
                // Log more details for debugging
                if let dataString = String(data: data, encoding: .utf8) {
                    print("Admin SDK Login Error - Status: \(httpResponse.statusCode), Response: \(dataString)")
                }
                
                throw AdminError.serverError(message)
            }
        } catch let error as AdminError {
            throw error
        } catch {
            print("Admin SDK Login Network Error: \(error.localizedDescription)")
            throw AdminError.networkError(error)
        }
    }
    
    /// Refresh the authentication token
    /// - Throws: AdminError if the refresh fails
    public func refreshToken() async throws {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/auth/refresh")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AdminError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                if let result = try? decoder.decode([String: String].self, from: data),
                   let newToken = result["token"] {
                    setToken(newToken)
                } else {
                    throw AdminError.serverError("Invalid refresh response")
                }
            } else if httpResponse.statusCode == 401 {
                throw AdminError.unauthorized
            } else {
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                throw AdminError.serverError(errorMessage?["message"] ?? "Token refresh failed")
            }
        } catch let error as AdminError {
            throw error
        } catch {
            throw AdminError.networkError(error)
        }
    }
    
    /// Get current admin user info
    /// - Returns: AdminUser information
    /// - Throws: AdminError if the request fails
    public func getCurrentAdmin() async throws -> AdminUser {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/auth/me")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AdminError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                return try decoder.decode(AdminUser.self, from: data)
            } else if httpResponse.statusCode == 401 {
                throw AdminError.unauthorized
            } else {
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                throw AdminError.serverError(errorMessage?["message"] ?? "Server error")
            }
        } catch let error as AdminError {
            throw error
        } catch {
            throw AdminError.networkError(error)
        }
    }
    
    // MARK: - User Management
    
    /// Get all users
    /// - Parameters:
    ///   - limit: Maximum number of users to return
    ///   - offset: Number of users to skip
    /// - Returns: UsersResponse containing list of users
    /// - Throws: AdminError if the request fails
    public func getUsers(limit: Int = 50, offset: Int = 0) async throws -> UsersResponse {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        var components = URLComponents(string: "\(config.baseURL)/api/admin/users")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        
        guard let url = components.url else {
            throw AdminError.invalidConfiguration
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AdminError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                return try decoder.decode(UsersResponse.self, from: data)
            } else if httpResponse.statusCode == 401 {
                throw AdminError.unauthorized
            } else if httpResponse.statusCode == 403 {
                throw AdminError.forbidden
            } else {
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                throw AdminError.serverError(errorMessage?["message"] ?? "Server error")
            }
        } catch let error as AdminError {
            throw error
        } catch {
            throw AdminError.networkError(error)
        }
    }
    
    /// Ban a user
    /// - Parameter userId: The user ID to ban
    /// - Throws: AdminError if the request fails
    public func banUser(userId: String) async throws {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/users/ban")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = ["userId": userId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        try await executeRequest(request: request)
    }
    
    /// Unban a user
    /// - Parameter userId: The user ID to unban
    /// - Throws: AdminError if the request fails
    public func unbanUser(userId: String) async throws {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/users/unban")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = ["userId": userId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        try await executeRequest(request: request)
    }
    
    /// Get detailed user information
    /// - Parameter userId: The user ID
    /// - Returns: UserDetailsResponse with full user details and stats
    /// - Throws: AdminError if the request fails
    public func getUserDetails(userId: String) async throws -> UserDetailsResponse {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/users/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AdminError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                return try decoder.decode(UserDetailsResponse.self, from: data)
            } else if httpResponse.statusCode == 401 {
                throw AdminError.unauthorized
            } else if httpResponse.statusCode == 403 {
                throw AdminError.forbidden
            } else if httpResponse.statusCode == 404 {
                throw AdminError.notFound
            } else {
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                throw AdminError.serverError(errorMessage?["message"] ?? "Server error")
            }
        } catch let error as AdminError {
            throw error
        } catch {
            throw AdminError.networkError(error)
        }
    }
    
    /// Get user activity log
    /// - Parameters:
    ///   - userId: The user ID
    ///   - limit: Maximum number of activities to return (default: 50)
    ///   - offset: Number of activities to skip (default: 0)
    ///   - activityType: Filter by activity type ("post", "comment", or nil for all)
    ///   - startDate: Optional start date timestamp (milliseconds)
    ///   - endDate: Optional end date timestamp (milliseconds)
    /// - Returns: UserActivityResponse with activity entries
    /// - Throws: AdminError if the request fails
    public func getUserActivity(userId: String, limit: Int = 50, offset: Int = 0, activityType: String? = nil, startDate: Int64? = nil, endDate: Int64? = nil) async throws -> UserActivityResponse {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        var components = URLComponents(string: "\(config.baseURL)/api/admin/users/\(userId)/activity")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        
        if let activityType = activityType {
            queryItems.append(URLQueryItem(name: "activityType", value: activityType))
        }
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "startDate", value: String(startDate)))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "endDate", value: String(endDate)))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw AdminError.invalidConfiguration
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AdminError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                return try decoder.decode(UserActivityResponse.self, from: data)
            } else if httpResponse.statusCode == 401 {
                throw AdminError.unauthorized
            } else if httpResponse.statusCode == 403 {
                throw AdminError.forbidden
            } else if httpResponse.statusCode == 404 {
                throw AdminError.notFound
            } else {
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                throw AdminError.serverError(errorMessage?["message"] ?? "Server error")
            }
        } catch let error as AdminError {
            throw error
        } catch {
            throw AdminError.networkError(error)
        }
    }
    
    /// Get user's posts
    /// - Parameters:
    ///   - userId: The user ID
    ///   - limit: Maximum number of posts to return (default: 50)
    ///   - offset: Number of posts to skip (default: 0)
    ///   - status: Filter by moderation status ("pending", "approved", "rejected", "flagged", "all", or nil)
    ///   - startDate: Optional start date timestamp (milliseconds)
    ///   - endDate: Optional end date timestamp (milliseconds)
    /// - Returns: PostsResponse with user's posts
    /// - Throws: AdminError if the request fails
    public func getUserPosts(userId: String, limit: Int = 50, offset: Int = 0, status: String? = nil, startDate: Int64? = nil, endDate: Int64? = nil) async throws -> PostsResponse {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        var components = URLComponents(string: "\(config.baseURL)/api/admin/users/\(userId)/posts")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "startDate", value: String(startDate)))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "endDate", value: String(endDate)))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw AdminError.invalidConfiguration
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AdminError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                return try decoder.decode(PostsResponse.self, from: data)
            } else if httpResponse.statusCode == 401 {
                throw AdminError.unauthorized
            } else if httpResponse.statusCode == 403 {
                throw AdminError.forbidden
            } else if httpResponse.statusCode == 404 {
                throw AdminError.notFound
            } else {
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                throw AdminError.serverError(errorMessage?["message"] ?? "Server error")
            }
        } catch let error as AdminError {
            throw error
        } catch {
            throw AdminError.networkError(error)
        }
    }
    
    /// Warn a user
    /// - Parameters:
    ///   - userId: The user ID to warn
    ///   - warningType: Type of warning ("spam", "harassment", "inappropriate_content", "terms_violation", "other")
    ///   - reason: Reason for the warning
    ///   - notes: Optional additional notes
    /// - Throws: AdminError if the request fails
    public func warnUser(userId: String, warningType: String, reason: String, notes: String? = nil) async throws {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/users/\(userId)/warn")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "warningType": warningType,
            "reason": reason
        ]
        if let notes = notes {
            body["notes"] = notes
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        try await executeRequest(request: request)
    }
    
    /// Temporarily ban a user
    /// - Parameters:
    ///   - userId: The user ID to ban
    ///   - duration: Duration in hours
    ///   - reason: Reason for the ban
    ///   - notes: Optional additional notes
    /// - Throws: AdminError if the request fails
    public func tempBanUser(userId: String, duration: Int, reason: String, notes: String? = nil) async throws {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/users/\(userId)/temp-ban")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "duration": duration,
            "reason": reason
        ]
        if let notes = notes {
            body["notes"] = notes
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        try await executeRequest(request: request)
    }
    
    /// Update user role
    /// - Parameters:
    ///   - userId: The user ID
    ///   - role: New role ("admin", "moderator", "user")
    /// - Throws: AdminError if the request fails
    public func updateUserRole(userId: String, role: String) async throws {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/users/\(userId)/role")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = ["role": role]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        try await executeRequest(request: request)
    }
    
    /// Delete a user
    /// - Parameter userId: The user ID to delete
    /// - Throws: AdminError if the request fails
    public func deleteUser(userId: String) async throws {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/users/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        try await executeRequest(request: request)
    }
    
    // MARK: - Analytics
    
    /// Get analytics data
    /// - Parameter period: Time period ("7d", "30d", "90d", "all")
    /// - Returns: AnalyticsResponse with analytics data
    /// - Throws: AdminError if the request fails
    public func getAnalytics(period: String = "30d") async throws -> AnalyticsResponse {
        // Check cache first
        if config.cacheEnabled {
            let cacheKey = AdminCache.analyticsKey(period: period)
            if let cached = cache.get(cacheKey, as: AnalyticsResponse.self) {
                return cached
            }
        }
        
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        var components = URLComponents(string: "\(config.baseURL)/api/admin/analytics")!
        components.queryItems = [
            URLQueryItem(name: "period", value: period)
        ]
        
        guard let url = components.url else {
            throw AdminError.invalidConfiguration
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AdminError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let result = try decoder.decode(AnalyticsResponse.self, from: data)
                
                // Cache the result
                if config.cacheEnabled {
                    let cacheKey = AdminCache.analyticsKey(period: period)
                    cache.set(cacheKey, value: result, ttl: AdminCache.CacheTTL.analytics)
                }
                
                return result
            } else if httpResponse.statusCode == 401 {
                throw AdminError.unauthorized
            } else if httpResponse.statusCode == 403 {
                throw AdminError.forbidden
            } else {
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                throw AdminError.serverError(errorMessage?["message"] ?? "Server error")
            }
        } catch let error as AdminError {
            throw error
        } catch {
            throw AdminError.networkError(error)
        }
    }
    
    // MARK: - Moderation
    
    /// Get moderation queue
    /// - Parameter status: Filter by status ("pending", "flagged", or nil for all)
    /// - Returns: ModerationQueueResponse with posts
    /// - Throws: AdminError if the request fails
    public func getModerationQueue(status: String? = nil) async throws -> ModerationQueueResponse {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        var components = URLComponents(string: "\(config.baseURL)/api/admin/moderation/queue")!
        if let status = status {
            components.queryItems = [URLQueryItem(name: "status", value: status)]
        }
        
        guard let url = components.url else {
            throw AdminError.invalidConfiguration
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AdminError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                return try decoder.decode(ModerationQueueResponse.self, from: data)
            } else if httpResponse.statusCode == 401 {
                throw AdminError.unauthorized
            } else if httpResponse.statusCode == 403 {
                throw AdminError.forbidden
            } else {
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                throw AdminError.serverError(errorMessage?["message"] ?? "Server error")
            }
        } catch let error as AdminError {
            throw error
        } catch {
            throw AdminError.networkError(error)
        }
    }
    
    /// Approve a post
    /// - Parameter postId: The post ID to approve
    /// - Throws: AdminError if the request fails
    public func approvePost(postId: String) async throws {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/moderation/approve")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = ["postId": postId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        try await executeRequest(request: request)
    }
    
    /// Reject a post
    /// - Parameter postId: The post ID to reject
    /// - Throws: AdminError if the request fails
    public func rejectPost(postId: String) async throws {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/moderation/reject")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = ["postId": postId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        try await executeRequest(request: request)
    }
    
    /// Flag a post
    /// - Parameter postId: The post ID to flag
    /// - Throws: AdminError if the request fails
    public func flagPost(postId: String) async throws {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/moderation/flag")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = ["postId": postId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        try await executeRequest(request: request)
    }
    
    // MARK: - Post Management
    
    /// Get posts with filters
    /// - Parameters:
    ///   - limit: Maximum number of posts to return (default: 50)
    ///   - offset: Number of posts to skip (default: 0)
    ///   - filters: Optional PostFilters for filtering posts
    /// - Returns: PostsResponse with posts
    /// - Throws: AdminError if the request fails
    public func getPosts(limit: Int = 50, offset: Int = 0, filters: PostFilters? = nil) async throws -> PostsResponse {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        var components = URLComponents(string: "\(config.baseURL)/api/admin/posts")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        
        if let filters = filters {
            if let status = filters.status {
                queryItems.append(URLQueryItem(name: "status", value: status))
            }
            if let userId = filters.userId {
                queryItems.append(URLQueryItem(name: "userId", value: userId))
            }
            if let startDate = filters.startDate {
                queryItems.append(URLQueryItem(name: "startDate", value: String(startDate)))
            }
            if let endDate = filters.endDate {
                queryItems.append(URLQueryItem(name: "endDate", value: String(endDate)))
            }
            if let search = filters.search {
                queryItems.append(URLQueryItem(name: "search", value: search))
            }
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw AdminError.invalidConfiguration
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AdminError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                return try decoder.decode(PostsResponse.self, from: data)
            } else if httpResponse.statusCode == 401 {
                throw AdminError.unauthorized
            } else if httpResponse.statusCode == 403 {
                throw AdminError.forbidden
            } else {
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                throw AdminError.serverError(errorMessage?["message"] ?? "Server error")
            }
        } catch let error as AdminError {
            throw error
        } catch {
            throw AdminError.networkError(error)
        }
    }
    
    /// Get post details
    /// - Parameter postId: The post ID
    /// - Returns: PostDetails with full post information
    /// - Throws: AdminError if the request fails
    public func getPostDetails(postId: String) async throws -> PostDetails {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/posts/\(postId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AdminError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                // Backend returns { post: {...} }
                let wrapper = try decoder.decode(PostDetailsResponse.self, from: data)
                return wrapper.post
            } else if httpResponse.statusCode == 401 {
                throw AdminError.unauthorized
            } else if httpResponse.statusCode == 403 {
                throw AdminError.forbidden
            } else if httpResponse.statusCode == 404 {
                throw AdminError.notFound
            } else {
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                throw AdminError.serverError(errorMessage?["message"] ?? "Server error")
            }
        } catch let error as AdminError {
            throw error
        } catch {
            throw AdminError.networkError(error)
        }
    }
    
    /// Update a post
    /// - Parameters:
    ///   - postId: The post ID
    ///   - updates: PostUpdate with fields to update
    /// - Throws: AdminError if the request fails
    public func updatePost(postId: String, updates: PostUpdate) async throws {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/posts/\(postId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [:]
        if let caption = updates.caption {
            body["caption"] = caption
        }
        if let tags = updates.tags {
            body["tags"] = tags
        }
        if let moderationStatus = updates.moderationStatus {
            body["moderationStatus"] = moderationStatus
        }
        if let moderationReason = updates.moderationReason {
            body["moderationReason"] = moderationReason
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        try await executeRequest(request: request)
    }
    
    /// Delete a post
    /// - Parameter postId: The post ID to delete
    /// - Throws: AdminError if the request fails
    public func deletePost(postId: String) async throws {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/posts/\(postId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        try await executeRequest(request: request)
    }
    
    /// Perform bulk action on posts
    /// - Parameters:
    ///   - postIds: Array of post IDs
    ///   - action: BulkPostAction to perform
    ///   - moderationReason: Optional reason for moderation actions
    /// - Throws: AdminError if the request fails
    public func bulkPostAction(postIds: [String], action: BulkPostAction, moderationReason: String? = nil) async throws {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/posts/bulk")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "postIds": postIds,
            "action": action.rawValue
        ]
        
        if let moderationReason = moderationReason {
            body["moderationReason"] = moderationReason
        }
        
        // Map SDK action to backend expected values
        if action == .approve {
            body["moderationStatus"] = "approved"
        } else if action == .reject {
            body["moderationStatus"] = "rejected"
        } else if action == .flag {
            body["moderationStatus"] = "flagged"
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        try await executeRequest(request: request)
    }
    
    // MARK: - Post Reporting
    
    /// Report a post (public endpoint - uses Firebase token, not admin token)
    /// - Parameters:
    ///   - postId: The post ID to report
    ///   - reason: Reason for reporting (e.g., "spam", "inappropriate", "harassment", "other")
    ///   - description: Optional additional description
    ///   - firebaseToken: Firebase ID token from Firebase Auth
    /// - Throws: AdminError if the request fails
    public func reportPost(postId: String, reason: String, description: String? = nil, firebaseToken: String) async throws {
        let url = URL(string: "\(config.baseURL)/api/reports/posts/\(postId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(firebaseToken)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = ["reason": reason]
        if let description = description {
            body["description"] = description
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        try await executeRequest(request: request)
    }
    
    /// Get all reports made by the current user
    /// - Parameter firebaseToken: Firebase ID token from Firebase Auth
    /// - Returns: UserReportsResponse containing list of reports
    /// - Throws: AdminError if the request fails
    public func getMyReports(firebaseToken: String) async throws -> UserReportsResponse {
        let url = URL(string: "\(config.baseURL)/api/reports/my-reports")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(firebaseToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AdminError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                return try decoder.decode(UserReportsResponse.self, from: data)
            } else if httpResponse.statusCode == 401 {
                throw AdminError.unauthorized
            } else if httpResponse.statusCode == 403 {
                throw AdminError.forbidden
            } else {
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                throw AdminError.serverError(errorMessage?["message"] ?? "Server error")
            }
        } catch let error as AdminError {
            throw error
        } catch {
            throw AdminError.networkError(error)
        }
    }
    
    // MARK: - Settings
    
    /// Get system settings
    /// - Returns: SystemSettingsResponse with current settings
    /// - Throws: AdminError if the request fails
    public func getSystemSettings() async throws -> SystemSettingsResponse {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/settings")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AdminError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                return try decoder.decode(SystemSettingsResponse.self, from: data)
            } else if httpResponse.statusCode == 401 {
                throw AdminError.unauthorized
            } else if httpResponse.statusCode == 403 {
                throw AdminError.forbidden
            } else {
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                throw AdminError.serverError(errorMessage?["message"] ?? "Server error")
            }
        } catch let error as AdminError {
            throw error
        } catch {
            throw AdminError.networkError(error)
        }
    }
    
    /// Update system settings
    /// - Parameter settings: SystemSettingsUpdate with settings to update
    /// - Throws: AdminError if the request fails
    public func updateSystemSettings(settings: SystemSettingsUpdate) async throws {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/settings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [:]
        if let featureFlags = settings.featureFlags {
            body["featureFlags"] = featureFlags
        }
        if let remoteConfig = settings.remoteConfig {
            body["remoteConfig"] = remoteConfig
        }
        if let maintenanceMode = settings.maintenanceMode {
            body["maintenanceMode"] = maintenanceMode
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        try await executeRequest(request: request)
    }
    
    // MARK: - Notifications
    
    /// Create a notification
    /// - Parameter notification: NotificationCreate with notification details
    /// - Returns: NotificationResponse with created notification
    /// - Throws: AdminError if the request fails
    public func createNotification(notification: NotificationCreate) async throws -> NotificationResponse {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/notifications")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "title": notification.title,
            "body": notification.body,
            "type": notification.type
        ]
        
        if let audience = notification.audience {
            body["audience"] = audience
        }
        if let audienceIds = notification.audienceIds {
            body["audienceIds"] = audienceIds
        }
        if let scheduledFor = notification.scheduledFor {
            body["scheduledFor"] = scheduledFor
        }
        if let data = notification.data {
            body["data"] = data
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AdminError.unknown
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                let decoder = JSONDecoder()
                // Backend returns { success: true, notification: {...} }
                if let wrapper = try? decoder.decode(NotificationResponseWrapper.self, from: data) {
                    return wrapper.notification
                } else {
                    // Fallback to direct decode
                    return try decoder.decode(NotificationResponse.self, from: data)
                }
            } else if httpResponse.statusCode == 401 {
                throw AdminError.unauthorized
            } else if httpResponse.statusCode == 403 {
                throw AdminError.forbidden
            } else {
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                throw AdminError.serverError(errorMessage?["message"] ?? "Server error")
            }
        } catch let error as AdminError {
            throw error
        } catch {
            throw AdminError.networkError(error)
        }
    }
    
    /// Get notifications
    /// - Parameter status: Optional status filter ("draft", "scheduled", "sending", "sent", "failed", or nil for all)
    /// - Returns: NotificationsResponse with list of notifications
    /// - Throws: AdminError if the request fails
    public func getNotifications(status: String? = nil) async throws -> NotificationsResponse {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        var components = URLComponents(string: "\(config.baseURL)/api/admin/notifications")!
        if let status = status {
            components.queryItems = [URLQueryItem(name: "status", value: status)]
        }
        
        guard let url = components.url else {
            throw AdminError.invalidConfiguration
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AdminError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                // Backend returns { success: true, notifications: [...] }
                return try decoder.decode(NotificationsResponse.self, from: data)
            } else if httpResponse.statusCode == 401 {
                throw AdminError.unauthorized
            } else if httpResponse.statusCode == 403 {
                throw AdminError.forbidden
            } else {
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                throw AdminError.serverError(errorMessage?["message"] ?? "Server error")
            }
        } catch let error as AdminError {
            throw error
        } catch {
            throw AdminError.networkError(error)
        }
    }
    
    /// Get notification details
    /// - Parameter notificationId: The notification ID
    /// - Returns: NotificationResponse with notification details
    /// - Throws: AdminError if the request fails
    public func getNotificationDetails(notificationId: String) async throws -> NotificationResponse {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/notifications/\(notificationId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AdminError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                // Backend returns { success: true, notification: {...} }
                if let wrapper = try? decoder.decode(NotificationResponseWrapper.self, from: data) {
                    return wrapper.notification
                } else {
                    // Fallback to direct decode
                    return try decoder.decode(NotificationResponse.self, from: data)
                }
            } else if httpResponse.statusCode == 401 {
                throw AdminError.unauthorized
            } else if httpResponse.statusCode == 403 {
                throw AdminError.forbidden
            } else if httpResponse.statusCode == 404 {
                throw AdminError.notFound
            } else {
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                throw AdminError.serverError(errorMessage?["message"] ?? "Server error")
            }
        } catch let error as AdminError {
            throw error
        } catch {
            throw AdminError.networkError(error)
        }
    }
    
    /// Send a notification
    /// - Parameter notificationId: The notification ID to send
    /// - Throws: AdminError if the request fails
    public func sendNotification(notificationId: String) async throws {
        guard let token = config.token else {
            throw AdminError.unauthorized
        }
        
        let url = URL(string: "\(config.baseURL)/api/admin/notifications/\(notificationId)/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        try await executeRequest(request: request)
    }
    
    // MARK: - Helper Methods
    
    /// Execute a request with retry logic and automatic token refresh
    /// - Parameter request: The URLRequest to execute
    /// - Throws: AdminError if the request fails after all retries
    private func executeRequestWithRetry(request: URLRequest) async throws {
        // Check if token is expired and refresh if needed
        if config.isTokenExpired, let _ = config.token {
            try await refreshToken()
        }
        
        var lastError: Error?
        var hasRefreshed = false
        
        for attempt in 0...maxRetries {
            do {
                // Update request with current token if it exists
                var mutableRequest = request
                if let token = config.token {
                    mutableRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                
                let (data, response) = try await session.data(for: mutableRequest)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AdminError.unknown
                }
                
                // Handle success
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    return
                }
                
                // Handle 401 - try to refresh token once
                if httpResponse.statusCode == 401 && !hasRefreshed, let _ = config.token {
                    hasRefreshed = true
                    try await refreshToken()
                    // Retry immediately with new token
                    continue
                } else if httpResponse.statusCode == 401 {
                    throw AdminError.unauthorized
                }
                
                // Handle errors that shouldn't be retried
                if httpResponse.statusCode == 400 {
                    let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                    throw AdminError.badRequest(message: errorMessage?["message"] ?? "Bad request")
                } else if httpResponse.statusCode == 403 {
                    throw AdminError.forbidden
                } else if httpResponse.statusCode == 404 {
                    throw AdminError.notFound
                } else if httpResponse.statusCode == 409 {
                    let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                    throw AdminError.conflict(message: errorMessage?["message"] ?? "Conflict")
                } else if httpResponse.statusCode == 408 || httpResponse.statusCode == 504 {
                    // Timeout - retry
                    lastError = AdminError.timeout
                } else if httpResponse.statusCode == 429 {
                    // Rate limited - check for Retry-After header
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
                    throw AdminError.rateLimited(retryAfter: retryAfter)
                } else if httpResponse.statusCode >= 500 {
                    // Server error - retry
                    let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                    lastError = AdminError.serverError(errorMessage?["message"] ?? "Server error")
                } else {
                    let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                    throw AdminError.serverError(errorMessage?["message"] ?? "Server error")
                }
            } catch let error as AdminError {
                // Don't retry on client errors (4xx except 408, 429, 401 with refresh)
                if error.statusCode != nil && (error.statusCode! < 500 && error.statusCode! != 408 && error.statusCode! != 401) {
                    throw error
                }
                lastError = error
            } catch {
                // Network errors - retry
                lastError = AdminError.networkError(error)
            }
            
            // If this was the last attempt, throw the error
            if attempt >= maxRetries {
                if let lastError = lastError {
                    throw lastError
                }
                throw AdminError.unknown
            }
            
            // Wait before retrying with exponential backoff
            let delay = retryDelay * pow(2.0, Double(attempt))
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
    
    /// Execute a request and handle common errors
    private func executeRequest(request: URLRequest) async throws {
        try await executeRequestWithRetry(request: request)
    }
}

