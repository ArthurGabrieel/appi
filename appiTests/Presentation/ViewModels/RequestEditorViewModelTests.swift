import Testing
import Foundation
@testable import appi

@MainActor
struct RequestEditorViewModelTests {
    func makeViewModel(
        tab: Tab? = nil,
        httpClient: any HTTPClient = MockHTTPClient(),
        envResolver: MockEnvResolver = MockEnvResolver(),
        authResolver: MockAuthResolver = MockAuthResolver(),
        requestRepository: MockRequestRepository = MockRequestRepository(),
        responseRepository: MockResponseRepository = MockResponseRepository(),
        collectionRepository: MockCollectionRepository = MockCollectionRepository()
    ) -> RequestEditorViewModel {
        let collectionId = UUID()
        let actualTab = tab ?? Tab(
            id: UUID(), linkedRequestId: nil,
            draft: RequestDraft.empty(in: collectionId),
            sortIndex: 0, isActive: true, createdAt: Date()
        )
        return RequestEditorViewModel(
            draft: actualTab.draft,
            tab: actualTab,
            requestRepository: requestRepository,
            responseRepository: responseRepository,
            collectionRepository: collectionRepository,
            httpClient: httpClient,
            envResolver: envResolver,
            authResolver: authResolver
        )
    }

    @Test("send() sets response on success")
    func sendSuccess() async {
        let url = URL(string: "https://api.example.com")!
        let expectedResponse = Response(
            id: UUID(), statusCode: 200, statusMessage: "OK",
            headers: [], body: Data(), contentType: nil,
            duration: 0.05, size: 0, createdAt: Date()
        )

        let httpClient = MockHTTPClient()
        httpClient.result = .success(expectedResponse)

        let envResolver = MockEnvResolver()
        envResolver.resolveResult = .success(PreparedRequest(method: .get, url: url, headers: [], body: .none))

        let authResolver = MockAuthResolver()
        authResolver.resolveResult = .success(.none)

        let vm = makeViewModel(httpClient: httpClient, envResolver: envResolver, authResolver: authResolver)
        await vm.send(environment: nil)

        #expect(vm.response?.statusCode == 200)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    @Test("send() sets error on invalid URL")
    func sendInvalidURL() async {
        let envResolver = MockEnvResolver()
        envResolver.resolveResult = .failure(RequestError.invalidURL(""))

        let vm = makeViewModel(envResolver: envResolver)
        await vm.send(environment: nil)

        #expect(vm.response == nil)
        #expect(vm.error != nil)
    }

    @Test("send() does not save history for unsaved draft")
    func sendNoHistoryForDraft() async {
        let url = URL(string: "https://api.example.com")!
        let response = Response(
            id: UUID(), statusCode: 200, statusMessage: "OK",
            headers: [], body: Data(), contentType: nil,
            duration: 0.05, size: 0, createdAt: Date()
        )

        let httpClient = MockHTTPClient()
        httpClient.result = .success(response)
        let envResolver = MockEnvResolver()
        envResolver.resolveResult = .success(PreparedRequest(method: .get, url: url, headers: [], body: .none))
        let authResolver = MockAuthResolver()
        authResolver.resolveResult = .success(.none)
        let responseRepo = MockResponseRepository()

        let vm = makeViewModel(httpClient: httpClient, envResolver: envResolver, authResolver: authResolver, responseRepository: responseRepo)
        await vm.send(environment: nil)

        #expect(responseRepo.saveCalled == false)
    }

    @Test("save() creates new request and sets linkedRequestId")
    func saveNewRequest() async throws {
        let requestRepo = MockRequestRepository()
        let vm = makeViewModel(requestRepository: requestRepo)

        try await vm.save()

        #expect(requestRepo.saveCalled)
        #expect(vm.tab.linkedRequestId != nil)
    }

    @Test("send() preserves persistence errors from repositories")
    func sendPersistenceError() async {
        let collectionRepo = MockCollectionRepository()
        collectionRepo.ancestorChainError = PersistenceError.fetchFailed(NSError(domain: "test", code: 1))
        let url = URL(string: "https://api.example.com")!
        let envResolver = MockEnvResolver()
        envResolver.resolveResult = .success(PreparedRequest(method: .get, url: url, headers: [], body: .none))

        let vm = makeViewModel(envResolver: envResolver, collectionRepository: collectionRepo)
        await vm.send(environment: nil)

        #expect(vm.response == nil)
        #expect(vm.error is PersistenceError)
    }

    @Test("cancelRequest() only cancels the send owned by that view model")
    func cancelRequestIsScopedToViewModel() async {
        let firstURL = URL(string: "https://api.example.com/first")!
        let secondURL = URL(string: "https://api.example.com/second")!

        let authResolver = MockAuthResolver()
        authResolver.resolveResult = .success(.none)
        let sharedHTTPClient = MockHTTPClient()
        sharedHTTPClient.executionDelayNanoseconds = 250_000_000
        sharedHTTPClient.result = .success(
            Response(
                id: UUID(),
                statusCode: 200,
                statusMessage: "OK",
                headers: [],
                body: Data("{}".utf8),
                contentType: "application/json",
                duration: 0.25,
                size: 2,
                createdAt: Date()
            )
        )

        let firstEnvResolver = MockEnvResolver()
        firstEnvResolver.resolveResult = .success(
            PreparedRequest(method: .get, url: firstURL, headers: [], body: .none)
        )
        let secondEnvResolver = MockEnvResolver()
        secondEnvResolver.resolveResult = .success(
            PreparedRequest(method: .get, url: secondURL, headers: [], body: .none)
        )

        let firstViewModel = makeViewModel(
            httpClient: sharedHTTPClient,
            envResolver: firstEnvResolver,
            authResolver: authResolver
        )
        let secondViewModel = makeViewModel(
            httpClient: sharedHTTPClient,
            envResolver: secondEnvResolver,
            authResolver: authResolver
        )

        let firstSend = firstViewModel.startSend(environment: nil)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let secondSend = secondViewModel.startSend(environment: nil)
        try? await Task.sleep(nanoseconds: 50_000_000)
        firstViewModel.cancelRequest()

        await firstSend.value
        await secondSend.value

        #expect(firstViewModel.response == nil)
        #expect(firstViewModel.error == nil)
        #expect(firstViewModel.isLoading == false)
        #expect(secondViewModel.response?.statusCode == 200)
        #expect(secondViewModel.error == nil)
    }
}
