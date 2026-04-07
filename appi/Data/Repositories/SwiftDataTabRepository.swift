import Foundation
import SwiftData

@ModelActor
actor SwiftDataTabRepository: TabRepository {
    func fetchAll() async throws -> [Tab] {
        let descriptor = FetchDescriptor<TabModel>(sortBy: [SortDescriptor(\.sortIndex)])
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    func save(_ tab: Tab) async throws {
        let id = tab.id
        let predicate = #Predicate<TabModel> { $0.id == id }
        let descriptor = FetchDescriptor<TabModel>(predicate: predicate)
        if let existing = try modelContext.fetch(descriptor).first {
            existing.linkedRequestId = tab.linkedRequestId
            existing.draftData = (try? JSONEncoder().encode(tab.draft)) ?? Data()
            existing.originalDraftData = tab.originalDraft.flatMap { try? JSONEncoder().encode($0) }
            existing.sortIndex = tab.sortIndex
            existing.isActive = tab.isActive
        } else {
            modelContext.insert(TabModel(from: tab))
        }
        try modelContext.save()
    }

    func delete(_ tab: Tab) async throws {
        let id = tab.id
        let predicate = #Predicate<TabModel> { $0.id == id }
        let descriptor = FetchDescriptor<TabModel>(predicate: predicate)
        if let model = try modelContext.fetch(descriptor).first {
            modelContext.delete(model)
            try modelContext.save()
        }
    }

    func cleanupOrphanedLinks() async throws {
        let descriptor = FetchDescriptor<TabModel>()
        let tabs = try modelContext.fetch(descriptor)

        for tab in tabs {
            guard let requestId = tab.linkedRequestId else { continue }
            let predicate = #Predicate<RequestModel> { $0.id == requestId }
            let requestDescriptor = FetchDescriptor<RequestModel>(predicate: predicate)
            if try modelContext.fetch(requestDescriptor).isEmpty {
                tab.linkedRequestId = nil
            }
        }
        try modelContext.save()
    }
}
