//
//  Logger.swift
//  OraBeta
//
//  Centralized logging utility with configurable log levels
//

import Foundation

/// Centralized logger with support for different log levels
struct Logger {
    /// Log levels for different types of messages
    enum MessageLevel {
        case info      // General information (only in full mode)
        case debug     // Debug information (only in full mode)
        case warning   // Warnings (logged in minimal and full mode)
        case error     // Errors (always logged)
    }
    
    /// Log a message with a specific level
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level (info, debug, warning, error)
    ///   - service: The service name (e.g., "StreamService")
    ///   - file: The file name (automatically captured)
    ///   - function: The function name (automatically captured)
    ///   - line: The line number (automatically captured)
    static func log(
        _ message: String,
        level: MessageLevel = .info,
        service: String = "App",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Register the service if not already registered
        _ = LoggingServiceRegistry.shared.register(serviceName: service)
        
        // Map MessageLevel to LogLevel for checking
        let logLevel: LogLevel = {
            switch level {
            case .info, .debug:
                return .full
            case .warning:
                return .minimal
            case .error:
                return .minimal // Errors are always logged
            }
        }()
        
        // Check if we should log this message
        let shouldLog = LoggingConfig.shouldLog(service: service, level: logLevel)
        if !shouldLog {
            // Debug: Log why we're not logging (only in debug builds to avoid infinite loops)
            #if DEBUG
            let isEnabled = LoggingServiceRegistry.shared.isEnabled(serviceName: service)
            let serviceLogLevel = LoggingConfig.logLevel(for: service)
            print("🔇 [DEBUG] Logging suppressed for \(service): enabled=\(isEnabled), logLevel=\(serviceLogLevel.rawValue), requiredLevel=\(logLevel.rawValue)")
            #endif
            return
        }
        
        // Format the log message
        let fileName = (file as NSString).lastPathComponent
        let prefix: String
        
        switch level {
        case .error:
            prefix = "❌"
        case .warning:
            prefix = "⚠️"
        case .info:
            prefix = "ℹ️"
        case .debug:
            prefix = "🔍"
        }
        
        let formattedMessage = "\(prefix) \(service): \(message)"
        print(formattedMessage)
    }
    
    /// Log an info message (only in full mode)
    static func info(
        _ message: String,
        service: String = "App",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, service: service, file: file, function: function, line: line)
    }
    
    /// Log a debug message (only in full mode)
    static func debug(
        _ message: String,
        service: String = "App",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, service: service, file: file, function: function, line: line)
    }
    
    /// Log a warning message (logged in minimal and full mode)
    static func warning(
        _ message: String,
        service: String = "App",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, service: service, file: file, function: function, line: line)
    }
    
    /// Log an error message (always logged)
    static func error(
        _ message: String,
        service: String = "App",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, service: service, file: file, function: function, line: line)
    }
}





