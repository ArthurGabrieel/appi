import Foundation
@testable import appi

final class MockCollectionRepository: CollectionRepository, @unchecked Sendable {
    var collections: [Collection] = []
    var ancestorChainResult: [Collection] = []
    var saveCalled = false
    var ancestorChainError: (any Error)?

    func fetchAll(in workspaceId: UUID) async throws -> [Collection] {
        collections.filter { $0.workspaceId == workspaceId }
    }

    func save(_ collection: Collection) async throws {
        saveCalled = true
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            collections[index] = collection
        } else {
            collections.append(collection)
        }
    }

    func delete(_ collection: Collection) async throws {
        collections.removeAll { $0.id == collection.id }
    }

    func move(_ collection: Collection, to parent: Collection?) async throws {}

    func ancestorChain(for collectionId: UUID) async throws -> [Collection] {
        if let ancestorChainError {
            throw ancestorChainError
        }
        return ancestorChainResult
    }
}
