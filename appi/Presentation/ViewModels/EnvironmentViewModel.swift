// appi/Presentation/ViewModels/EnvironmentViewModel.swift
import Foundation

@Observable @MainActor
final class EnvironmentViewModel {
    var environments: [Environment] = []
    var activeEnvironment: Environment? { environments.first(where: { $0.isActive }) }
    var error: (any LocalizedError)?

    let workspaceId: UUID
    private let environmentRepository: any EnvironmentRepository

    init(workspaceId: UUID, environmentRepository: any EnvironmentRepository) {
        self.workspaceId = workspaceId
        self.environmentRepository = environmentRepository
    }

    func clearError() {
        error = nil
    }

    func loadEnvironments() async {
        do {
            environments = try await environmentRepository.fetchAll(in: workspaceId)
            error = nil
        } catch {
            self.error = error as? any LocalizedError ?? PersistenceError.fetchFailed(error)
        }
    }

    func createEnvironment(name: String) async {
        let env = Environment(
            id: UUID(), name: name, isActive: false,
            workspaceId: workspaceId, variables: [],
            createdAt: Date(), updatedAt: Date()
        )
        do {
            try await environmentRepository.save(env)
            error = nil
            await loadEnvironments()
        } catch {
            self.error = error as? any LocalizedError ?? PersistenceError.saveFailed(error)
        }
    }

    func rename(_ environmentId: UUID, to newName: String) async {
        guard var env = environments.first(where: { $0.id == environmentId }) else { return }
        env.name = newName
        env.updatedAt = Date()
        do {
            try await environmentRepository.save(env)
            error = nil
            await loadEnvironments()
        } catch {
            self.error = error as? any LocalizedError ?? PersistenceError.saveFailed(error)
        }
    }

    func delete(_ environment: Environment) async {
        do {
            try await environmentRepository.delete(environment)
            error = nil
            await loadEnvironments()
        } catch {
            self.error = error as? any LocalizedError ?? PersistenceError.saveFailed(error)
        }
    }

    func activate(_ environment: Environment) async {
        do {
            try await environmentRepository.activate(environment)
            error = nil
            await loadEnvironments()
        } catch {
            self.error = error as? any LocalizedError ?? PersistenceError.saveFailed(error)
        }
    }

    func deactivate() async {
        guard var env = activeEnvironment else { return }
        env.isActive = false
        env.updatedAt = Date()
        do {
            try await environmentRepository.save(env)
            error = nil
            await loadEnvironments()
        } catch {
            self.error = error as? any LocalizedError ?? PersistenceError.saveFailed(error)
        }
    }

    // MARK: - Variable management

    func addVariable(to environmentId: UUID, key: String, value: String, isSecret: Bool) async {
        guard var env = environments.first(where: { $0.id == environmentId }) else { return }
        let variable = EnvVariable(
            id: UUID(), key: key, value: value,
            isSecret: isSecret, isEnabled: true,
            environmentId: environmentId
        )
        env.variables.append(variable)
        env.updatedAt = Date()
        do {
            try await environmentRepository.save(env)
            error = nil
            await loadEnvironments()
        } catch {
            self.error = error as? any LocalizedError ?? PersistenceError.saveFailed(error)
        }
    }

    func updateVariable(_ variableId: UUID, in environmentId: UUID, key: String, value: String, isSecret: Bool) async {
        guard var env = environments.first(where: { $0.id == environmentId }),
              let idx = env.variables.firstIndex(where: { $0.id == variableId }) else { return }
        env.variables[idx].key = key
        env.variables[idx].value = value
        env.variables[idx].isSecret = isSecret
        env.updatedAt = Date()
        do {
            try await environmentRepository.save(env)
            error = nil
            await loadEnvironments()
        } catch {
            self.error = error as? any LocalizedError ?? PersistenceError.saveFailed(error)
        }
    }

    func toggleVariable(_ variableId: UUID, in environmentId: UUID) async {
        guard var env = environments.first(where: { $0.id == environmentId }),
              let idx = env.variables.firstIndex(where: { $0.id == variableId }) else { return }
        env.variables[idx].isEnabled.toggle()
        env.updatedAt = Date()
        do {
            try await environmentRepository.save(env)
            error = nil
            await loadEnvironments()
        } catch {
            self.error = error as? any LocalizedError ?? PersistenceError.saveFailed(error)
        }
    }

    func toggleVariableSecret(_ variableId: UUID, in environmentId: UUID) async {
        guard var env = environments.first(where: { $0.id == environmentId }),
              let idx = env.variables.firstIndex(where: { $0.id == variableId }) else { return }
        env.variables[idx].isSecret.toggle()
        env.updatedAt = Date()
        do {
            try await environmentRepository.save(env)
            error = nil
            await loadEnvironments()
        } catch {
            self.error = error as? any LocalizedError ?? PersistenceError.saveFailed(error)
        }
    }

    func deleteVariable(_ variableId: UUID, from environmentId: UUID) async {
        guard var env = environments.first(where: { $0.id == environmentId }) else { return }
        env.variables.removeAll { $0.id == variableId }
        env.updatedAt = Date()
        do {
            try await environmentRepository.save(env)
            error = nil
            await loadEnvironments()
        } catch {
            self.error = error as? any LocalizedError ?? PersistenceError.saveFailed(error)
        }
    }
}
