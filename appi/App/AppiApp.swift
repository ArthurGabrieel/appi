//
//  AppiApp.swift
//  appi
//
//  Created by Arthur Gabriel Lima Gomes on 06/04/26.
//

import SwiftUI
import SwiftData

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
