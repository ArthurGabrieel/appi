import Foundation

protocol KeychainService: Sendable {
    func save(_ data: Data, for key: String) throws
    func load(for key: String) throws -> Data?
    func delete(for key: String) throws
}
