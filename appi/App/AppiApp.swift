//
//  AppiApp.swift
//  appi
//
//  Created by Arthur Gabriel Lima Gomes on 06/04/26.
//

import SwiftUI
import SwiftData

@MainActor
func bootstrapIfNeeded(
    workspaceRepository: any WorkspaceRepository,
    collectionRepository: any CollectionRepository,
    tabRepository: any TabRepository
) async {
    do {
        let workspaces = try await workspaceRepository.fetchAll()
        guard workspaces.isEmpty else { return }

        let workspace = Workspace(id: UUID(), name: "My Workspace", createdAt: Date())
        try await workspaceRepository.save(workspace)

        let collection = Collection(
            id: UUID(), name: "My Collection", parentId: nil,
            sortIndex: 0, workspaceId: workspace.id, auth: .none,
            createdAt: Date(), updatedAt: Date()
        )
        try await collectionRepository.save(collection)

        let tab = Tab(
            id: UUID(), linkedRequestId: nil,
            draft: RequestDraft.empty(in: collection.id),
            originalDraft: nil,
            sortIndex: 0, isActive: true, createdAt: Date()
        )
        try await tabRepository.save(tab)
    } catch {
        // First launch is best-effort — app still opens
    }
}

@main
struct AppiApp: App {
    let modelContainer: ModelContainer
    let container: DependencyContainer

    init() {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let modelContainer = try! ModelContainer(for: schema)
        self.modelContainer = modelContainer
        self.container = DependencyContainer(modelContainer: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(container)
        }
    }
}
