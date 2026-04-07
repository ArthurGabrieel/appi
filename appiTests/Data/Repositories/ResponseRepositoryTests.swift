import Testing
import Foundation
import SwiftData
@testable import appi

struct ResponseRepositoryTests {
    func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: WorkspaceModel.self, CollectionModel.self, RequestModel.self,
            ResponseModel.self, EnvironmentModel.self, EnvVariableModel.self, TabModel.self,
            configurations: config
        )
    }

    @Test("history limited to 50 responses per request (RN-03)")
    func historyLimitedTo50() async throws {
        let container = try makeContainer()
        let repo = SwiftDataResponseRepository(modelContainer: container)
        let requestId = UUID()

        for i in 0..<55 {
            let response = Response(
                id: UUID(), statusCode: 200, statusMessage: "OK",
                headers: [], body: Data(), contentType: "application/json",
                duration: 0.1, size: 10, createdAt: Date().addingTimeInterval(TimeInterval(i))
            )
            try await repo.save(response, forRequestId: requestId)
        }

        let history = try await repo.fetchHistory(for: requestId)
        #expect(history.count == 50)
    }
}
