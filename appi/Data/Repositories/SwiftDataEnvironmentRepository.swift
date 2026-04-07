import Foundation
import SwiftData

@ModelActor
actor SwiftDataEnvironmentRepository: EnvironmentRepository {
    func fetchAll(in workspaceId: UUID) async throws -> [Environment] {
        let predicate = #Predicate<EnvironmentModel> { $0.workspaceId == workspaceId }
        let descriptor = FetchDescriptor<EnvironmentModel>(predicate: predicate)
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    func activate(_ environment: Environment) async throws {
        let workspaceId = environment.workspaceId
        // Deactivate all in workspace
        let predicate = #Predicate<EnvironmentModel> { $0.workspaceId == workspaceId }
        let descriptor = FetchDescriptor<EnvironmentModel>(predicate: predicate)
        for model in try modelContext.fetch(descriptor) {
            model.isActive = false
        }

        // Activate the target
        let targetId = environment.id
        let targetPredicate = #Predicate<EnvironmentModel> { $0.id == targetId }
        let targetDescriptor = FetchDescriptor<EnvironmentModel>(predicate: targetPredicate)
        if let target = try modelContext.fetch(targetDescriptor).first {
            target.isActive = true
        }
        try modelContext.save()
    }

    func save(_ environment: Environment) async throws {
        let id = environment.id
        let predicate = #Predicate<EnvironmentModel> { $0.id == id }
        let descriptor = FetchDescriptor<EnvironmentModel>(predicate: predicate)
        if let existing = try modelContext.fetch(descriptor).first {
            existing.name = environment.name
            existing.isActive = environment.isActive
            existing.updatedAt = Date()
            // Update variables: remove old, add new
            for variable in existing.variables {
                modelContext.delete(variable)
            }
            existing.variables = environment.variables.map { EnvVariableModel(from: $0) }
        } else {
            modelContext.insert(EnvironmentModel(from: environment))
        }
        try modelContext.save()
    }

    func delete(_ environment: Environment) async throws {
        let id = environment.id
        let predicate = #Predicate<EnvironmentModel> { $0.id == id }
        let descriptor = FetchDescriptor<EnvironmentModel>(predicate: predicate)
        if let model = try modelContext.fetch(descriptor).first {
            modelContext.delete(model)
            try modelContext.save()
        }
    }
}
