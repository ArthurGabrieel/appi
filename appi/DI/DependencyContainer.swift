import Foundation
import SwiftData

@Observable
final class DependencyContainer {
    let requestRepository: any RequestRepository
    let collectionRepository: any CollectionRepository
    let responseRepository: any ResponseRepository
    let workspaceRepository: any WorkspaceRepository
    let environmentRepository: any EnvironmentRepository
    let tabRepository: any TabRepository
    let httpClient: any HTTPClient
    let envResolver: any EnvResolver
    let keychainService: any KeychainService

    init(modelContainer: ModelContainer) {
        self.requestRepository = SwiftDataRequestRepository(modelContainer: modelContainer)
        self.collectionRepository = SwiftDataCollectionRepository(modelContainer: modelContainer)
        self.responseRepository = SwiftDataResponseRepository(modelContainer: modelContainer)
        self.workspaceRepository = SwiftDataWorkspaceRepository(modelContainer: modelContainer)
        self.environmentRepository = SwiftDataEnvironmentRepository(modelContainer: modelContainer)
        self.tabRepository = SwiftDataTabRepository(modelContainer: modelContainer)
        self.httpClient = URLSessionHTTPClient()
        self.envResolver = DefaultEnvResolver()
        self.keychainService = AppleKeychainService()
    }

    // MARK: - ViewModel Factories
    // Factory methods for ViewModels will be added as they are implemented.
}
