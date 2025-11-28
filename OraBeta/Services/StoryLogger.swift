//
//  StoryLogger.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/22/25.
//

import Foundation
import os.log

// MARK: - Story Logging Protocol
protocol StoryLoggingProtocol {
    func log(_ event: StoryAnalyticsEvent)
    func logError(_ error: StoryError, context: String)
    func logInfo(_ message: String, category: String)
    func logDebug(_ message: String, category: String)
}

// MARK: - Story Logger Implementation
class StoryLogger: StoryLoggingProtocol {
    private let configuration: StoryConfiguration
    private let osLog = OSLog(subsystem: "com.orabeta.stories", category: "StoryService")
    
    init(configuration: StoryConfiguration = .default) {
        self.configuration = configuration
    }
    
    func log(_ event: StoryAnalyticsEvent) {
        guard configuration.enableAnalytics else { return }
        
        os_log(.info, log: osLog, "Story Event: %{public}@ - %{public}@", event.name, event.parameters)
        
        // Here you would also send to your analytics service
        // Analytics.track(event.name, parameters: event.parameters)
    }
    
    func logError(_ error: StoryError, context: String) {
        os_log(.error, log: osLog, "Story Error in %{public}@: %{public}@", context, error.errorDescription ?? "Unknown error")
        
        if configuration.enableAnalytics {
            log(.storyError(error: error, context: context))
        }
    }
    
    func logInfo(_ message: String, category: String) {
        os_log(.info, log: osLog, "[%{public}@] %{public}@", category, message)
    }
    
    func logDebug(_ message: String, category: String) {
        #if DEBUG
        os_log(.debug, log: osLog, "[%{public}@] %{public}@", category, message)
        #endif
    }
}

// MARK: - Mock Logger for Testing
class MockStoryLogger: StoryLoggingProtocol {
    private(set) var loggedEvents: [StoryAnalyticsEvent] = []
    private(set) var loggedErrors: [(StoryError, String)] = []
    private(set) var loggedInfo: [(String, String)] = []
    private(set) var loggedDebug: [(String, String)] = []
    
    func log(_ event: StoryAnalyticsEvent) {
        loggedEvents.append(event)
    }
    
    func logError(_ error: StoryError, context: String) {
        loggedErrors.append((error, context))
    }
    
    func logInfo(_ message: String, category: String) {
        loggedInfo.append((message, category))
    }
    
    func logDebug(_ message: String, category: String) {
        loggedDebug.append((message, category))
    }
    
    func clear() {
        loggedEvents.removeAll()
        loggedErrors.removeAll()
        loggedInfo.removeAll()
        loggedDebug.removeAll()
    }
}
