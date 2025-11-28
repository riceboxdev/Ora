//
//  FunctionsConfig.swift
//  OraBeta
//
//  Helper to configure Firebase Functions for local development
//

import Foundation
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

#if DEBUG
/// Configure Firebase Functions to use the local emulator when in debug mode
/// Set USE_LOCAL_FUNCTIONS=true in your environment or scheme settings to enable
class FunctionsConfig {
    private static let useLocalEmulator = ProcessInfo.processInfo.environment["USE_LOCAL_FUNCTIONS"] == "true"
    
    /// Get a Functions instance configured for the current environment
    /// - Parameter region: The Firebase Functions region (default: us-central1)
    /// - Returns: Configured Functions instance
    static func functions(region: String = "us-central1") -> Functions {
        let functions = Functions.functions(region: region)
        
        // Connect to local emulator if enabled
        if useLocalEmulator {
            functions.useEmulator(withHost: "localhost", port: 5001)
            print("🔧 FunctionsConfig: Using LOCAL Firebase Functions emulator (localhost:5001)")
        }
        
        return functions
    }
}
#else
/// Production configuration - always uses cloud functions
class FunctionsConfig {
    static func functions(region: String = "us-central1") -> Functions {
        return Functions.functions(region: region)
    }
}
#endif

