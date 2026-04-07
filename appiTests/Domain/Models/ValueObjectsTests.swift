import Foundation
import Testing
@testable import appi

struct HTTPMethodTests {
    @Test("All HTTP methods have correct raw values")
    func rawValues() {
        #expect(HTTPMethod.get.rawValue == "GET")
        #expect(HTTPMethod.post.rawValue == "POST")
        #expect(HTTPMethod.put.rawValue == "PUT")
        #expect(HTTPMethod.patch.rawValue == "PATCH")
        #expect(HTTPMethod.delete.rawValue == "DELETE")
        #expect(HTTPMethod.head.rawValue == "HEAD")
        #expect(HTTPMethod.options.rawValue == "OPTIONS")
    }

    @Test("HTTPMethod is CaseIterable with 7 cases")
    func caseIterable() {
        #expect(HTTPMethod.allCases.count == 7)
    }
}

struct HeaderTests {
    @Test("Header preserves key case")
    func preservesCase() {
        let header = Header(id: UUID(), key: "Content-Type", value: "application/json", isEnabled: true)
        #expect(header.key == "Content-Type")
    }
}

struct RequestBodyTests {
    @Test("RequestBody.none round-trips through Codable")
    func noneRoundTrip() throws {
        let body = RequestBody.none
        let data = try JSONEncoder().encode(body)
        let decoded = try JSONDecoder().decode(RequestBody.self, from: data)
        #expect(decoded == .none)
    }

    @Test("RequestBody.raw round-trips through Codable")
    func rawRoundTrip() throws {
        let body = RequestBody.raw("{}", contentType: "application/json")
        let data = try JSONEncoder().encode(body)
        let decoded = try JSONDecoder().decode(RequestBody.self, from: data)
        #expect(decoded == body)
    }

    @Test("RequestBody.formData round-trips through Codable")
    func formDataRoundTrip() throws {
        let field = FormField(id: UUID(), key: "name", value: .text("test"), isEnabled: true)
        let body = RequestBody.formData([field])
        let data = try JSONEncoder().encode(body)
        let decoded = try JSONDecoder().decode(RequestBody.self, from: data)
        #expect(decoded == body)
    }
}

struct AuthConfigTests {
    @Test("AuthConfig.inheritFromParent round-trips through Codable")
    func inheritRoundTrip() throws {
        let auth = AuthConfig.inheritFromParent
        let data = try JSONEncoder().encode(auth)
        let decoded = try JSONDecoder().decode(AuthConfig.self, from: data)
        #expect(decoded == auth)
    }

    @Test("AuthConfig.oauth2 round-trips through Codable")
    func oauth2RoundTrip() throws {
        let config = OAuth2Config(
            authURL: "https://auth.example.com",
            tokenURL: "https://token.example.com",
            clientId: "client123",
            clientSecret: nil,
            scopes: ["read", "write"],
            redirectURI: "appi://callback"
        )
        let auth = AuthConfig.oauth2(config)
        let data = try JSONEncoder().encode(auth)
        let decoded = try JSONDecoder().decode(AuthConfig.self, from: data)
        #expect(decoded == auth)
    }
}

struct PreparedRequestTests {
    @Test("withAuth combines PreparedRequest and ResolvedAuth into ResolvedRequest")
    func withAuth() throws {
        let url = try #require(URL(string: "https://api.example.com"))
        let prepared = PreparedRequest(method: .get, url: url, headers: [], body: .none)
        let auth = ResolvedAuth.bearer(token: "abc123")
        let resolved = prepared.withAuth(auth)

        #expect(resolved.method == .get)
        #expect(resolved.url == url)
        #expect(resolved.auth == auth)
    }
}
