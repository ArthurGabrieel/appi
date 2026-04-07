import Foundation
@testable import appi

final class MockRequestRepository: RequestRepository, @unchecked Sendable {
    var requests: [Request] = []
    var saveCalled = false
    var deleteCalled = false
    var savedRequest: Request?

    func fetchAll(in collectionId: UUID) async throws -> [Request] {
        requests.filter { $0.collectionId == collectionId }
    }

    func save(_ request: Request) async throws {
        saveCalled = true
        savedRequest = request
        if let index = requests.firstIndex(where: { $0.id == request.id }) {
            requests[index] = request
        } else {
            requests.append(request)
        }
    }

    func delete(_ request: Request) async throws {
        deleteCalled = true
        requests.removeAll { $0.id == request.id }
    }

    func duplicate(_ request: Request) async throws -> Request {
        let copy = Request(
            id: UUID(), name: "\(request.name) Copy", method: request.method,
            url: request.url, headers: request.headers, body: request.body,
            auth: request.auth, collectionId: request.collectionId,
            sortIndex: request.sortIndex + 1, createdAt: Date(), updatedAt: Date()
        )
        requests.append(copy)
        return copy
    }
}
