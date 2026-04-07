import Testing
import Foundation
@testable import appi

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var delay: TimeInterval = 0
    nonisolated(unsafe) static var delayProvider: ((URLRequest) -> TimeInterval)?
    private static let stateLock = NSLock()
    nonisolated(unsafe) private static var _handlerCallCount = 0

    private var pendingWorkItem: DispatchWorkItem?
    private var isStopped = false
    private var didComplete = false

    static func resetState() {
        stateLock.lock()
        handler = nil
        delay = 0
        delayProvider = nil
        _handlerCallCount = 0
        stateLock.unlock()
    }

    static func handlerCallCount() -> Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _handlerCallCount
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isStopped, let handler = Self.handler else { return }
            do {
                Self.stateLock.lock()
                Self._handlerCallCount += 1
                Self.stateLock.unlock()
                let (response, data) = try handler(self.request)
                self.didComplete = true
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: data)
                self.client?.urlProtocolDidFinishLoading(self)
            } catch {
                self.didComplete = true
                self.client?.urlProtocol(self, didFailWithError: error)
            }
        }
        pendingWorkItem = workItem

        let delay = Self.delayProvider?(request) ?? Self.delay

        if delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: workItem)
        } else {
            workItem.perform()
        }
    }

    override func stopLoading() {
        guard !isStopped else { return }
        isStopped = true
        pendingWorkItem?.cancel()
        if !didComplete {
            client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
        }
    }
}

@MainActor
@Suite(.serialized)
struct HTTPClientTests {
    func makeClient() -> URLSessionHTTPClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSessionHTTPClient(session: URLSession(configuration: config))
    }

    @Test("Successful GET returns Response with status, body, and duration")
    func successfulGet() async throws {
        MockURLProtocol.resetState()
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

    @Test("Task cancellation cancels an in-flight request")
    func cancelInFlightRequest() async {
        MockURLProtocol.resetState()
        MockURLProtocol.delay = 0.2
        MockURLProtocol.delayProvider = nil

        let url = URL(string: "https://api.example.com/users")!
        MockURLProtocol.handler = { _ in
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{}".utf8))
        }

        let client = makeClient()
        let resolved = ResolvedRequest(
            method: .get,
            url: url,
            headers: [],
            body: .none,
            auth: .none
        )

        let task = Task { try await client.execute(resolved) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected RequestError.cancelled")
        } catch let error as RequestError {
            #expect(error == .cancelled)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        MockURLProtocol.resetState()
    }

    @Test("A task cancelled before execute starts does not keep the request alive")
    func preCancelledTaskDoesNotExecuteRequest() async {
        MockURLProtocol.resetState()
        MockURLProtocol.delay = 0.2
        MockURLProtocol.delayProvider = nil

        let url = URL(string: "https://api.example.com/users")!
        MockURLProtocol.handler = { _ in
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{}".utf8))
        }

        let client = makeClient()
        let resolved = ResolvedRequest(
            method: .get,
            url: url,
            headers: [],
            body: .none,
            auth: .none
        )

        let task = Task {
            withUnsafeCurrentTask { currentTask in
                currentTask?.cancel()
            }
            return try await client.execute(resolved)
        }

        do {
            _ = try await task.value
            Issue.record("Expected RequestError.cancelled")
        } catch let error as RequestError {
            #expect(error == .cancelled)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(MockURLProtocol.handlerCallCount() == 0)

        MockURLProtocol.resetState()
    }
}
