import Testing
import Foundation
@testable import appi

@MainActor
struct EnvironmentViewModelTests {
    struct DuplicateKeyError: LocalizedError {
        var errorDescription: String? { "Duplicate variable key" }
    }

    let workspaceId = UUID()

    func makeVM(repo: MockEnvironmentRepository = MockEnvironmentRepository()) -> EnvironmentViewModel {
        EnvironmentViewModel(workspaceId: workspaceId, environmentRepository: repo)
    }

    @Test("loadEnvironments populates environments and resolves activeEnvironment")
    func loadEnvironments() async throws {
        let repo = MockEnvironmentRepository()
        let e1 = Environment(id: UUID(), name: "Dev", isActive: false, workspaceId: workspaceId, variables: [], createdAt: Date(), updatedAt: Date())
        let e2 = Environment(id: UUID(), name: "Prod", isActive: true, workspaceId: workspaceId, variables: [], createdAt: Date(), updatedAt: Date())
        repo.environments = [e1, e2]

        let vm = makeVM(repo: repo)
        await vm.loadEnvironments()

        #expect(vm.environments.count == 2)
        #expect(vm.activeEnvironment?.name == "Prod")
    }

    @Test("activate sets isActive and reloads")
    func activate() async throws {
        let repo = MockEnvironmentRepository()
        let e1 = Environment(id: UUID(), name: "Dev", isActive: true, workspaceId: workspaceId, variables: [], createdAt: Date(), updatedAt: Date())
        let e2 = Environment(id: UUID(), name: "Prod", isActive: false, workspaceId: workspaceId, variables: [], createdAt: Date(), updatedAt: Date())
        repo.environments = [e1, e2]

        let vm = makeVM(repo: repo)
        await vm.loadEnvironments()
        await vm.activate(e2)

        #expect(repo.activateCalled)
        #expect(vm.activeEnvironment?.id == e2.id)
    }

    @Test("createEnvironment saves and reloads")
    func createEnvironment() async throws {
        let repo = MockEnvironmentRepository()
        let vm = makeVM(repo: repo)
        await vm.loadEnvironments()

        await vm.createEnvironment(name: "Staging")

        #expect(repo.saveCalled)
        #expect(vm.environments.first?.name == "Staging")
    }

    @Test("addVariable adds to environment and saves")
    func addVariable() async throws {
        let repo = MockEnvironmentRepository()
        let env = Environment(id: UUID(), name: "Dev", isActive: true, workspaceId: workspaceId, variables: [], createdAt: Date(), updatedAt: Date())
        repo.environments = [env]

        let vm = makeVM(repo: repo)
        await vm.loadEnvironments()
        await vm.addVariable(to: env.id, key: "BASE_URL", value: "https://dev.example.com", isSecret: false)

        let updated = vm.environments.first
        #expect(updated?.variables.count == 1)
        #expect(updated?.variables.first?.key == "BASE_URL")
    }

    @Test("toggleVariableSecret updates isSecret and saves")
    func toggleVariableSecret() async throws {
        let repo = MockEnvironmentRepository()
        let envId = UUID()
        let variable = EnvVariable(
            id: UUID(), key: "TOKEN", value: "secret",
            isSecret: false, isEnabled: true, environmentId: envId
        )
        let env = Environment(
            id: envId, name: "Dev", isActive: true, workspaceId: workspaceId,
            variables: [variable], createdAt: Date(), updatedAt: Date()
        )
        repo.environments = [env]

        let vm = makeVM(repo: repo)
        await vm.loadEnvironments()
        await vm.toggleVariableSecret(variable.id, in: env.id)

        #expect(vm.environments.first?.variables.first?.isSecret == true)
    }

    @Test("deactivate clears active environment")
    func deactivate() async throws {
        let repo = MockEnvironmentRepository()
        let env = Environment(id: UUID(), name: "Dev", isActive: true, workspaceId: workspaceId, variables: [], createdAt: Date(), updatedAt: Date())
        repo.environments = [env]

        let vm = makeVM(repo: repo)
        await vm.loadEnvironments()
        await vm.deactivate()

        #expect(repo.saveCalled)
        #expect(vm.activeEnvironment == nil)
    }

    @Test("rename updates environment name")
    func rename() async throws {
        let repo = MockEnvironmentRepository()
        let env = Environment(id: UUID(), name: "Dev", isActive: true, workspaceId: workspaceId, variables: [], createdAt: Date(), updatedAt: Date())
        repo.environments = [env]

        let vm = makeVM(repo: repo)
        await vm.loadEnvironments()
        await vm.rename(env.id, to: "Development")

        #expect(repo.saveCalled)
        #expect(vm.environments.first?.name == "Development")
    }

    @Test("duplicate variable key error is surfaced inline")
    func duplicateVariableKeySetsError() async throws {
        let repo = MockEnvironmentRepository()
        repo.saveError = DuplicateKeyError()
        let env = Environment(id: UUID(), name: "Dev", isActive: true, workspaceId: workspaceId, variables: [], createdAt: Date(), updatedAt: Date())
        repo.environments = [env]

        let vm = makeVM(repo: repo)
        await vm.loadEnvironments()
        await vm.addVariable(to: env.id, key: "TOKEN", value: "a", isSecret: false)

        #expect(vm.error != nil)
    }
}
