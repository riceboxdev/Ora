//
//  LoggerTests.swift
//  OraLoggingTests
//
//  Basic tests for the logging system
//

import XCTest
@testable import OraLogging

final class LoggerTests: XCTestCase {
    
    func testLogLevelShouldLog() {
        XCTAssertFalse(LogLevel.none.shouldLog(requiredLevel: .full))
        XCTAssertFalse(LogLevel.none.shouldLog(requiredLevel: .minimal))
        XCTAssertFalse(LogLevel.none.shouldLog(requiredLevel: .none))
        
        XCTAssertTrue(LogLevel.minimal.shouldLog(requiredLevel: .minimal))
        XCTAssertTrue(LogLevel.minimal.shouldLog(requiredLevel: .none))
        XCTAssertFalse(LogLevel.minimal.shouldLog(requiredLevel: .full))
        
        XCTAssertTrue(LogLevel.full.shouldLog(requiredLevel: .full))
        XCTAssertTrue(LogLevel.full.shouldLog(requiredLevel: .minimal))
        XCTAssertTrue(LogLevel.full.shouldLog(requiredLevel: .none))
    }
    
    func testLoggingConfiguration() {
        let config = LoggingConfiguration(
            defaultLogLevel: .full,
            serviceLogLevels: ["TestService": .minimal],
            serviceLoggingStates: ["TestService": true]
        )
        
        XCTAssertEqual(config.defaultLogLevel, .full)
        XCTAssertEqual(config.serviceLogLevels["TestService"], .minimal)
        XCTAssertEqual(config.serviceLoggingStates["TestService"], true)
    }
    
    func testLoggingServiceRegistry() {
        let registry = LoggingServiceRegistry.shared
        
        // Register a test service
        let enabled = registry.register(serviceName: "TestService")
        XCTAssertTrue(enabled) // Default is enabled
        
        // Disable it
        registry.disable(serviceName: "TestService")
        XCTAssertFalse(registry.isEnabled(serviceName: "TestService"))
        
        // Enable it
        registry.enable(serviceName: "TestService")
        XCTAssertTrue(registry.isEnabled(serviceName: "TestService"))
        
        // Toggle it
        let newState = registry.toggle(serviceName: "TestService")
        XCTAssertFalse(newState)
        XCTAssertFalse(registry.isEnabled(serviceName: "TestService"))
    }
    
    func testLoggingConfig() {
        // Configure with test settings
        let config = LoggingConfiguration(
            defaultLogLevel: .full,
            serviceLogLevels: ["TestService": .minimal],
            serviceLoggingStates: [:]
        )
        LoggingConfig.configure(config)
        
        XCTAssertEqual(LoggingConfig.defaultLogLevel, .full)
        XCTAssertEqual(LoggingConfig.logLevel(for: "TestService"), .minimal)
        XCTAssertEqual(LoggingConfig.logLevel(for: "UnknownService"), .full)
    }
}



