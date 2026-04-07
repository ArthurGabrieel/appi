import Foundation

@Observable
final class RequestEditorViewModel {
    var draft: RequestDraft
    var tab: Tab
    var response: Response?
    var error: (any LocalizedError)?
    var isLoading = false

    private var sendTask: Task<Void, Never>?
    private var activeSendID: UUID?

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
    }

    @MainActor
    func cancelRequest() {
        sendTask?.cancel()
        sendTask = nil
        activeSendID = nil
        isLoading = false
    }

    var isDirty: Bool {
        // For now, always true if there's a linkedRequest
        // Will be enhanced with proper comparison in Sprint 2
        tab.linkedRequestId != nil
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
            error = authError
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
}
