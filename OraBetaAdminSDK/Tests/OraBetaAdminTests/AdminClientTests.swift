import XCTest
@testable import OraBetaAdmin

final class AdminClientTests: XCTestCase {
    func testConfigValidation() {
        let validConfig = AdminConfig(baseURL: "https://api.example.com")
        XCTAssertTrue(validConfig.isValid)
        
        let invalidConfig = AdminConfig(baseURL: "")
        XCTAssertFalse(invalidConfig.isValid)
    }
    
    func testConfigWithToken() {
        let config = AdminConfig(baseURL: "https://api.example.com")
        let configWithToken = config.withToken("test-token")
        
        XCTAssertEqual(configWithToken.token, "test-token")
        XCTAssertEqual(configWithToken.baseURL, config.baseURL)
    }
}










