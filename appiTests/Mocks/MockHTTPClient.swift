import Foundation
@testable import appi

final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    var result: Result<Response, Error> = .failure(RequestError.cancelled)
    var resultProvider: (@Sendable (ResolvedRequest) -> Result<Response, Error>)?
    var executionDelayNanoseconds: UInt64 = 0

    private let lock = NSLock()
    private var executedRequestsStorage: [ResolvedRequest] = []

    var executedRequest: ResolvedRequest? {
        lock.lock()
        defer { lock.unlock() }
        return executedRequestsStorage.last
    }

    func execute(_ request: ResolvedRequest) async throws -> Response {
        lock.lock()
        executedRequestsStorage.append(request)
        let currentResult = result
        let currentProvider = resultProvider
        let delay = executionDelayNanoseconds
        lock.unlock()

        if delay > 0 {
            try await Task.sleep(nanoseconds: delay)
        }

        try Task.checkCancellation()

        if let currentProvider {
            return try currentProvider(request).get()
        }

        return try currentResult.get()
    }
}
