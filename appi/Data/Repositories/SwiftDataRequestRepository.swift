import Foundation
import SwiftData

@ModelActor
actor SwiftDataRequestRepository: RequestRepository {
    func fetchAll(in collectionId: UUID) async throws -> [Request] {
        let predicate = #Predicate<RequestModel> { $0.collectionId == collectionId }
        let descriptor = FetchDescriptor<RequestModel>(predicate: predicate, sortBy: [SortDescriptor(\.sortIndex)])
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    func save(_ request: Request) async throws {
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
            existing.sortIndex = request.sortIndex
            existing.updatedAt = Date()
        } else {
            modelContext.insert(RequestModel(from: request))
        }
        try modelContext.save()
    }

    func delete(_ request: Request) async throws {
        let id = request.id
        let predicate = #Predicate<RequestModel> { $0.id == id }
        let descriptor = FetchDescriptor<RequestModel>(predicate: predicate)
        if let model = try modelContext.fetch(descriptor).first {
            modelContext.delete(model)
            try modelContext.save()
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
