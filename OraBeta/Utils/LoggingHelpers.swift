//
//  LoggingHelpers.swift
//  OraBeta
//
//  Convenience helpers for logging control
//

import Foundation

/// Convenience functions for controlling logging services
enum LoggingControl {
    /// Enable logging for a service
    static func enable(_ serviceName: String) {
        LoggingServiceRegistry.shared.enable(serviceName: serviceName)
    }
    
    /// Disable logging for a service
    static func disable(_ serviceName: String) {
        LoggingServiceRegistry.shared.disable(serviceName: serviceName)
    }
    
    /// Toggle logging for a service
    @discardableResult
    static func toggle(_ serviceName: String) -> Bool {
        return LoggingServiceRegistry.shared.toggle(serviceName: serviceName)
    }
    
    /// Check if a service is enabled
    static func isEnabled(_ serviceName: String) -> Bool {
        return LoggingServiceRegistry.shared.isEnabled(serviceName: serviceName)
    }
    
    /// Get all registered services
    static func allServices() -> [String] {
        return LoggingServiceRegistry.shared.getAllServices()
    }
    
    /// Enable all services
    static func enableAll() {
        LoggingServiceRegistry.shared.enableAll()
    }
    
    /// Disable all services
    static func disableAll() {
        LoggingServiceRegistry.shared.disableAll()
    }
    
    /// Reset all services to defaults from Config
    static func resetToDefaults() {
        LoggingServiceRegistry.shared.resetToDefaults()
    }
    
    /// Print current logging state (useful for debugging)
    static func printState() {
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






