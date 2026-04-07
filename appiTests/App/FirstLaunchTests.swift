// appiTests/App/FirstLaunchTests.swift
import Testing
import Foundation
@testable import appi

@MainActor
struct FirstLaunchTests {
    @Test("bootstrapIfNeeded creates workspace, collection, and tab on empty DB")
    func bootstrapCreatesDefaults() async throws {
        let workspaceRepo = MockWorkspaceRepository()
        let collectionRepo = MockCollectionRepository()
        let tabRepo = MockTabRepository()

        await bootstrapIfNeeded(
            workspaceRepository: workspaceRepo,
            collectionRepository: collectionRepo,
            tabRepository: tabRepo
        )

        #expect(workspaceRepo.workspaces.count == 1)
        #expect(workspaceRepo.workspaces.first?.name == "My Workspace")

        #expect(collectionRepo.collections.count == 1)
        let collection = try #require(collectionRepo.collections.first)
        #expect(collection.name == "My Collection")
        #expect(collection.parentId == nil)
        #expect(collection.auth == .none)
        #expect(collection.workspaceId == workspaceRepo.workspaces.first?.id)

        #expect(tabRepo.tabs.count == 1)
        let tab = try #require(tabRepo.tabs.first)
        #expect(tab.isActive == true)
        #expect(tab.linkedRequestId == nil)
        #expect(tab.draft.collectionId == collection.id)
    }

    @Test("bootstrapIfNeeded is a no-op when workspace already exists")
    func bootstrapNoOpWhenExists() async throws {
        let workspaceRepo = MockWorkspaceRepository()
        workspaceRepo.workspaces = [
            Workspace(id: UUID(), name: "Existing", createdAt: Date())
        ]
        let collectionRepo = MockCollectionRepository()
        let tabRepo = MockTabRepository()

        await bootstrapIfNeeded(
            workspaceRepository: workspaceRepo,
            collectionRepository: collectionRepo,
            tabRepository: tabRepo
        )

        #expect(workspaceRepo.workspaces.count == 1)
        #expect(workspaceRepo.workspaces.first?.name == "Existing")
        #expect(collectionRepo.saveCalled == false)
        #expect(tabRepo.saveCalled == false)
    }
}
