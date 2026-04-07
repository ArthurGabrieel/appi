import Foundation
@testable import appi

final class MockTabRepository: TabRepository, @unchecked Sendable {
    var tabs: [Tab] = []
    var saveCalled = false
    var savedTab: Tab?
    var deleteCalled = false
    var cleanupOrphanedLinksCalled = false

    func fetchAll() async throws -> [Tab] {
        tabs.sorted { $0.sortIndex < $1.sortIndex }
    }

    func save(_ tab: Tab) async throws {
        saveCalled = true
        savedTab = tab
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs[index] = tab
        } else {
            tabs.append(tab)
        }
    }

    func delete(_ tab: Tab) async throws {
        deleteCalled = true
        tabs.removeAll { $0.id == tab.id }
    }

    func cleanupOrphanedLinks() async throws {
        cleanupOrphanedLinksCalled = true
    }
}
