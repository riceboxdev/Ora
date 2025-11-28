//
//  LoggingConfigurationAdapter.swift
//  OraBeta
//
//  Adapter to configure OraLogging package from app-specific Config
//

import Foundation
import OraLogging

/// Convert app LogLevel to OraLogging LogLevel
private func convertLogLevel(_ level: LogLevel?) -> OraLogging.LogLevel? {
    guard let level = level else { return nil }
    switch level {
    case .none: return .none
    case .minimal: return .minimal
    case .full: return .full
    }
}

/// Convert app service log levels to OraLogging log levels
private func convertServiceLogLevels(_ levels: [String: LogLevel]) -> [String: OraLogging.LogLevel] {
    return levels.mapValues { convertLogLevel($0) ?? .full }
}

/// Configure the OraLogging package from app-specific Config
/// This should be called early in app initialization (e.g., in AppDelegate or OraBetaApp.init)
public func configureOraLogging() {
    let configuration = OraLogging.LoggingConfiguration(
        defaultLogLevel: convertLogLevel(Config.logLevel),
        serviceLogLevels: convertServiceLogLevels(Config.serviceLogLevels),
        serviceLoggingStates: Config.serviceLoggingStates
    )
    OraLogging.LoggingConfig.configure(configuration)
}



