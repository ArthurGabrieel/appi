import Foundation

protocol ResponseRepository: Sendable {
    func fetchHistory(for requestId: UUID) async throws -> [Response]
    func save(_ response: Response, forRequestId: UUID) async throws
}
