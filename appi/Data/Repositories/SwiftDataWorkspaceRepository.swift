import Foundation
import SwiftData

@ModelActor
actor SwiftDataWorkspaceRepository: WorkspaceRepository {
    func fetchAll() async throws -> [Workspace] {
        let descriptor = FetchDescriptor<WorkspaceModel>()
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    func save(_ workspace: Workspace) async throws {
        let id = workspace.id
        let predicate = #Predicate<WorkspaceModel> { $0.id == id }
        let descriptor = FetchDescriptor<WorkspaceModel>(predicate: predicate)
        if let existing = try modelContext.fetch(descriptor).first {
            existing.name = workspace.name
        } else {
            modelContext.insert(WorkspaceModel(from: workspace))
        }
        try modelContext.save()
    }

    func delete(_ workspace: Workspace) async throws {
        let id = workspace.id
        let predicate = #Predicate<WorkspaceModel> { $0.id == id }
        let descriptor = FetchDescriptor<WorkspaceModel>(predicate: predicate)
        if let model = try modelContext.fetch(descriptor).first {
            modelContext.delete(model)
            try modelContext.save()
        }
    }
}
