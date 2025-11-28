//
//  LoggingServiceRegistry.swift
//  OraBeta
//
//  Service registry for centralized logging control
//

import Foundation

/// Registry for managing logging services
class LoggingServiceRegistry {
    static let shared = LoggingServiceRegistry()
    
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
    func register(serviceName: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // If service is already registered, return its current state
        if let enabled = registeredServices[serviceName] {
            return enabled
        }
        
        // Check if there's a saved state for this service
        let savedState = UserDefaults.standard.bool(forKey: "LoggingService_\(serviceName)_enabled")
        
        // If no saved state, check Config for default state
        let defaultEnabled: Bool
        if let configState = Config.serviceLoggingStates[serviceName] {
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
    func enable(serviceName: String) {
        lock.lock()
        defer { lock.unlock() }
        
        registeredServices[serviceName] = true
        UserDefaults.standard.set(true, forKey: "LoggingService_\(serviceName)_enabled")
    }
    
    /// Disable logging for a specific service
    func disable(serviceName: String) {
        lock.lock()
        defer { lock.unlock() }
        
        registeredServices[serviceName] = false
        UserDefaults.standard.set(false, forKey: "LoggingService_\(serviceName)_enabled")
    }
    
    /// Toggle logging for a specific service
    func toggle(serviceName: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let currentState = registeredServices[serviceName] ?? true
        let newState = !currentState
        registeredServices[serviceName] = newState
        UserDefaults.standard.set(newState, forKey: "LoggingService_\(serviceName)_enabled")
        return newState
    }
    
    /// Check if a service is enabled
    func isEnabled(serviceName: String) -> Bool {
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
        
        // Check Config for default
        if let configState = Config.serviceLoggingStates[serviceName] {
            return configState
        }
        
        // Default to enabled
        return true
    }
    
    /// Get all registered services
    func getAllServices() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        
        return Array(registeredServices.keys).sorted()
    }
    
    /// Get all services with their enabled state
    func getAllServicesWithState() -> [String: Bool] {
        lock.lock()
        defer { lock.unlock() }
        
        return registeredServices
    }
    
    /// Enable all services
    func enableAll() {
        lock.lock()
        defer { lock.unlock() }
        
        for serviceName in registeredServices.keys {
            registeredServices[serviceName] = true
            UserDefaults.standard.set(true, forKey: "LoggingService_\(serviceName)_enabled")
        }
    }
    
    /// Disable all services
    func disableAll() {
        lock.lock()
        defer { lock.unlock() }
        
        for serviceName in registeredServices.keys {
            registeredServices[serviceName] = false
            UserDefaults.standard.set(false, forKey: "LoggingService_\(serviceName)_enabled")
        }
    }
    
    /// Reset all service states to defaults from Config
    func resetToDefaults() {
        lock.lock()
        defer { lock.unlock() }
        
        for serviceName in registeredServices.keys {
            let defaultState = Config.serviceLoggingStates[serviceName] ?? true
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






