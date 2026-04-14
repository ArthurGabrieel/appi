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
    let authResolver: any AuthResolver
    let keychainService: any KeychainService
    let authService: any AuthService

    init(modelContainer: ModelContainer) {
        self.requestRepository = SwiftDataRequestRepository(modelContainer: modelContainer)
        self.collectionRepository = SwiftDataCollectionRepository(modelContainer: modelContainer)
        self.responseRepository = SwiftDataResponseRepository(modelContainer: modelContainer)
        self.workspaceRepository = SwiftDataWorkspaceRepository(modelContainer: modelContainer)
        self.keychainService = AppleKeychainService()
        self.environmentRepository = SwiftDataEnvironmentRepository(
            modelContainer: modelContainer,
            keychainService: keychainService
        )
        self.tabRepository = SwiftDataTabRepository(modelContainer: modelContainer)
        self.httpClient = URLSessionHTTPClient()
        self.envResolver = DefaultEnvResolver()
        let authService = PKCEAuthService(keychainService: keychainService)
        self.authService = authService
        self.authResolver = DefaultAuthResolver(authService: authService)
    }

    // MARK: - ViewModel Factories

    func makeRequestEditorViewModel(draft: RequestDraft, tab: Tab) -> RequestEditorViewModel {
        RequestEditorViewModel(
            draft: draft,
            tab: tab,
            tabRepository: tabRepository,
            requestRepository: requestRepository,
            responseRepository: responseRepository,
            collectionRepository: collectionRepository,
            httpClient: httpClient,
            envResolver: envResolver,
            authResolver: authResolver,
            authService: authService
        )
    }

    func makeCollectionTreeViewModel(workspaceId: UUID) -> CollectionTreeViewModel {
        CollectionTreeViewModel(
            workspaceId: workspaceId,
            collectionRepository: collectionRepository,
            requestRepository: requestRepository,
            tabRepository: tabRepository,
            authService: authService
        )
    }

    func makeTabBarViewModel() -> TabBarViewModel {
        TabBarViewModel(
            tabRepository: tabRepository,
            requestRepository: requestRepository
        )
    }

    func makeEnvironmentViewModel(workspaceId: UUID) -> EnvironmentViewModel {
        EnvironmentViewModel(workspaceId: workspaceId, environmentRepository: environmentRepository)
    }
}
