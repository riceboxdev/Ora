//
//  LogLevel.swift
//  OraLogging
//
//  Log level enumeration
//

import Foundation

/// Log level enumeration
public enum LogLevel: String, CaseIterable {
    case none = "none"
    case minimal = "minimal"
    case full = "full"
    
    /// Returns true if this log level should log messages of the given required level
    /// The required level indicates the minimum verbosity needed to log the message
    public func shouldLog(requiredLevel: LogLevel) -> Bool {
        switch self {
        case .none:
            return false
        case .minimal:
            // Minimal mode only logs messages that require minimal or less (i.e., errors and warnings)
            return requiredLevel == .minimal || requiredLevel == .none
        case .full:
            // Full mode logs everything (all required levels)
            return true
        }
    }
}






