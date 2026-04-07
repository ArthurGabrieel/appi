// appi/Presentation/ViewModels/TabBarViewModel.swift
import Foundation

@Observable @MainActor
final class TabBarViewModel {
    var tabs: [Tab] = []
    var activeTabId: UUID?
    /// Monotonic counter incremented after reloadTabs() so ContentView can observe payload changes.
    var tabsVersion: Int = 0

    private let tabRepository: any TabRepository
    let requestRepository: any RequestRepository

    init(
        tabRepository: any TabRepository,
        requestRepository: any RequestRepository
    ) {
        self.tabRepository = tabRepository
        self.requestRepository = requestRepository
    }

    var activeTab: Tab? {
        tabs.first { $0.id == activeTabId }
    }

    func loadTabs() async {
        do {
            try await tabRepository.cleanupOrphanedLinks()
            tabs = try await tabRepository.fetchAll()
            activeTabId = tabs.first(where: { $0.isActive })?.id ?? tabs.first?.id
        } catch {}
    }

    func openRequest(_ request: Request) async {
        // If request already open in a tab, activate it
        if let existingTab = tabs.first(where: { $0.linkedRequestId == request.id }) {
            await activateTab(existingTab.id)
            return
        }

        // Create new tab with originalDraft snapshot for dirty tracking
        let draft = RequestDraft.from(request)
        let tab = Tab(
            id: UUID(),
            linkedRequestId: request.id,
            draft: draft,
            originalDraft: draft,
            sortIndex: tabs.count,
            isActive: true,
            createdAt: Date()
        )

        do {
            await deactivateAllTabs()
            try await tabRepository.save(tab)
            tabs.append(tab)
            activeTabId = tab.id
        } catch {}
    }

    func newTab(collectionId: UUID) async {
        let tab = Tab(
            id: UUID(),
            linkedRequestId: nil,
            draft: RequestDraft.empty(in: collectionId),
            originalDraft: nil,
            sortIndex: tabs.count,
            isActive: true,
            createdAt: Date()
        )

        do {
            await deactivateAllTabs()
            try await tabRepository.save(tab)
            tabs.append(tab)
            activeTabId = tab.id
        } catch {}
    }

    func activateTab(_ id: UUID) async {
        guard tabs.contains(where: { $0.id == id }) else { return }
        await deactivateAllTabs()

        if let index = tabs.firstIndex(where: { $0.id == id }) {
            tabs[index].isActive = true
            do { try await tabRepository.save(tabs[index]) } catch {}
        }
        activeTabId = id
    }

    /// Result of attempting to close a dirty tab linked to a saved request.
    enum CloseAction {
        case closed
        case needsConfirmation(Tab)
    }

    /// Attempts to close a tab. Returns `.needsConfirmation` if the tab is dirty
    /// and linked to a saved request (RN-07). The View must show a Save/Discard/Cancel
    /// alert and then call `forceCloseTab` or `saveAndCloseTab`.
    func closeTab(_ id: UUID) async -> CloseAction {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return .closed }
        let tab = tabs[index]

        // Dirty tab linked to a saved request → needs confirmation (RN-07)
        if tab.linkedRequestId != nil, isDirty(tab) {
            return .needsConfirmation(tab)
        }

        // Not dirty, or new draft (no linkedRequestId) → close silently
        await performClose(at: index)
        return .closed
    }

    /// Force-close a tab after user chose "Discard" in the confirmation alert.
    func forceCloseTab(_ id: UUID) async {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        await performClose(at: index)
    }

    /// Save the tab's draft as a request, then close it.
    func saveAndCloseTab(_ id: UUID, requestRepository: any RequestRepository) async {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs[index]
        do {
            if let existingId = tab.linkedRequestId {
                let request = tab.draft.toRequest(existingId: existingId)
                try await requestRepository.save(request)
            }
            await performClose(at: index)
        } catch {}
    }

    /// Delegates to Tab.isDirty — compares draft against originalDraft snapshot.
    func isDirty(_ tab: Tab) -> Bool {
        tab.isDirty
    }

    private func performClose(at index: Int) async {
        let tab = tabs[index]
        let id = tab.id

        do {
            try await tabRepository.delete(tab)
        } catch { return }

        tabs.remove(at: index)

        if activeTabId == id {
            if tabs.isEmpty {
                activeTabId = nil
            } else {
                let newIndex = min(index, tabs.count - 1)
                await activateTab(tabs[newIndex].id)
            }
        }
    }

    /// Reloads tabs from repository (e.g. after orphan cleanup by CollectionTreeViewModel)
    func reloadTabs() async {
        do {
            tabs = try await tabRepository.fetchAll()
            // Keep current active tab if still exists, else pick first
            if let activeTabId, !tabs.contains(where: { $0.id == activeTabId }) {
                self.activeTabId = tabs.first?.id
            }
            tabsVersion += 1
        } catch {}
    }

    private func deactivateAllTabs() async {
        for index in tabs.indices where tabs[index].isActive {
            tabs[index].isActive = false
            do { try await tabRepository.save(tabs[index]) } catch {}
        }
    }
}
