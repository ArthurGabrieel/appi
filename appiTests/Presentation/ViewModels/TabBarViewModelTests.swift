// appiTests/Presentation/ViewModels/TabBarViewModelTests.swift
import Testing
import Foundation
@testable import appi

@MainActor
struct TabBarViewModelTests {
    // NOTE: All Tab() constructors need `originalDraft:` parameter.
    // Use `originalDraft: nil` for new/empty tabs, `originalDraft: draft` for tabs opened from saved requests.

    func makeViewModel(
        tabRepository: MockTabRepository? = nil,
        requestRepository: MockRequestRepository? = nil
    ) -> TabBarViewModel {
        TabBarViewModel(
            tabRepository: tabRepository ?? MockTabRepository(),
            requestRepository: requestRepository ?? MockRequestRepository()
        )
    }

    @Test("loadTabs restores tabs and active tab from repository")
    func loadTabs() async throws {
        let tabRepo = MockTabRepository()
        let collectionId = UUID()
        let tab1 = Tab(
            id: UUID(), linkedRequestId: nil,
            draft: RequestDraft.empty(in: collectionId),
            originalDraft: nil,
            sortIndex: 0, isActive: false, createdAt: Date()
        )
        let tab2 = Tab(
            id: UUID(), linkedRequestId: nil,
            draft: RequestDraft.empty(in: collectionId),
            originalDraft: nil,
            sortIndex: 1, isActive: true, createdAt: Date()
        )
        tabRepo.tabs = [tab1, tab2]

        let vm = makeViewModel(tabRepository: tabRepo)
        await vm.loadTabs()

        #expect(vm.tabs.count == 2)
        #expect(vm.activeTabId == tab2.id)
        #expect(tabRepo.cleanupOrphanedLinksCalled)
    }

    @Test("openRequest activates existing tab if request already open")
    func openRequestActivatesExisting() async throws {
        let tabRepo = MockTabRepository()
        let requestId = UUID()
        let collectionId = UUID()
        var draft = RequestDraft.empty(in: collectionId)
        draft.name = "Login"
        let existingTab = Tab(
            id: UUID(), linkedRequestId: requestId,
            draft: draft, originalDraft: draft,
            sortIndex: 0, isActive: true, createdAt: Date()
        )
        tabRepo.tabs = [existingTab]

        let reqRepo = MockRequestRepository()
        let request = Request(
            id: requestId, name: "Login", method: .post,
            url: "/login", headers: [], body: .none,
            auth: .inheritFromParent, collectionId: collectionId,
            sortIndex: 0, createdAt: Date(), updatedAt: Date()
        )
        reqRepo.requests = [request]

        let vm = makeViewModel(tabRepository: tabRepo, requestRepository: reqRepo)
        await vm.loadTabs()

        await vm.openRequest(request)

        #expect(vm.tabs.count == 1)
        #expect(vm.activeTabId == existingTab.id)
    }

    @Test("openRequest creates new tab if request not already open")
    func openRequestCreatesNew() async throws {
        let tabRepo = MockTabRepository()
        let reqRepo = MockRequestRepository()
        let collectionId = UUID()
        let request = Request(
            id: UUID(), name: "Login", method: .post,
            url: "/login", headers: [], body: .none,
            auth: .inheritFromParent, collectionId: collectionId,
            sortIndex: 0, createdAt: Date(), updatedAt: Date()
        )
        reqRepo.requests = [request]

        let vm = makeViewModel(tabRepository: tabRepo, requestRepository: reqRepo)
        await vm.loadTabs()

        await vm.openRequest(request)

        #expect(vm.tabs.count == 1)
        #expect(vm.activeTabId == vm.tabs.first?.id)
        #expect(vm.tabs.first?.linkedRequestId == request.id)
        #expect(vm.tabs.first?.draft.name == "Login")
    }

    @Test("newTab creates empty tab and activates it")
    func newTab() async throws {
        let tabRepo = MockTabRepository()
        let vm = makeViewModel(tabRepository: tabRepo)

        await vm.newTab(collectionId: UUID())

        #expect(vm.tabs.count == 1)
        #expect(vm.activeTabId == vm.tabs.first?.id)
        #expect(vm.tabs.first?.linkedRequestId == nil)
    }

    @Test("closeTab on non-dirty tab removes it and activates adjacent")
    func closeTabNonDirty() async throws {
        let tabRepo = MockTabRepository()
        let collectionId = UUID()
        // Tabs without linkedRequestId are never dirty
        let tab1 = Tab(id: UUID(), linkedRequestId: nil, draft: RequestDraft.empty(in: collectionId), originalDraft: nil, sortIndex: 0, isActive: true, createdAt: Date())
        let tab2 = Tab(id: UUID(), linkedRequestId: nil, draft: RequestDraft.empty(in: collectionId), originalDraft: nil, sortIndex: 1, isActive: false, createdAt: Date())
        tabRepo.tabs = [tab1, tab2]

        let vm = makeViewModel(tabRepository: tabRepo)
        await vm.loadTabs()

        let result = await vm.closeTab(tab1.id)

        #expect(vm.tabs.count == 1)
        #expect(vm.activeTabId == tab2.id)
        if case .closed = result {} else { Issue.record("Expected .closed") }
    }

    @Test("closeTab on dirty tab linked to request returns needsConfirmation (RN-07)")
    func closeTabDirtyNeedsConfirmation() async throws {
        let tabRepo = MockTabRepository()
        let requestId = UUID()
        let collectionId = UUID()
        let originalDraft = RequestDraft.empty(in: collectionId)
        var modifiedDraft = originalDraft
        modifiedDraft.url = "https://modified.example.com"
        let tab = Tab(
            id: UUID(), linkedRequestId: requestId,
            draft: modifiedDraft, originalDraft: originalDraft,
            sortIndex: 0, isActive: true, createdAt: Date()
        )
        tabRepo.tabs = [tab]

        let vm = makeViewModel(tabRepository: tabRepo)
        await vm.loadTabs()

        let result = await vm.closeTab(tab.id)

        // Tab should NOT be removed yet — waiting for user decision
        #expect(vm.tabs.count == 1)
        if case .needsConfirmation(let t) = result {
            #expect(t.id == tab.id)
        } else {
            Issue.record("Expected .needsConfirmation")
        }
    }

    @Test("forceCloseTab removes tab after user chose Discard")
    func forceCloseTab() async throws {
        let tabRepo = MockTabRepository()
        let requestId = UUID()
        let tab = Tab(id: UUID(), linkedRequestId: requestId, draft: RequestDraft.empty(in: UUID()), originalDraft: nil, sortIndex: 0, isActive: true, createdAt: Date())
        tabRepo.tabs = [tab]

        let vm = makeViewModel(tabRepository: tabRepo)
        await vm.loadTabs()

        await vm.forceCloseTab(tab.id)

        #expect(vm.tabs.isEmpty)
        #expect(vm.activeTabId == nil)
    }

    @Test("closeTab last tab sets activeTabId to nil")
    func closeLastTab() async throws {
        let tabRepo = MockTabRepository()
        let tab = Tab(id: UUID(), linkedRequestId: nil, draft: RequestDraft.empty(in: UUID()), originalDraft: nil, sortIndex: 0, isActive: true, createdAt: Date())
        tabRepo.tabs = [tab]

        let vm = makeViewModel(tabRepository: tabRepo)
        await vm.loadTabs()

        let result = await vm.closeTab(tab.id)

        #expect(vm.tabs.isEmpty)
        #expect(vm.activeTabId == nil)
        if case .closed = result {} else { Issue.record("Expected .closed") }
    }
}
