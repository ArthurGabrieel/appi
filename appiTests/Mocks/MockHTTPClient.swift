import Foundation
@testable import appi

final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    var result: Result<Response, Error> = .failure(RequestError.cancelled)
    var executedRequest: ResolvedRequest?

    func execute(_ request: ResolvedRequest) async throws -> Response {
        executedRequest = request
        return try result.get()
    }

    func cancel() {}
}
