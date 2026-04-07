import Foundation
import SwiftData

@ModelActor
actor SwiftDataResponseRepository: ResponseRepository {
    func fetchHistory(for requestId: UUID) async throws -> [Response] {
        let predicate = #Predicate<ResponseModel> { $0.requestId == requestId }
        let descriptor = FetchDescriptor<ResponseModel>(predicate: predicate, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    func save(_ response: Response, forRequestId requestId: UUID) async throws {
        modelContext.insert(ResponseModel(from: response, requestId: requestId))
        try modelContext.save()

        // Enforce 50-response limit (RN-03)
        let predicate = #Predicate<ResponseModel> { $0.requestId == requestId }
        let descriptor = FetchDescriptor<ResponseModel>(predicate: predicate, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let all = try modelContext.fetch(descriptor)
        if all.count > 50 {
            for model in all.dropFirst(50) {
                modelContext.delete(model)
            }
            try modelContext.save()
        }
    }
}
