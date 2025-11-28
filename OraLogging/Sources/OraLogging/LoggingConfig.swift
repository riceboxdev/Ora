//
//  LoggingConfig.swift
//  OraLogging
//
//  Centralized logging configuration
//

import Foundation

/// Centralized logging configuration
public struct LoggingConfig {
    /// Shared configuration instance
    private static var _sharedConfiguration: LoggingConfiguration = .default
    
    /// Internal access to shared configuration
    static var sharedConfiguration: LoggingConfiguration {
        get { _sharedConfiguration }
        set { _sharedConfiguration = newValue }
    }
    
    /// Configure the logging system
    /// - Parameter configuration: The logging configuration to use
    public static func configure(_ configuration: LoggingConfiguration) {
        sharedConfiguration = configuration
    }
    
    /// App-wide default log level
    public static var defaultLogLevel: LogLevel {
        #if DEBUG
        // In debug builds, check configuration first, then default to full
        if let configLevel = sharedConfiguration.defaultLogLevel {
            return configLevel
        }
        return .full
        #else
        // In release builds, check configuration first, then default to minimal
        if let configLevel = sharedConfiguration.defaultLogLevel {
            return configLevel
        }
        return .minimal
        #endif
    }
    
    /// Get log level for a specific service
    /// Falls back to default log level if service-specific level not set
    public static func logLevel(for service: String) -> LogLevel {
        // Check for service-specific override in configuration
        if let serviceLevel = sharedConfiguration.serviceLogLevels[service] {
            return serviceLevel
        }
        return defaultLogLevel
    }
    
    /// Check if a message should be logged for a given service and required level
    public static func shouldLog(service: String, level: LogLevel) -> Bool {
        // First check if the service is enabled in the registry
        if !LoggingServiceRegistry.shared.isEnabled(serviceName: service) {
            return false
        }
        
        // Then check the log level
        let serviceLogLevel = logLevel(for: service)
        return serviceLogLevel.shouldLog(requiredLevel: level)
    }
    
    /// Get service logging state from configuration (internal helper)
    static func getServiceLoggingState(_ serviceName: String) -> Bool? {
        return sharedConfiguration.serviceLoggingStates[serviceName]
    }
}

