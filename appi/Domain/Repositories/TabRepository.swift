import Foundation

protocol TabRepository: Sendable {
    func fetchAll() async throws -> [Tab]
    func save(_ tab: Tab) async throws
    func delete(_ tab: Tab) async throws
    func cleanupOrphanedLinks() async throws
}
