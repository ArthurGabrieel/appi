import Foundation

protocol KeychainService: Sendable {
    nonisolated func save(_ data: Data, for key: String) throws
    nonisolated func load(for key: String) throws -> Data?
    nonisolated func delete(for key: String) throws
}
