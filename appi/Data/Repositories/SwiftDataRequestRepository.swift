import Foundation
import SwiftData

@ModelActor
actor SwiftDataRequestRepository: RequestRepository {
    func fetchAll(in collectionId: UUID) async throws -> [Request] {
        do {
            let predicate = #Predicate<RequestModel> { $0.collectionId == collectionId }
            let descriptor = FetchDescriptor<RequestModel>(predicate: predicate, sortBy: [SortDescriptor(\.sortIndex)])
            let models = try modelContext.fetch(descriptor)
            return models.map { $0.toDomain() }
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.fetchFailed(error)
        }
    }

    func save(_ request: Request) async throws {
        do {
            let id = request.id
            let predicate = #Predicate<RequestModel> { $0.id == id }
            let descriptor = FetchDescriptor<RequestModel>(predicate: predicate)
            if let existing = try modelContext.fetch(descriptor).first {
                existing.name = request.name
                existing.method = request.method.rawValue
                existing.url = request.url
                existing.headersData = (try? JSONEncoder().encode(request.headers)) ?? Data()
                existing.bodyData = (try? JSONEncoder().encode(request.body)) ?? Data()
                existing.authData = (try? JSONEncoder().encode(request.auth)) ?? Data()
                existing.collectionId = request.collectionId
                // Preserve persisted ordering when updating from editor drafts.
                existing.updatedAt = Date()
            } else {
                modelContext.insert(RequestModel(from: request))
            }
            try modelContext.save()
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }

    func move(_ requestId: UUID, toCollection collectionId: UUID, sortIndex: Int) async throws {
        do {
            let id = requestId
            let predicate = #Predicate<RequestModel> { $0.id == id }
            if let existing = try modelContext.fetch(FetchDescriptor<RequestModel>(predicate: predicate)).first {
                existing.collectionId = collectionId
                existing.sortIndex = sortIndex
                existing.updatedAt = Date()
                try modelContext.save()
            }
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }

    func delete(_ request: Request) async throws {
        do {
            let id = request.id
            let predicate = #Predicate<RequestModel> { $0.id == id }
            let descriptor = FetchDescriptor<RequestModel>(predicate: predicate)
            if let model = try modelContext.fetch(descriptor).first {
                let responseDescriptor = FetchDescriptor<ResponseModel>()
                let responses = try modelContext.fetch(responseDescriptor)
                for response in responses where response.requestId == id {
                    modelContext.delete(response)
                }

                let tabDescriptor = FetchDescriptor<TabModel>()
                let tabs = try modelContext.fetch(tabDescriptor)
                for tab in tabs where tab.linkedRequestId == id {
                    tab.linkedRequestId = nil
                }

                modelContext.delete(model)
                try modelContext.save()
            }
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }

    func duplicate(_ request: Request) async throws -> Request {
        let copy = Request(
            id: UUID(), name: "\(request.name) Copy", method: request.method,
            url: request.url, headers: request.headers, body: request.body,
            auth: request.auth, collectionId: request.collectionId,
            sortIndex: request.sortIndex + 1, createdAt: Date(), updatedAt: Date()
        )
        try await save(copy)
        return copy
    }
}
