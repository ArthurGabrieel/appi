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

    func move(_ requestId: UUID, toCollection collectionId: UUID, sortIndex: Int) async throws {
        if let index = requests.firstIndex(where: { $0.id == requestId }) {
            requests[index].collectionId = collectionId
            requests[index].sortIndex = sortIndex
        }
    }

    func delete(_ request: Request) async throws {
        deleteCalled = true
        requests.removeAll { $0.id == request.id }
    }
}
