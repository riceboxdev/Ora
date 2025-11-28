//
//  LoggingConfiguration.swift
//  OraLogging
//
//  Configuration struct to replace app-specific Config dependency
//

import Foundation

/// Configuration for the logging system
/// This replaces the dependency on app-specific Config struct
public struct LoggingConfiguration {
    /// App-wide default log level
    public let defaultLogLevel: LogLevel?
    
    /// Per-service log level overrides
    /// Example: ["StreamService": .full, "ImageUploadService": .minimal]
    public let serviceLogLevels: [String: LogLevel]
    
    /// Per-service logging enabled/disabled states
    /// Example: ["StreamService": true, "ImageSegmentationService": false]
    /// Services not in this dictionary default to enabled
    public let serviceLoggingStates: [String: Bool]
    
    /// Create a logging configuration
    /// - Parameters:
    ///   - defaultLogLevel: App-wide default log level. If nil, uses defaults (full in debug, minimal in release)
    ///   - serviceLogLevels: Per-service log level overrides
    ///   - serviceLoggingStates: Per-service enabled/disabled states
    public init(
        defaultLogLevel: LogLevel? = nil,
        serviceLogLevels: [String: LogLevel] = [:],
        serviceLoggingStates: [String: Bool] = [:]
    ) {
        self.defaultLogLevel = defaultLogLevel
        self.serviceLogLevels = serviceLogLevels
        self.serviceLoggingStates = serviceLoggingStates
    }
    
    /// Default configuration (full logging in debug, minimal in release)
    public static var `default`: LoggingConfiguration {
        #if DEBUG
        return LoggingConfiguration(defaultLogLevel: .full)
        #else
        return LoggingConfiguration(defaultLogLevel: .minimal)
        #endif
    }
}



