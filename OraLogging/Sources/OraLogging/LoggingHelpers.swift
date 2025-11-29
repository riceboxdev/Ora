//
//  LoggingHelpers.swift
//  OraLogging
//
//  Convenience helpers for logging control
//

import Foundation

/// Convenience functions for controlling logging services
public enum LoggingControl {
    /// Enable logging for a service
    public static func enable(_ serviceName: String) {
        LoggingServiceRegistry.shared.enable(serviceName: serviceName)
    }
    
    /// Disable logging for a service
    public static func disable(_ serviceName: String) {
        LoggingServiceRegistry.shared.disable(serviceName: serviceName)
    }
    
    /// Toggle logging for a service
    @discardableResult
    public static func toggle(_ serviceName: String) -> Bool {
        return LoggingServiceRegistry.shared.toggle(serviceName: serviceName)
    }
    
    /// Check if a service is enabled
    public static func isEnabled(_ serviceName: String) -> Bool {
        return LoggingServiceRegistry.shared.isEnabled(serviceName: serviceName)
    }
    
    /// Get all registered services
    public static func allServices() -> [String] {
        return LoggingServiceRegistry.shared.getAllServices()
    }
    
    /// Enable all services
    public static func enableAll() {
        LoggingServiceRegistry.shared.enableAll()
    }
    
    /// Disable all services
    public static func disableAll() {
        LoggingServiceRegistry.shared.disableAll()
    }
    
    /// Reset all services to defaults from configuration
    public static func resetToDefaults() {
        LoggingServiceRegistry.shared.resetToDefaults()
    }
    
    /// Print current logging state (useful for debugging)
    public static func printState() {
        let services = LoggingServiceRegistry.shared.getAllServicesWithState()
        print("📊 Logging Service States:")
        print("   App-wide log level: \(LoggingConfig.defaultLogLevel.rawValue)")
        print("   Services:")
        for (service, enabled) in services.sorted(by: { $0.key < $1.key }) {
            let level = LoggingConfig.logLevel(for: service)
            let status = enabled ? "✅" : "❌"
            print("   \(status) \(service): \(enabled ? "enabled" : "disabled") (level: \(level.rawValue))")
        }
    }
}






