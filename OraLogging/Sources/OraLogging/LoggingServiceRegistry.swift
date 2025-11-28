//
//  LoggingServiceRegistry.swift
//  OraLogging
//
//  Service registry for centralized logging control
//

import Foundation

/// Registry for managing logging services
public class LoggingServiceRegistry {
    public static let shared = LoggingServiceRegistry()
    
    /// Registered services with their enabled state
    private var registeredServices: [String: Bool] = [:]
    
    /// Lock for thread-safe access
    private let lock = NSLock()
    
    private init() {
        // Load saved service states from UserDefaults
        loadServiceStates()
    }
    
    /// Register a service with the logger
    /// - Parameter serviceName: The name of the service (e.g., "StreamService", "ImageSegmentationService")
    /// - Returns: True if the service is enabled, false otherwise
    @discardableResult
    public func register(serviceName: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // If service is already registered, return its current state
        if let enabled = registeredServices[serviceName] {
            return enabled
        }
        
        // Check if there's a saved state for this service
        let savedState = UserDefaults.standard.bool(forKey: "LoggingService_\(serviceName)_enabled")
        
        // If no saved state, check configuration for default state
        let defaultEnabled: Bool
        if let configState = LoggingConfig.getServiceLoggingState(serviceName) {
            defaultEnabled = configState
        } else {
            // Default to enabled for all services
            defaultEnabled = true
        }
        
        let enabled = savedState || (savedState == false ? false : defaultEnabled)
        registeredServices[serviceName] = enabled
        
        // Save to UserDefaults
        UserDefaults.standard.set(enabled, forKey: "LoggingService_\(serviceName)_enabled")
        
        return enabled
    }
    
    /// Enable logging for a specific service
    public func enable(serviceName: String) {
        lock.lock()
        defer { lock.unlock() }
        
        registeredServices[serviceName] = true
        UserDefaults.standard.set(true, forKey: "LoggingService_\(serviceName)_enabled")
    }
    
    /// Disable logging for a specific service
    public func disable(serviceName: String) {
        lock.lock()
        defer { lock.unlock() }
        
        registeredServices[serviceName] = false
        UserDefaults.standard.set(false, forKey: "LoggingService_\(serviceName)_enabled")
    }
    
    /// Toggle logging for a specific service
    @discardableResult
    public func toggle(serviceName: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let currentState = registeredServices[serviceName] ?? true
        let newState = !currentState
        registeredServices[serviceName] = newState
        UserDefaults.standard.set(newState, forKey: "LoggingService_\(serviceName)_enabled")
        return newState
    }
    
    /// Check if a service is enabled
    public func isEnabled(serviceName: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // If service is registered, return its state
        if let enabled = registeredServices[serviceName] {
            return enabled
        }
        
        // If not registered, check UserDefaults
        if UserDefaults.standard.object(forKey: "LoggingService_\(serviceName)_enabled") != nil {
            return UserDefaults.standard.bool(forKey: "LoggingService_\(serviceName)_enabled")
        }
        
        // Check configuration for default
        if let configState = LoggingConfig.getServiceLoggingState(serviceName) {
            return configState
        }
        
        // Default to enabled
        return true
    }
    
    /// Get all registered services
    public func getAllServices() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        
        return Array(registeredServices.keys).sorted()
    }
    
    /// Get all services with their enabled state
    public func getAllServicesWithState() -> [String: Bool] {
        lock.lock()
        defer { lock.unlock() }
        
        return registeredServices
    }
    
    /// Enable all services
    public func enableAll() {
        lock.lock()
        defer { lock.unlock() }
        
        for serviceName in registeredServices.keys {
            registeredServices[serviceName] = true
            UserDefaults.standard.set(true, forKey: "LoggingService_\(serviceName)_enabled")
        }
    }
    
    /// Disable all services
    public func disableAll() {
        lock.lock()
        defer { lock.unlock() }
        
        for serviceName in registeredServices.keys {
            registeredServices[serviceName] = false
            UserDefaults.standard.set(false, forKey: "LoggingService_\(serviceName)_enabled")
        }
    }
    
    /// Reset all service states to defaults from configuration
    public func resetToDefaults() {
        lock.lock()
        defer { lock.unlock() }
        
        for serviceName in registeredServices.keys {
            let defaultState = LoggingConfig.getServiceLoggingState(serviceName) ?? true
            registeredServices[serviceName] = defaultState
            UserDefaults.standard.set(defaultState, forKey: "LoggingService_\(serviceName)_enabled")
        }
    }
    
    /// Load service states from UserDefaults
    private func loadServiceStates() {
        // This will be called when services register themselves
        // We don't preload all possible services, only those that register
    }
}

