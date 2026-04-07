import Testing
import Foundation
@testable import appi

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else { return }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

struct HTTPClientTests {
    func makeClient() -> URLSessionHTTPClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSessionHTTPClient(session: URLSession(configuration: config))
    }

    @Test("Successful GET returns Response with status, body, and duration")
    func successfulGet() async throws {
        let url = try #require(URL(string: "https://api.example.com/users"))
        let responseBody = "{\"users\": []}".data(using: .utf8) ?? Data()

        MockURLProtocol.handler = { _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, responseBody)
        }

        let client = makeClient()
        let resolved = ResolvedRequest(
            method: .get, url: url, headers: [], body: .none, auth: .none
        )

        let result = try await client.execute(resolved)

        #expect(result.statusCode == 200)
        #expect(result.body == responseBody)
        #expect(result.contentType == "application/json")
        #expect(result.duration > 0)
        #expect(result.size == responseBody.count)
    }
}
