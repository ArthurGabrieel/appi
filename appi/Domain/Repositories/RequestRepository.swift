import Foundation

protocol RequestRepository: Sendable {
    func fetchAll(in collectionId: UUID) async throws -> [Request]
    func save(_ request: Request) async throws
    func move(_ requestId: UUID, toCollection: UUID, sortIndex: Int) async throws
    func delete(_ request: Request) async throws
    func duplicate(_ request: Request) async throws -> Request
}
