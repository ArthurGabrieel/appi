import Foundation

protocol CollectionRepository: Sendable {
    func fetchAll(in workspaceId: UUID) async throws -> [Collection]
    func save(_ collection: Collection) async throws
    func delete(_ collection: Collection) async throws
    func move(_ collection: Collection, to parent: Collection?) async throws
    func ancestorChain(for collectionId: UUID) async throws -> [Collection]
}
