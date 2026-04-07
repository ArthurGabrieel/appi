import Foundation
import SwiftData

@ModelActor
actor SwiftDataCollectionRepository: CollectionRepository {
    func fetchAll(in workspaceId: UUID) async throws -> [Collection] {
        do {
            let predicate = #Predicate<CollectionModel> { $0.workspaceId == workspaceId }
            let descriptor = FetchDescriptor<CollectionModel>(predicate: predicate, sortBy: [SortDescriptor(\.sortIndex)])
            let models = try modelContext.fetch(descriptor)
            return models.map { $0.toDomain() }
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.fetchFailed(error)
        }
    }

    func save(_ collection: Collection) async throws {
        do {
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
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }

    func delete(_ collection: Collection) async throws {
        do {
            let collections = try modelContext.fetch(FetchDescriptor<CollectionModel>())
            let requests = try modelContext.fetch(FetchDescriptor<RequestModel>())
            let responses = try modelContext.fetch(FetchDescriptor<ResponseModel>())
            let tabs = try modelContext.fetch(FetchDescriptor<TabModel>())

            let collectionIDs = descendantIDs(of: collection.id, in: collections)
            let requestIDs = Set(
                requests
                    .filter { collectionIDs.contains($0.collectionId) }
                    .map(\.id)
            )

            for response in responses where requestIDs.contains(response.requestId) {
                modelContext.delete(response)
            }

            for request in requests where requestIDs.contains(request.id) {
                modelContext.delete(request)
            }

            for tab in tabs where tab.linkedRequestId.map(requestIDs.contains) == true {
                tab.linkedRequestId = nil
            }

            for model in collections where collectionIDs.contains(model.id) {
                modelContext.delete(model)
            }

            try modelContext.save()
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }

    func move(_ collection: Collection, to parent: Collection?) async throws {
        do {
            let id = collection.id
            let predicate = #Predicate<CollectionModel> { $0.id == id }
            let descriptor = FetchDescriptor<CollectionModel>(predicate: predicate)
            if let model = try modelContext.fetch(descriptor).first {
                model.parentId = parent?.id
                model.updatedAt = Date()
                try modelContext.save()
            }
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }

    func ancestorChain(for collectionId: UUID) async throws -> [Collection] {
        do {
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
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.fetchFailed(error)
        }
    }

    private func descendantIDs(of rootID: UUID, in collections: [CollectionModel]) -> Set<UUID> {
        var collected: Set<UUID> = [rootID]
        var queue: [UUID] = [rootID]

        while let current = queue.first {
            queue.removeFirst()
            let children = collections
                .filter { $0.parentId == current }
                .map(\.id)

            for childID in children where collected.insert(childID).inserted {
                queue.append(childID)
            }
        }

        return collected
    }
}
