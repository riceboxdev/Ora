//
//  LoggingConfig.swift
//  OraBeta
//
//  Centralized logging configuration
//

import Foundation

/// Log level enumeration
enum LogLevel: String, CaseIterable {
    case none = "none"
    case minimal = "minimal"
    case full = "full"
    
    /// Returns true if this log level should log messages of the given required level
    /// The required level indicates the minimum verbosity needed to log the message
    func shouldLog(requiredLevel: LogLevel) -> Bool {
        switch self {
        case .none:
            return false
        case .minimal:
            // Minimal mode only logs messages that require minimal or less (i.e., errors and warnings)
            return requiredLevel == .minimal || requiredLevel == .none
        case .full:
            // Full mode logs everything (all required levels)
            return true
        }
    }
}

/// Centralized logging configuration
struct LoggingConfig {
    /// App-wide default log level
    static var defaultLogLevel: LogLevel {
        #if DEBUG
        // In debug builds, check Config first, then default to full
        if let configLevel = Config.logLevel {
            return configLevel
        }
        return .full
        #else
        // In release builds, check Config first, then default to minimal
        if let configLevel = Config.logLevel {
            return configLevel
        }
        return .minimal
        #endif
    }
    
    /// Get log level for a specific service
    /// Falls back to default log level if service-specific level not set
    static func logLevel(for service: String) -> LogLevel {
        // Check for service-specific override in Config
        if let serviceLevel = Config.serviceLogLevels[service] {
            return serviceLevel
        }
        return defaultLogLevel
    }
    
    /// Check if a message should be logged for a given service and required level
    static func shouldLog(service: String, level: LogLevel) -> Bool {
        // First check if the service is enabled in the registry
        if !LoggingServiceRegistry.shared.isEnabled(serviceName: service) {
            return false
        }
        
        // Then check the log level
        let serviceLogLevel = logLevel(for: service)
        return serviceLogLevel.shouldLog(requiredLevel: level)
    }
}

