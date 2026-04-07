import Foundation

@Observable
final class RequestEditorViewModel {
    var draft: RequestDraft
    var tab: Tab
    var response: Response?
    var error: (any LocalizedError)?
    var isLoading = false

    private let requestRepository: any RequestRepository
    private let responseRepository: any ResponseRepository
    private let collectionRepository: any CollectionRepository
    private let httpClient: any HTTPClient
    private let envResolver: any EnvResolver
    private let authResolver: any AuthResolver

    init(
        draft: RequestDraft,
        tab: Tab,
        requestRepository: any RequestRepository,
        responseRepository: any ResponseRepository,
        collectionRepository: any CollectionRepository,
        httpClient: any HTTPClient,
        envResolver: any EnvResolver,
        authResolver: any AuthResolver
    ) {
        self.draft = draft
        self.tab = tab
        self.requestRepository = requestRepository
        self.responseRepository = responseRepository
        self.collectionRepository = collectionRepository
        self.httpClient = httpClient
        self.envResolver = envResolver
        self.authResolver = authResolver
    }

    func send(environment: Environment?) async {
        isLoading = true
        error = nil

        do {
            // 1. Resolve variables
            let prepared = try envResolver.resolve(draft, using: environment)

            // 2. Resolve auth chain
            let chain = try await collectionRepository.ancestorChain(for: draft.collectionId)
            let resolvedAuth = try await authResolver.resolve(for: draft.auth, chain: chain)

            // 3. Execute
            let resolved = prepared.withAuth(resolvedAuth)
            let result = try await httpClient.execute(resolved)

            response = result
            isLoading = false

            // 4. Save to history if linked to a saved request
            if let requestId = tab.linkedRequestId {
                try await responseRepository.save(result, forRequestId: requestId)
            }
        } catch let requestError as RequestError {
            error = requestError
            isLoading = false
        } catch let authError as AuthError {
            error = authError
            isLoading = false
        } catch let persistenceError as PersistenceError {
            error = persistenceError
            isLoading = false
        } catch {
            self.error = RequestError.networkError(URLError(.unknown))
            isLoading = false
        }
    }

    func save() async throws {
        if let existingId = tab.linkedRequestId {
            let request = draft.toRequest(existingId: existingId)
            try await requestRepository.save(request)
        } else {
            let request = draft.toRequest()
            try await requestRepository.save(request)
            tab.linkedRequestId = request.id
        }
    }

    func cancelRequest() {
        httpClient.cancel()
        isLoading = false
    }

    var isDirty: Bool {
        // For now, always true if there's a linkedRequest
        // Will be enhanced with proper comparison in Sprint 2
        tab.linkedRequestId != nil
    }
}
