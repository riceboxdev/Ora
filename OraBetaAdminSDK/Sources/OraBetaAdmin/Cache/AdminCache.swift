import Foundation

/// Cache entry with TTL
private struct CacheEntry<T: Codable> {
    let data: T
    let expiryDate: Date
    
    var isExpired: Bool {
        return Date() >= expiryDate
    }
}

/// In-memory cache for admin API responses
@available(iOS 15.0, macOS 12.0, *)
public final class AdminCache {
    private var cache: [String: Any] = [:]
    private let cacheQueue = DispatchQueue(label: "com.orabeta.admin.cache", attributes: .concurrent)
    
    /// Cache TTL configurations
    public struct CacheTTL {
        public static let analytics: TimeInterval = 5 * 60 // 5 minutes
        public static let users: TimeInterval = 2 * 60 // 2 minutes
        public static let moderation: TimeInterval = 1 * 60 // 1 minute
        public static let posts: TimeInterval = 2 * 60 // 2 minutes
        public static let settings: TimeInterval = 10 * 60 // 10 minutes
    }
    
    /// Get cached data
    /// - Parameters:
    ///   - key: Cache key
    ///   - type: Type to decode
    /// - Returns: Cached data if available and not expired, nil otherwise
    public func get<T: Codable>(_ key: String, as type: T.Type) -> T? {
        return cacheQueue.sync {
            guard let entry = cache[key] as? CacheEntry<T> else {
                return nil
            }
            
            if entry.isExpired {
                cache.removeValue(forKey: key)
                return nil
            }
            
            return entry.data
        }
    }
    
    /// Set cached data
    /// - Parameters:
    ///   - key: Cache key
    ///   - value: Data to cache
    ///   - ttl: Time to live in seconds
    public func set<T: Codable>(_ key: String, value: T, ttl: TimeInterval) {
        cacheQueue.async(flags: .barrier) {
            let expiryDate = Date().addingTimeInterval(ttl)
            let entry = CacheEntry(data: value, expiryDate: expiryDate)
            self.cache[key] = entry
        }
    }
    
    /// Remove cached data
    /// - Parameter key: Cache key to remove
    public func remove(_ key: String) {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }
    
    /// Clear all cache
    public func clear() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
    
    /// Clear cache entries matching a prefix
    /// - Parameter prefix: Key prefix to match
    public func clear(prefix: String) {
        cacheQueue.async(flags: .barrier) {
            let keysToRemove = self.cache.keys.filter { $0.hasPrefix(prefix) }
            for key in keysToRemove {
                self.cache.removeValue(forKey: key)
            }
        }
    }
    
    /// Generate cache key for analytics
    public static func analyticsKey(period: String) -> String {
        return "analytics:\(period)"
    }
    
    /// Generate cache key for users list
    public static func usersKey(limit: Int, offset: Int, filters: String? = nil) -> String {
        let filterStr = filters ?? "none"
        return "users:\(limit):\(offset):\(filterStr)"
    }
    
    /// Generate cache key for moderation queue
    public static func moderationKey(status: String?) -> String {
        return "moderation:\(status ?? "all")"
    }
    
    /// Generate cache key for posts list
    public static func postsKey(limit: Int, offset: Int, filters: String? = nil) -> String {
        let filterStr = filters ?? "none"
        return "posts:\(limit):\(offset):\(filterStr)"
    }
    
    /// Generate cache key for settings
    public static func settingsKey() -> String {
        return "settings"
    }
}

