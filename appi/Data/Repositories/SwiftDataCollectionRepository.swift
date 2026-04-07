import Foundation
import SwiftData

@ModelActor
actor SwiftDataCollectionRepository: CollectionRepository {
    func fetchAll(in workspaceId: UUID) async throws -> [Collection] {
        let predicate = #Predicate<CollectionModel> { $0.workspaceId == workspaceId }
        let descriptor = FetchDescriptor<CollectionModel>(predicate: predicate, sortBy: [SortDescriptor(\.sortIndex)])
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    func save(_ collection: Collection) async throws {
        let id = collection.id
        let predicate = #Predicate<CollectionModel> { $0.id == id }
        let descriptor = FetchDescriptor<CollectionModel>(predicate: predicate)
        if let existing = try modelContext.fetch(descriptor).first {
            existing.name = collection.name
            existing.parentId = collection.parentId
            existing.sortIndex = collection.sortIndex
            existing.authData = (try? JSONEncoder().encode(collection.auth)) ?? Data()
            existing.updatedAt = Date()
        } else {
            modelContext.insert(CollectionModel(from: collection))
        }
        try modelContext.save()
    }

    func delete(_ collection: Collection) async throws {
        let id = collection.id
        let predicate = #Predicate<CollectionModel> { $0.id == id }
        let descriptor = FetchDescriptor<CollectionModel>(predicate: predicate)
        if let model = try modelContext.fetch(descriptor).first {
            modelContext.delete(model)
            try modelContext.save()
        }
    }

    func move(_ collection: Collection, to parent: Collection?) async throws {
        let id = collection.id
        let predicate = #Predicate<CollectionModel> { $0.id == id }
        let descriptor = FetchDescriptor<CollectionModel>(predicate: predicate)
        if let model = try modelContext.fetch(descriptor).first {
            model.parentId = parent?.id
            model.updatedAt = Date()
            try modelContext.save()
        }
    }

    func ancestorChain(for collectionId: UUID) async throws -> [Collection] {
        var chain: [Collection] = []
        var currentId: UUID? = collectionId

        while let id = currentId {
            let predicate = #Predicate<CollectionModel> { $0.id == id }
            let descriptor = FetchDescriptor<CollectionModel>(predicate: predicate)
            guard let model = try modelContext.fetch(descriptor).first else { break }
            chain.append(model.toDomain())
            currentId = model.parentId
        }

        return chain
    }
}
