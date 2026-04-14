import Foundation

@Observable @MainActor
final class RequestEditorViewModel {
    var draft: RequestDraft {
        didSet { syncDraftToTab() }
    }
    var tab: Tab
    var onDraftChanged: ((Tab) -> Void)?
    var response: Response?
    var error: (any LocalizedError)?
    var isLoading = false
    var effectiveAuth: AuthConfig?
    var isLoadingEffectiveAuth = false
    var authError: (any LocalizedError)?

    private var sendTask: Task<Void, Never>?
    private var activeSendID: UUID?

    private let tabRepository: any TabRepository
    private let requestRepository: any RequestRepository
    private let responseRepository: any ResponseRepository
    private let collectionRepository: any CollectionRepository
    private let httpClient: any HTTPClient
    private let envResolver: any EnvResolver
    private let authResolver: any AuthResolver
    private let authService: any AuthService

    init(
        draft: RequestDraft,
        tab: Tab,
        tabRepository: any TabRepository,
        requestRepository: any RequestRepository,
        responseRepository: any ResponseRepository,
        collectionRepository: any CollectionRepository,
        httpClient: any HTTPClient,
        envResolver: any EnvResolver,
        authResolver: any AuthResolver,
        authService: any AuthService
    ) {
        self.draft = draft
        self.tab = tab
        self.tabRepository = tabRepository
        self.requestRepository = requestRepository
        self.responseRepository = responseRepository
        self.collectionRepository = collectionRepository
        self.httpClient = httpClient
        self.envResolver = envResolver
        self.authResolver = authResolver
        self.authService = authService
    }

    @MainActor
    func send(environment: Environment?) async {
        let task = startSend(environment: environment)
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    @discardableResult
    @MainActor
    func startSend(environment: Environment?) -> Task<Void, Never> {
        sendTask?.cancel()

        let sendID = UUID()
        activeSendID = sendID
        isLoading = true
        error = nil
        authError = nil

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performSend(environment: environment, sendID: sendID)
        }
        sendTask = task
        return task
    }

    @MainActor
    func save() async throws {
        if let existingId = tab.linkedRequestId {
            let request = draft.toRequest(existingId: existingId)
            try await requestRepository.save(request)
        } else {
            let request = draft.toRequest()
            try await requestRepository.save(request)
            tab.linkedRequestId = request.id
        }
        tab.draft = draft
        tab.originalDraft = draft  // Reset baseline — tab is no longer dirty
        try await tabRepository.save(tab)
    }

    @MainActor
    func cancelRequest() {
        sendTask?.cancel()
        sendTask = nil
        activeSendID = nil
        isLoading = false
    }

    var isDirty: Bool {
        tab.isDirty
    }

    @MainActor
    func loadEffectiveAuth() async {
        guard case .inheritFromParent = draft.auth else {
            effectiveAuth = nil
            return
        }
        isLoadingEffectiveAuth = true
        defer { isLoadingEffectiveAuth = false }
        do {
            let chain = try await collectionRepository.ancestorChain(for: draft.collectionId)
            effectiveAuth = Self.firstConcreteAuth(in: chain)
        } catch {
            effectiveAuth = nil
        }
    }

    // Pure chain-walk — never touches Keychain or triggers token refresh.
    private static func firstConcreteAuth(in chain: [Collection]) -> AuthConfig {
        for collection in chain {
            if case .inheritFromParent = collection.auth { continue }
            return collection.auth
        }
        return .none
    }

    @MainActor
    func authorizeOAuth2(config: OAuth2Config) async -> Bool {
        do {
            authError = nil
            _ = try await authService.authorize(with: config)
            return true
        } catch {
            authError = error as? any LocalizedError
                ?? AuthError.invalidConfiguration(String(localized: "error.auth.unknown"))
            return false
        }
    }

    func unresolvedKeys(environment: Environment?) -> [String] {
        envResolver.unresolvedKeys(in: draft, environment: environment)
    }

    @MainActor
    private func performSend(environment: Environment?, sendID: UUID) async {
        defer { finishSendIfNeeded(sendID: sendID) }

        do {
            try Task.checkCancellation()

            // 1. Resolve variables
            let prepared = try envResolver.resolve(draft, using: environment)

            try Task.checkCancellation()

            // 2. Resolve auth chain
            let chain = try await collectionRepository.ancestorChain(for: draft.collectionId)
            try Task.checkCancellation()

            let resolvedAuth = try await authResolver.resolve(for: draft.auth, chain: chain)
            try Task.checkCancellation()

            // 3. Execute
            let resolved = prepared.withAuth(resolvedAuth)
            let result = try await httpClient.execute(resolved)
            try Task.checkCancellation()

            guard isActiveSend(sendID) else { return }

            response = result

            // 4. Save to history if linked to a saved request
            if let requestId = tab.linkedRequestId {
                try await responseRepository.save(result, forRequestId: requestId)
                try Task.checkCancellation()
            }
        } catch let requestError as RequestError {
            guard isActiveSend(sendID) else { return }
            error = requestError
        } catch is CancellationError {
            guard isActiveSend(sendID) else { return }
            error = RequestError.cancelled
        } catch let authError as AuthError {
            guard isActiveSend(sendID) else { return }
            self.authError = authError
        } catch let persistenceError as PersistenceError {
            guard isActiveSend(sendID) else { return }
            error = persistenceError
        } catch {
            guard isActiveSend(sendID) else { return }
            if let localizedError = error as? any LocalizedError {
                self.error = localizedError
            } else {
                self.error = RequestError.networkError(URLError(.unknown))
            }
        }
    }

    @MainActor
    private func finishSendIfNeeded(sendID: UUID) {
        guard activeSendID == sendID else { return }
        sendTask = nil
        activeSendID = nil
        isLoading = false
    }

    @MainActor
    private func isActiveSend(_ sendID: UUID) -> Bool {
        activeSendID == sendID
    }

    private func syncDraftToTab() {
        guard tab.draft != draft else { return }
        tab.draft = draft
        let snapshot = tab
        onDraftChanged?(snapshot)
        Task {
            try? await tabRepository.save(snapshot)
        }
    }
}
