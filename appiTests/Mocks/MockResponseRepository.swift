import Foundation
@testable import appi

final class MockResponseRepository: ResponseRepository, @unchecked Sendable {
    var responses: [Response] = []
    var saveCalled = false
    var savedForRequestId: UUID?

    func fetchHistory(for requestId: UUID) async throws -> [Response] {
        responses
    }

    func save(_ response: Response, forRequestId requestId: UUID) async throws {
        saveCalled = true
        savedForRequestId = requestId
        responses.append(response)
    }
}
