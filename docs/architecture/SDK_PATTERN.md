# SDK Pattern Template

This document outlines the standard pattern for creating SDKs that interact with API services, based on the Waitlist SDK architecture.

## Directory Structure

```
SDK/
├── Configuration/
│   └── SDKConfig.swift          # Configuration struct
├── Models/
│   ├── SDKModels.swift          # Response models (Codable)
│   └── SDKError.swift          # Error types
├── SDKClient.swift             # Main client class
└── UI/                         # Optional SwiftUI components
    └── SDKView.swift
```

## Configuration Pattern

```swift
import Foundation

/// Configuration for the SDK
public struct SDKConfig {
    /// The API key for authentication
    public let apiKey: String
    
    /// The base URL of the API server
    public let baseURL: String
    
    /// The resource ID (e.g., waitlist ID, project ID)
    public let resourceId: String
    
    /// Default base URL for the service
    public static let defaultBaseURL = "https://api.example.com"
    
    /// Initialize a new SDK configuration
    public init(
        apiKey: String,
        resourceId: String,
        baseURL: String = SDKConfig.defaultBaseURL
    ) {
        self.apiKey = apiKey
        self.resourceId = resourceId
        self.baseURL = baseURL
    }
    
    /// Validates the configuration
    public var isValid: Bool {
        return !apiKey.isEmpty && !resourceId.isEmpty && !baseURL.isEmpty
    }
}
```

## Error Handling Pattern

```swift
import Foundation

/// SDK-specific errors
public enum SDKError: Error, LocalizedError {
    case invalidConfiguration
    case invalidInput(String)
    case networkError(Error)
    case serverError(String)
    case unauthorized
    case notFound
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid SDK configuration"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unauthorized:
            return "Unauthorized: check your API key"
        case .notFound:
            return "Resource not found"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}
```

## Model Pattern

```swift
import Foundation

/// Response model example
public struct SDKResponse: Codable {
    public let id: String
    public let name: String
    public let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt
    }
}
```

## Client Pattern

```swift
import Foundation

/// Main client for interacting with the API
@available(iOS 15.0, macOS 12.0, *)
public final class SDKClient: @unchecked Sendable {
    private let config: SDKConfig
    private let session: URLSession
    
    /// Initialize a new SDK client
    public init(config: SDKConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }
    
    /// Example API method
    public func fetchResource() async throws -> SDKResponse {
        guard config.isValid else {
            throw SDKError.invalidConfiguration
        }
        
        let url = URL(string: "\(config.baseURL)/api/resource/\(config.resourceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SDKError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                return try decoder.decode(SDKResponse.self, from: data)
            } else if httpResponse.statusCode == 401 {
                throw SDKError.unauthorized
            } else {
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                throw SDKError.serverError(errorMessage?["message"] ?? "Server error")
            }
        } catch let error as SDKError {
            throw error
        } catch {
            throw SDKError.networkError(error)
        }
    }
}
```

## UI Component Pattern (Optional)

```swift
import SwiftUI

/// SwiftUI component for SDK functionality
public struct SDKView: View {
    private let config: SDKConfig
    @StateObject private var client: SDKClient
    
    public init(config: SDKConfig) {
        self.config = config
        _client = StateObject(wrappedValue: SDKClient(config: config))
    }
    
    public var body: some View {
        // UI implementation
    }
}
```

## Best Practices

1. **Async/Await**: Use modern async/await APIs for all network calls
2. **Error Handling**: Provide typed errors with descriptive messages
3. **Validation**: Validate configuration and inputs before making requests
4. **Thread Safety**: Mark client as `@unchecked Sendable` if needed
5. **Documentation**: Document all public APIs with doc comments
6. **Testing**: Include unit tests for client methods
7. **Versioning**: Support iOS 15.0+ and macOS 12.0+ minimum













