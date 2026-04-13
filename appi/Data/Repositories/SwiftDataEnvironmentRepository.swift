import Foundation
import SwiftData

private struct DuplicateVariableKeyError: LocalizedError {
    let key: String
    var errorDescription: String? { "Duplicate variable key: \(key)" }
}

// Manual ModelActor conformance (not @ModelActor macro) because the macro does not
// support injecting additional dependencies via a custom init.
actor SwiftDataEnvironmentRepository: EnvironmentRepository, ModelActor {
    nonisolated let modelExecutor: any ModelExecutor
    nonisolated let modelContainer: ModelContainer
    private let keychainService: any KeychainService

    var modelContext: ModelContext { modelExecutor.modelContext }

    init(modelContainer: ModelContainer, keychainService: any KeychainService) {
        self.keychainService = keychainService
        let context = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.modelContainer = modelContainer
    }

    // MARK: - Helpers

    private func secretKey(environmentId: UUID, variableId: UUID) -> String {
        "envvar.\(environmentId.uuidString).\(variableId.uuidString)"
    }

    // MARK: - EnvironmentRepository

    func fetchAll(in workspaceId: UUID) async throws -> [Environment] {
        let predicate = #Predicate<EnvironmentModel> { $0.workspaceId == workspaceId }
        let descriptor = FetchDescriptor<EnvironmentModel>(predicate: predicate)
        let models = try modelContext.fetch(descriptor)
        return models.map { model in
            var env = model.toDomain()
            env.variables = env.variables.map { variable in
                guard variable.isSecret else { return variable }
                var v = variable
                let key = secretKey(environmentId: env.id, variableId: variable.id)
                v.value = (try? keychainService.load(for: key)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
                return v
            }
            return env
        }
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
        // 1. Validate unique keys
        let keys = environment.variables.map { $0.key }
        var seen: Set<String> = []
        for key in keys {
            if !seen.insert(key).inserted {
                throw DuplicateVariableKeyError(key: key)
            }
        }

        let id = environment.id
        let predicate = #Predicate<EnvironmentModel> { $0.id == id }
        let descriptor = FetchDescriptor<EnvironmentModel>(predicate: predicate)
        if let existing = try modelContext.fetch(descriptor).first {
            existing.name = environment.name
            existing.isActive = environment.isActive
            existing.updatedAt = Date()
            // Remove old variable models
            for variable in existing.variables {
                modelContext.delete(variable)
            }
            // Persist new variable models with Keychain handling
            existing.variables = try environment.variables.map { variable in
                let model = EnvVariableModel(from: variable)
                if variable.isSecret {
                    // Write plaintext to Keychain, store sentinel in SwiftData
                    let key = secretKey(environmentId: environment.id, variableId: variable.id)
                    let data = Data(variable.value.utf8)
                    try keychainService.save(data, for: key)
                    model.value = ""
                } else {
                    // Non-secret: delete any stale Keychain item
                    let key = secretKey(environmentId: environment.id, variableId: variable.id)
                    try? keychainService.delete(for: key)
                    model.value = variable.value
                }
                return model
            }
        } else {
            let model = EnvironmentModel(from: environment)
            // EnvironmentModel(from:) copies value as-is; apply Keychain logic post-construction.
            for variableModel in model.variables {
                if variableModel.isSecret {
                    let key = secretKey(environmentId: environment.id, variableId: variableModel.id)
                    let data = Data(variableModel.value.utf8)
                    try keychainService.save(data, for: key)
                    variableModel.value = ""
                }
            }
            modelContext.insert(model)
        }
        try modelContext.save()
    }

    func delete(_ environment: Environment) async throws {
        // Delete all Keychain items for secret variables first
        for variable in environment.variables where variable.isSecret {
            let key = secretKey(environmentId: environment.id, variableId: variable.id)
            try? keychainService.delete(for: key)
        }

        let id = environment.id
        let predicate = #Predicate<EnvironmentModel> { $0.id == id }
        let descriptor = FetchDescriptor<EnvironmentModel>(predicate: predicate)
        if let model = try modelContext.fetch(descriptor).first {
            modelContext.delete(model)
            try modelContext.save()
        }
    }
}
