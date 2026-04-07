# Sprint 2 — Organization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add sidebar collection tree, tab bar, drag-and-drop, search, and first launch flow to Appi.

**Architecture:** Vertical slices building on Sprint 1's data layer. Each slice adds a ViewModel + Views wired through DependencyContainer. Bootstrap resolves `workspaceId` once and passes it to factories. `CollectionTreeViewModel` owns sidebar CRUD and orphan cleanup via `TabRepository`. Each `RequestEditorViewModel` syncs its draft to the tab for persistence.

**Tech Stack:** SwiftUI, SwiftData, Swift Testing, Swift Concurrency

---

## File Structure

### New Files

| File | Responsibility |
|---|---|
| `appi/Presentation/ViewModels/CollectionTreeViewModel.swift` | Sidebar tree state, CRUD, drag-drop, search filtering, orphan cleanup |
| `appi/Presentation/ViewModels/TabBarViewModel.swift` | Tab lifecycle, open/close/activate, restoration |
| `appi/Presentation/Views/Sidebar/SidebarView.swift` | Container: search + tree + environment picker placeholder |
| `appi/Presentation/Views/Sidebar/CollectionTreeView.swift` | Recursive List with DisclosureGroup |
| `appi/Presentation/Views/Sidebar/CollectionRow.swift` | Collection disclosure group row |
| `appi/Presentation/Views/Sidebar/RequestRow.swift` | Request row with method badge |
| `appi/Presentation/Views/Tabs/TabBarView.swift` | Horizontal tab strip |
| `appi/Presentation/Views/Tabs/TabItemView.swift` | Single tab: name, method, dirty dot, close button |
| `appiTests/Mocks/MockWorkspaceRepository.swift` | Mock for WorkspaceRepository |
| `appiTests/Mocks/MockTabRepository.swift` | Mock for TabRepository |
| `appiTests/Presentation/ViewModels/CollectionTreeViewModelTests.swift` | Sidebar ViewModel tests |
| `appiTests/Presentation/ViewModels/TabBarViewModelTests.swift` | Tab bar ViewModel tests |

### Modified Files

| File | Changes |
|---|---|
| `appi/DI/DependencyContainer.swift` | Add factory methods for new ViewModels, pass `workspaceId` and `tabRepository` |
| `appi/App/ContentView.swift` | Replace stub with NavigationSplitView wiring sidebar + tabs + editor |
| `appi/App/AppiApp.swift` | Add `.task {}` for first launch bootstrap |
| `appi/Presentation/ViewModels/RequestEditorViewModel.swift` | Add `tabRepository`, `startSend`/`cancelRequest`, draft→tab sync |
| `appi/Presentation/Views/Common/EmptyStateView.swift` | Add `⌘N` shortcut hint text |
| `appiTests/Mocks/MockHTTPClient.swift` | Remove `cancel()` method |

---

## Task 1: Add Missing Mocks (WorkspaceRepository + TabRepository)

**Files:**
- Create: `appiTests/Mocks/MockWorkspaceRepository.swift`
- Create: `appiTests/Mocks/MockTabRepository.swift`

- [ ] **Step 1: Create MockWorkspaceRepository**

```swift
// appiTests/Mocks/MockWorkspaceRepository.swift
import Foundation
@testable import appi

final class MockWorkspaceRepository: WorkspaceRepository, @unchecked Sendable {
    var workspaces: [Workspace] = []
    var saveCalled = false

    func fetchAll() async throws -> [Workspace] {
        workspaces
    }

    func save(_ workspace: Workspace) async throws {
        saveCalled = true
        if let index = workspaces.firstIndex(where: { $0.id == workspace.id }) {
            workspaces[index] = workspace
        } else {
            workspaces.append(workspace)
        }
    }

    func delete(_ workspace: Workspace) async throws {
        workspaces.removeAll { $0.id == workspace.id }
    }
}
```

- [ ] **Step 2: Create MockTabRepository**

```swift
// appiTests/Mocks/MockTabRepository.swift
import Foundation
@testable import appi

final class MockTabRepository: TabRepository, @unchecked Sendable {
    var tabs: [Tab] = []
    var saveCalled = false
    var savedTab: Tab?
    var deleteCalled = false
    var cleanupOrphanedLinksCalled = false

    func fetchAll() async throws -> [Tab] {
        tabs.sorted { $0.sortIndex < $1.sortIndex }
    }

    func save(_ tab: Tab) async throws {
        saveCalled = true
        savedTab = tab
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs[index] = tab
        } else {
            tabs.append(tab)
        }
    }

    func delete(_ tab: Tab) async throws {
        deleteCalled = true
        tabs.removeAll { $0.id == tab.id }
    }

    func cleanupOrphanedLinks() async throws {
        cleanupOrphanedLinksCalled = true
    }
}
```

- [ ] **Step 3: Update MockHTTPClient — remove cancel()**

In `appiTests/Mocks/MockHTTPClient.swift`, remove the `func cancel() {}` method. The `HTTPClient` protocol no longer has `cancel()` — cancellation is via Task cancellation.

Also update `appi/Domain/Services/HTTPClient.swift` — remove `func cancel()` from the protocol:

```swift
protocol HTTPClient: Sendable {
    func execute(_ request: ResolvedRequest) async throws -> Response
}
```

And update `appi/Data/Services/URLSessionHTTPClient.swift` — remove the `cancel()` method. Cancellation is handled by the calling Task.

And update `appi/Presentation/ViewModels/RequestEditorViewModel.swift` — remove `cancelRequest()` and the direct `httpClient.cancel()` call. The new cancellation pattern will be added in a later task.

- [ ] **Step 4: Build to verify mocks compile**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add appiTests/Mocks/MockWorkspaceRepository.swift appiTests/Mocks/MockTabRepository.swift appiTests/Mocks/MockHTTPClient.swift appi/Domain/Services/HTTPClient.swift appi/Data/Services/URLSessionHTTPClient.swift appi/Presentation/ViewModels/RequestEditorViewModel.swift
git commit -m "test: add MockWorkspaceRepository and MockTabRepository, remove HTTPClient.cancel()"
```

---

## Task 2: First Launch Bootstrap

**Files:**
- Modify: `appi/App/AppiApp.swift`
- Modify: `appi/App/ContentView.swift`

- [ ] **Step 1: Write the failing test for bootstrap**

Create file `appiTests/App/FirstLaunchTests.swift`:

```swift
// appiTests/App/FirstLaunchTests.swift
import Testing
import Foundation
@testable import appi

@MainActor
struct FirstLaunchTests {
    @Test("bootstrapIfNeeded creates workspace, collection, and tab on empty DB")
    func bootstrapCreatesDefaults() async throws {
        let workspaceRepo = MockWorkspaceRepository()
        let collectionRepo = MockCollectionRepository()
        let tabRepo = MockTabRepository()

        await bootstrapIfNeeded(
            workspaceRepository: workspaceRepo,
            collectionRepository: collectionRepo,
            tabRepository: tabRepo
        )

        #expect(workspaceRepo.workspaces.count == 1)
        #expect(workspaceRepo.workspaces.first?.name == "My Workspace")

        #expect(collectionRepo.collections.count == 1)
        let collection = try #require(collectionRepo.collections.first)
        #expect(collection.name == "My Collection")
        #expect(collection.parentId == nil)
        #expect(collection.auth == .none)
        #expect(collection.workspaceId == workspaceRepo.workspaces.first?.id)

        #expect(tabRepo.tabs.count == 1)
        let tab = try #require(tabRepo.tabs.first)
        #expect(tab.isActive == true)
        #expect(tab.linkedRequestId == nil)
        #expect(tab.draft.collectionId == collection.id)
    }

    @Test("bootstrapIfNeeded is a no-op when workspace already exists")
    func bootstrapNoOpWhenExists() async throws {
        let workspaceRepo = MockWorkspaceRepository()
        workspaceRepo.workspaces = [
            Workspace(id: UUID(), name: "Existing", createdAt: Date())
        ]
        let collectionRepo = MockCollectionRepository()
        let tabRepo = MockTabRepository()

        await bootstrapIfNeeded(
            workspaceRepository: workspaceRepo,
            collectionRepository: collectionRepo,
            tabRepository: tabRepo
        )

        #expect(workspaceRepo.workspaces.count == 1)
        #expect(workspaceRepo.workspaces.first?.name == "Existing")
        #expect(collectionRepo.saveCalled == false)
        #expect(tabRepo.saveCalled == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' test 2>&1 | grep -E "(Test|error|FAIL|SUCCEED)"`
Expected: FAIL — `bootstrapIfNeeded` function not found

- [ ] **Step 3: Implement bootstrapIfNeeded as a free function in AppiApp.swift**

```swift
// Add to appi/App/AppiApp.swift, before the AppiApp struct

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
            sortIndex: 0, isActive: true, createdAt: Date()
        )
        try await tabRepository.save(tab)
    } catch {
        // First launch is best-effort — app still opens
    }
}
```

- [ ] **Step 4: Wire bootstrap into AppiApp body via .task**

Replace the current `AppiApp.body`:

```swift
var body: some Scene {
    WindowGroup {
        ContentView()
            .environment(container)
            .task {
                await bootstrapIfNeeded(
                    workspaceRepository: container.workspaceRepository,
                    collectionRepository: container.collectionRepository,
                    tabRepository: container.tabRepository
                )
            }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' test 2>&1 | grep -E "(Test|FAIL|SUCCEED)"`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add appi/App/AppiApp.swift appiTests/App/FirstLaunchTests.swift
git commit -m "feat: add first launch bootstrap — creates default workspace, collection, and tab"
```

---

## Task 3: CollectionTreeViewModel — Load & Display

**Files:**
- Create: `appi/Presentation/ViewModels/CollectionTreeViewModel.swift`
- Create: `appiTests/Presentation/ViewModels/CollectionTreeViewModelTests.swift`

- [ ] **Step 1: Write failing test for loading collections and requests**

```swift
// appiTests/Presentation/ViewModels/CollectionTreeViewModelTests.swift
import Testing
import Foundation
@testable import appi

@MainActor
struct CollectionTreeViewModelTests {
    let workspaceId = UUID()

    func makeViewModel(
        collectionRepository: MockCollectionRepository? = nil,
        requestRepository: MockRequestRepository? = nil,
        tabRepository: MockTabRepository? = nil
    ) -> CollectionTreeViewModel {
        let colRepo = collectionRepository ?? MockCollectionRepository()
        let reqRepo = requestRepository ?? MockRequestRepository()
        let tabRepo = tabRepository ?? MockTabRepository()
        return CollectionTreeViewModel(
            workspaceId: workspaceId,
            collectionRepository: colRepo,
            requestRepository: reqRepo,
            tabRepository: tabRepo
        )
    }

    @Test("loadTree fetches collections and requests for workspace")
    func loadTree() async throws {
        let colRepo = MockCollectionRepository()
        let collection = Collection(
            id: UUID(), name: "Auth API", parentId: nil,
            sortIndex: 0, workspaceId: workspaceId, auth: .none,
            createdAt: Date(), updatedAt: Date()
        )
        colRepo.collections = [collection]

        let reqRepo = MockRequestRepository()
        let request = Request(
            id: UUID(), name: "Login", method: .post,
            url: "{{baseUrl}}/login", headers: [], body: .none,
            auth: .inheritFromParent, collectionId: collection.id,
            sortIndex: 0, createdAt: Date(), updatedAt: Date()
        )
        reqRepo.requests = [request]

        let vm = makeViewModel(collectionRepository: colRepo, requestRepository: reqRepo)
        await vm.loadTree()

        #expect(vm.collections.count == 1)
        #expect(vm.collections.first?.name == "Auth API")
        #expect(vm.requests.count == 1)
        #expect(vm.requests.first?.name == "Login")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' test 2>&1 | grep -E "(error|FAIL|SUCCEED)"`
Expected: FAIL — `CollectionTreeViewModel` not found

- [ ] **Step 3: Implement CollectionTreeViewModel with loadTree**

```swift
// appi/Presentation/ViewModels/CollectionTreeViewModel.swift
import Foundation

enum SidebarItem: Identifiable, Equatable {
    case collection(Collection)
    case request(Request)

    var id: UUID {
        switch self {
        case .collection(let c): c.id
        case .request(let r): r.id
        }
    }

    var sortIndex: Int {
        switch self {
        case .collection(let c): c.sortIndex
        case .request(let r): r.sortIndex
        }
    }

    var name: String {
        switch self {
        case .collection(let c): c.name
        case .request(let r): r.name
        }
    }
}

@Observable @MainActor
final class CollectionTreeViewModel {
    var collections: [Collection] = []
    var requests: [Request] = []
    var selectedItemId: UUID?
    var searchQuery: String = ""

    var onRequestSelected: ((Request) -> Void)?

    let workspaceId: UUID
    private let collectionRepository: any CollectionRepository
    private let requestRepository: any RequestRepository
    private let tabRepository: any TabRepository

    init(
        workspaceId: UUID,
        collectionRepository: any CollectionRepository,
        requestRepository: any RequestRepository,
        tabRepository: any TabRepository
    ) {
        self.workspaceId = workspaceId
        self.collectionRepository = collectionRepository
        self.requestRepository = requestRepository
        self.tabRepository = tabRepository
    }

    func loadTree() async {
        do {
            collections = try await collectionRepository.fetchAll(in: workspaceId)

            var allRequests: [Request] = []
            for collection in collections {
                let reqs = try await requestRepository.fetchAll(in: collection.id)
                allRequests.append(contentsOf: reqs)
            }
            requests = allRequests
        } catch {
            // Loading failure — UI shows empty sidebar
        }
    }

    /// Returns sidebar items (collections + requests) for a given parent collection ID.
    /// Pass nil for root-level items.
    func children(of parentId: UUID?) -> [SidebarItem] {
        let childCollections = collections
            .filter { $0.parentId == parentId }
            .map { SidebarItem.collection($0) }

        let childRequests: [SidebarItem]
        if let parentId {
            childRequests = requests
                .filter { $0.collectionId == parentId }
                .map { SidebarItem.request($0) }
        } else {
            childRequests = []
        }

        return (childCollections + childRequests).sorted { $0.sortIndex < $1.sortIndex }
    }

    func selectItem(_ id: UUID) {
        selectedItemId = id
        if let request = requests.first(where: { $0.id == id }) {
            onRequestSelected?(request)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' test 2>&1 | grep -E "(Test|FAIL|SUCCEED)"`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add appi/Presentation/ViewModels/CollectionTreeViewModel.swift appiTests/Presentation/ViewModels/CollectionTreeViewModelTests.swift
git commit -m "feat: add CollectionTreeViewModel with loadTree and children(of:)"
```

---

## Task 4: CollectionTreeViewModel — CRUD Operations

**Files:**
- Modify: `appi/Presentation/ViewModels/CollectionTreeViewModel.swift`
- Modify: `appiTests/Presentation/ViewModels/CollectionTreeViewModelTests.swift`

- [ ] **Step 1: Write failing tests for create, rename, delete**

Append to `CollectionTreeViewModelTests`:

```swift
@Test("createCollection adds a new root collection")
func createCollection() async throws {
    let colRepo = MockCollectionRepository()
    let vm = makeViewModel(collectionRepository: colRepo)
    await vm.loadTree()

    await vm.createCollection(name: "Users API", parentId: nil)

    #expect(colRepo.saveCalled)
    #expect(vm.collections.count == 1)
    #expect(vm.collections.first?.name == "Users API")
    #expect(vm.collections.first?.auth == .none)
}

@Test("createSubCollection sets parentId and auth to inheritFromParent")
func createSubCollection() async throws {
    let colRepo = MockCollectionRepository()
    let parentCollection = Collection(
        id: UUID(), name: "Parent", parentId: nil,
        sortIndex: 0, workspaceId: workspaceId, auth: .none,
        createdAt: Date(), updatedAt: Date()
    )
    colRepo.collections = [parentCollection]

    let vm = makeViewModel(collectionRepository: colRepo)
    await vm.loadTree()

    await vm.createCollection(name: "Child", parentId: parentCollection.id)

    let child = vm.collections.first { $0.name == "Child" }
    #expect(child?.parentId == parentCollection.id)
    #expect(child?.auth == .inheritFromParent)
}

@Test("createRequest adds request in collection and reloads")
func createRequest() async throws {
    let colRepo = MockCollectionRepository()
    let collection = Collection(
        id: UUID(), name: "API", parentId: nil,
        sortIndex: 0, workspaceId: workspaceId, auth: .none,
        createdAt: Date(), updatedAt: Date()
    )
    colRepo.collections = [collection]
    let reqRepo = MockRequestRepository()

    let vm = makeViewModel(collectionRepository: colRepo, requestRepository: reqRepo)
    await vm.loadTree()

    await vm.createRequest(in: collection.id)

    #expect(reqRepo.saveCalled)
    #expect(vm.requests.count == 1)
    #expect(vm.requests.first?.name == "New Request")
    #expect(vm.requests.first?.collectionId == collection.id)
}

@Test("renameCollection updates name")
func renameCollection() async throws {
    let colRepo = MockCollectionRepository()
    let collection = Collection(
        id: UUID(), name: "Old Name", parentId: nil,
        sortIndex: 0, workspaceId: workspaceId, auth: .none,
        createdAt: Date(), updatedAt: Date()
    )
    colRepo.collections = [collection]

    let vm = makeViewModel(collectionRepository: colRepo)
    await vm.loadTree()

    await vm.renameCollection(collection.id, to: "New Name")

    #expect(vm.collections.first?.name == "New Name")
}

@Test("deleteCollection removes collection and reloads")
func deleteCollection() async throws {
    let colRepo = MockCollectionRepository()
    let collection = Collection(
        id: UUID(), name: "Doomed", parentId: nil,
        sortIndex: 0, workspaceId: workspaceId, auth: .none,
        createdAt: Date(), updatedAt: Date()
    )
    colRepo.collections = [collection]

    let vm = makeViewModel(collectionRepository: colRepo)
    await vm.loadTree()

    await vm.deleteCollection(collection)

    #expect(vm.collections.isEmpty)
}

@Test("deleteRequest removes request and reloads")
func deleteRequest() async throws {
    let colRepo = MockCollectionRepository()
    let collection = Collection(
        id: UUID(), name: "API", parentId: nil,
        sortIndex: 0, workspaceId: workspaceId, auth: .none,
        createdAt: Date(), updatedAt: Date()
    )
    colRepo.collections = [collection]

    let reqRepo = MockRequestRepository()
    let request = Request(
        id: UUID(), name: "Login", method: .post,
        url: "/login", headers: [], body: .none,
        auth: .inheritFromParent, collectionId: collection.id,
        sortIndex: 0, createdAt: Date(), updatedAt: Date()
    )
    reqRepo.requests = [request]

    let vm = makeViewModel(collectionRepository: colRepo, requestRepository: reqRepo)
    await vm.loadTree()

    await vm.deleteRequest(request)

    #expect(vm.requests.isEmpty)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' test 2>&1 | grep -E "(error|FAIL|SUCCEED)"`
Expected: FAIL — methods not found

- [ ] **Step 3: Implement CRUD methods on CollectionTreeViewModel**

Add to `CollectionTreeViewModel`:

```swift
func createCollection(name: String, parentId: UUID?) async {
    guard let workspaceId else { return }
    let auth: AuthConfig = parentId == nil ? .none : .inheritFromParent
    let collection = Collection(
        id: UUID(), name: name, parentId: parentId,
        sortIndex: collections.filter({ $0.parentId == parentId }).count,
        workspaceId: workspaceId, auth: auth,
        createdAt: Date(), updatedAt: Date()
    )
    do {
        try await collectionRepository.save(collection)
        await loadTree()
    } catch {}
}

func createRequest(in collectionId: UUID) async {
    let sortIndex = requests.filter { $0.collectionId == collectionId }.count
    let request = Request(
        id: UUID(), name: "New Request", method: .get,
        url: "", headers: [], body: .none,
        auth: .inheritFromParent, collectionId: collectionId,
        sortIndex: sortIndex, createdAt: Date(), updatedAt: Date()
    )
    do {
        try await requestRepository.save(request)
        await loadTree()
    } catch {}
}

func renameCollection(_ id: UUID, to newName: String) async {
    guard var collection = collections.first(where: { $0.id == id }) else { return }
    collection.name = newName
    collection.updatedAt = Date()
    do {
        try await collectionRepository.save(collection)
        await loadTree()
    } catch {}
}

func renameRequest(_ id: UUID, to newName: String) async {
    guard var request = requests.first(where: { $0.id == id }) else { return }
    request.name = newName
    request.updatedAt = Date()
    do {
        try await requestRepository.save(request)
        await loadTree()
    } catch {}
}

func deleteCollection(_ collection: Collection) async {
    do {
        try await collectionRepository.delete(collection)
        try await tabRepository.cleanupOrphanedLinks()
        await loadTree()
    } catch {}
}

func deleteRequest(_ request: Request) async {
    do {
        try await requestRepository.delete(request)
        try await tabRepository.cleanupOrphanedLinks()
        await loadTree()
    } catch {}
}

func duplicateRequest(_ request: Request) async {
    do {
        _ = try await requestRepository.duplicate(request)
        await loadTree()
    } catch {}
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' test 2>&1 | grep -E "(Test|FAIL|SUCCEED)"`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add appi/Presentation/ViewModels/CollectionTreeViewModel.swift appiTests/Presentation/ViewModels/CollectionTreeViewModelTests.swift
git commit -m "feat: add CRUD operations to CollectionTreeViewModel"
```

---

## Task 5: Sidebar Views

**Files:**
- Create: `appi/Presentation/Views/Sidebar/SidebarView.swift`
- Create: `appi/Presentation/Views/Sidebar/CollectionTreeView.swift`
- Create: `appi/Presentation/Views/Sidebar/CollectionRow.swift`
- Create: `appi/Presentation/Views/Sidebar/RequestRow.swift`

- [ ] **Step 1: Create RequestRow**

```swift
// appi/Presentation/Views/Sidebar/RequestRow.swift
import SwiftUI

struct RequestRow: View {
    let request: Request

    var body: some View {
        HStack(spacing: 6) {
            Text(request.method.rawValue)
                .font(.caption.monospaced().bold())
                .foregroundStyle(color(for: request.method))
                .frame(width: 50, alignment: .leading)

            Text(request.name)
                .lineLimit(1)
        }
        .accessibilityLabel(String(localized: "sidebar.request.label \(request.method.rawValue) \(request.name)"))
    }

    private func color(for method: HTTPMethod) -> Color {
        switch method {
        case .get: .green
        case .post: .orange
        case .put: .blue
        case .patch: .purple
        case .delete: .red
        case .head: .gray
        case .options: .gray
        }
    }
}
```

- [ ] **Step 2: Create CollectionRow**

```swift
// appi/Presentation/Views/Sidebar/CollectionRow.swift
import SwiftUI

struct CollectionRow: View {
    let collection: Collection
    @Binding var isExpanded: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isExpanded ? "folder.fill" : "folder")
                .foregroundStyle(.secondary)
            Text(collection.name)
                .lineLimit(1)
        }
        .accessibilityLabel(String(localized: "sidebar.collection.label \(collection.name)"))
    }
}
```

- [ ] **Step 3: Create CollectionTreeView**

```swift
// appi/Presentation/Views/Sidebar/CollectionTreeView.swift
import SwiftUI

struct CollectionTreeView: View {
    @Bindable var viewModel: CollectionTreeViewModel

    var body: some View {
        List(selection: $viewModel.selectedItemId) {
            ForEach(viewModel.children(of: nil)) { item in
                sidebarItemView(item)
            }
        }
        .onChange(of: viewModel.selectedItemId) { _, newValue in
            if let id = newValue {
                viewModel.selectItem(id)
            }
        }
    }

    @ViewBuilder
    private func sidebarItemView(_ item: SidebarItem) -> some View {
        switch item {
        case .collection(let collection):
            collectionDisclosure(collection)
        case .request(let request):
            RequestRow(request: request)
                .tag(request.id)
                .contextMenu { requestContextMenu(request) }
        }
    }

    @State private var expandedCollections: Set<UUID> = []

    private func collectionDisclosure(_ collection: Collection) -> some View {
        DisclosureGroup(isExpanded: Binding(
            get: { expandedCollections.contains(collection.id) },
            set: { isExpanded in
                if isExpanded {
                    expandedCollections.insert(collection.id)
                } else {
                    expandedCollections.remove(collection.id)
                }
            }
        )) {
            ForEach(viewModel.children(of: collection.id)) { child in
                sidebarItemView(child)
            }
        } label: {
            CollectionRow(
                collection: collection,
                isExpanded: .constant(expandedCollections.contains(collection.id))
            )
            .tag(collection.id)
            .contextMenu { collectionContextMenu(collection) }
        }
    }

    @ViewBuilder
    private func collectionContextMenu(_ collection: Collection) -> some View {
        Button(String(localized: "sidebar.menu.newRequest")) {
            Task { await viewModel.createRequest(in: collection.id) }
        }
        Button(String(localized: "sidebar.menu.newSubcollection")) {
            Task { await viewModel.createCollection(name: "New Collection", parentId: collection.id) }
        }
        Divider()
        Button(String(localized: "sidebar.menu.delete"), role: .destructive) {
            Task { await viewModel.deleteCollection(collection) }
        }
    }

    @ViewBuilder
    private func requestContextMenu(_ request: Request) -> some View {
        Button(String(localized: "sidebar.menu.duplicate")) {
            Task { await viewModel.duplicateRequest(request) }
        }
        Divider()
        Button(String(localized: "sidebar.menu.delete"), role: .destructive) {
            Task { await viewModel.deleteRequest(request) }
        }
    }
}
```

- [ ] **Step 4: Create SidebarView**

```swift
// appi/Presentation/Views/Sidebar/SidebarView.swift
import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: CollectionTreeViewModel

    var body: some View {
        VStack(spacing: 0) {
            CollectionTreeView(viewModel: viewModel)
                .searchable(text: $viewModel.searchQuery, prompt: String(localized: "sidebar.search.prompt"))

            Divider()

            // Environment picker placeholder — Sprint 3
            HStack {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
                Text(String(localized: "sidebar.noEnvironment"))
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .accessibilityLabel(String(localized: "sidebar.label"))
    }
}
```

- [ ] **Step 5: Build to verify Views compile**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add appi/Presentation/Views/Sidebar/
git commit -m "feat: add sidebar views — SidebarView, CollectionTreeView, CollectionRow, RequestRow"
```

---

## Task 6: TabBarViewModel

**Files:**
- Create: `appi/Presentation/ViewModels/TabBarViewModel.swift`
- Create: `appiTests/Presentation/ViewModels/TabBarViewModelTests.swift`

- [ ] **Step 1: Write failing tests for tab lifecycle**

```swift
// appiTests/Presentation/ViewModels/TabBarViewModelTests.swift
import Testing
import Foundation
@testable import appi

@MainActor
struct TabBarViewModelTests {
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
            sortIndex: 0, isActive: false, createdAt: Date()
        )
        let tab2 = Tab(
            id: UUID(), linkedRequestId: nil,
            draft: RequestDraft.empty(in: collectionId),
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
            draft: draft, sortIndex: 0, isActive: true, createdAt: Date()
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

    @Test("closeTab removes tab and activates adjacent")
    func closeTab() async throws {
        let tabRepo = MockTabRepository()
        let collectionId = UUID()
        let tab1 = Tab(id: UUID(), linkedRequestId: nil, draft: RequestDraft.empty(in: collectionId), sortIndex: 0, isActive: true, createdAt: Date())
        let tab2 = Tab(id: UUID(), linkedRequestId: nil, draft: RequestDraft.empty(in: collectionId), sortIndex: 1, isActive: false, createdAt: Date())
        tabRepo.tabs = [tab1, tab2]

        let vm = makeViewModel(tabRepository: tabRepo)
        await vm.loadTabs()

        await vm.closeTab(tab1.id)

        #expect(vm.tabs.count == 1)
        #expect(vm.activeTabId == tab2.id)
    }

    @Test("closeTab last tab sets activeTabId to nil")
    func closeLastTab() async throws {
        let tabRepo = MockTabRepository()
        let tab = Tab(id: UUID(), linkedRequestId: nil, draft: RequestDraft.empty(in: UUID()), sortIndex: 0, isActive: true, createdAt: Date())
        tabRepo.tabs = [tab]

        let vm = makeViewModel(tabRepository: tabRepo)
        await vm.loadTabs()

        await vm.closeTab(tab.id)

        #expect(vm.tabs.isEmpty)
        #expect(vm.activeTabId == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' test 2>&1 | grep -E "(error|FAIL|SUCCEED)"`
Expected: FAIL — `TabBarViewModel` not found

- [ ] **Step 3: Implement TabBarViewModel**

```swift
// appi/Presentation/ViewModels/TabBarViewModel.swift
import Foundation

@Observable @MainActor
final class TabBarViewModel {
    var tabs: [Tab] = []
    var activeTabId: UUID?

    private let tabRepository: any TabRepository
    private let requestRepository: any RequestRepository

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

        // Create new tab
        let tab = Tab(
            id: UUID(),
            linkedRequestId: request.id,
            draft: RequestDraft.from(request),
            sortIndex: tabs.count,
            isActive: true,
            createdAt: Date()
        )

        do {
            // Deactivate current
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

    func closeTab(_ id: UUID) async {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs[index]

        do {
            try await tabRepository.delete(tab)
        } catch { return }

        tabs.remove(at: index)

        if activeTabId == id {
            // Activate adjacent tab
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
        } catch {}
    }

    private func deactivateAllTabs() async {
        for index in tabs.indices where tabs[index].isActive {
            tabs[index].isActive = false
            do { try await tabRepository.save(tabs[index]) } catch {}
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' test 2>&1 | grep -E "(Test|FAIL|SUCCEED)"`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add appi/Presentation/ViewModels/TabBarViewModel.swift appiTests/Presentation/ViewModels/TabBarViewModelTests.swift
git commit -m "feat: add TabBarViewModel with open, close, activate, restore"
```

---

## Task 7: Tab Bar Views

**Files:**
- Create: `appi/Presentation/Views/Tabs/TabBarView.swift`
- Create: `appi/Presentation/Views/Tabs/TabItemView.swift`

- [ ] **Step 1: Create TabItemView**

```swift
// appi/Presentation/Views/Tabs/TabItemView.swift
import SwiftUI

struct TabItemView: View {
    let tab: Tab
    let isActive: Bool
    let onActivate: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tab.draft.method.rawValue)
                .font(.caption2.monospaced().bold())
                .foregroundStyle(.secondary)

            Text(tab.draft.name)
                .lineLimit(1)
                .font(.caption)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "tabs.close"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture { onActivate() }
        .accessibilityLabel(String(localized: "tabs.item.label \(tab.draft.method.rawValue) \(tab.draft.name)"))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
```

- [ ] **Step 2: Create TabBarView**

```swift
// appi/Presentation/Views/Tabs/TabBarView.swift
import SwiftUI

struct TabBarView: View {
    @Bindable var viewModel: TabBarViewModel
    let defaultCollectionId: UUID?

    var body: some View {
        HStack(spacing: 2) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(viewModel.tabs) { tab in
                        TabItemView(
                            tab: tab,
                            isActive: tab.id == viewModel.activeTabId,
                            onActivate: {
                                Task { await viewModel.activateTab(tab.id) }
                            },
                            onClose: {
                                Task { await viewModel.closeTab(tab.id) }
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }

            Button {
                Task {
                    if let collectionId = defaultCollectionId {
                        await viewModel.newTab(collectionId: collectionId)
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            .accessibilityLabel(String(localized: "tabs.new"))
            .keyboardShortcut("t", modifiers: .command)
        }
        .frame(height: 32)
        .background(.bar)
    }
}
```

- [ ] **Step 3: Build to verify Views compile**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add appi/Presentation/Views/Tabs/
git commit -m "feat: add TabBarView and TabItemView"
```

---

## Task 8: Wire Everything in ContentView + DependencyContainer

**Files:**
- Modify: `appi/DI/DependencyContainer.swift`
- Modify: `appi/App/ContentView.swift`

- [ ] **Step 1: Add factories to DependencyContainer**

Add these factory methods after `makeRequestEditorViewModel`:

Also update `makeRequestEditorViewModel` to include `tabRepository`:

```swift
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
        authResolver: authResolver
    )
}

func makeCollectionTreeViewModel(workspaceId: UUID) -> CollectionTreeViewModel {
    CollectionTreeViewModel(
        workspaceId: workspaceId,
        collectionRepository: collectionRepository,
        requestRepository: requestRepository,
        tabRepository: tabRepository
    )
}

func makeTabBarViewModel() -> TabBarViewModel {
    TabBarViewModel(
        tabRepository: tabRepository,
        requestRepository: requestRepository
    )
}
```

- [ ] **Step 2: Rewrite ContentView with NavigationSplitView**

Replace the entire `ContentView.swift`:

```swift
// appi/App/ContentView.swift
import SwiftUI

struct ContentView: View {
    @SwiftUI.Environment(DependencyContainer.self) private var container

    @State private var collectionTreeViewModel: CollectionTreeViewModel?
    @State private var tabBarViewModel: TabBarViewModel?
    @State private var editorViewModel: RequestEditorViewModel?
    @State private var currentWorkspaceId: UUID?
    @State private var isLoaded = false

    var body: some View {
        NavigationSplitView {
            if let collectionTreeViewModel {
                SidebarView(viewModel: collectionTreeViewModel)
            }
        } detail: {
            VStack(spacing: 0) {
                if let tabBarViewModel {
                    TabBarView(
                        viewModel: tabBarViewModel,
                        defaultCollectionId: collectionTreeViewModel?.collections.first?.id
                    )
                    Divider()
                }

                if let editorViewModel {
                    RequestEditorView(viewModel: editorViewModel, activeEnvironment: nil)
                } else {
                    EmptyStateView {
                        Task {
                            if let collectionId = collectionTreeViewModel?.collections.first?.id {
                                await tabBarViewModel?.newTab(collectionId: collectionId)
                            }
                        }
                    }
                }
            }
        }
        .task {
            guard !isLoaded else { return }
            isLoaded = true

            // Resolve workspaceId once
            guard let workspace = try? await container.workspaceRepository.fetchAll().first else { return }
            currentWorkspaceId = workspace.id

            let treeVM = container.makeCollectionTreeViewModel(workspaceId: workspace.id)
            let tabVM = container.makeTabBarViewModel()

            // Wire sidebar → tabs
            treeVM.onRequestSelected = { request in
                Task { await tabVM.openRequest(request) }
            }

            collectionTreeViewModel = treeVM
            tabBarViewModel = tabVM

            await treeVM.loadTree()
            await tabVM.loadTabs()

            updateEditor()
        }
        .onChange(of: tabBarViewModel?.activeTabId) { _, _ in
            updateEditor()
        }
    }

    private func updateEditor() {
        guard let tabBarViewModel, let activeTab = tabBarViewModel.activeTab else {
            editorViewModel = nil
            return
        }
        editorViewModel = container.makeRequestEditorViewModel(draft: activeTab.draft, tab: activeTab)
    }
}
```

- [ ] **Step 3: Build and run to verify wiring works**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run all tests to verify nothing broke**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' test 2>&1 | grep -E "(Test|FAIL|SUCCEED)"`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add appi/DI/DependencyContainer.swift appi/App/ContentView.swift
git commit -m "feat: wire sidebar, tabs, and editor via NavigationSplitView in ContentView"
```

---

## Task 9: Drag-and-Drop

**Files:**
- Modify: `appi/Presentation/ViewModels/CollectionTreeViewModel.swift`
- Modify: `appi/Presentation/Views/Sidebar/CollectionTreeView.swift`
- Modify: `appiTests/Presentation/ViewModels/CollectionTreeViewModelTests.swift`

- [ ] **Step 1: Write failing tests for move operations**

Append to `CollectionTreeViewModelTests`:

```swift
@Test("moveRequest updates collectionId and sortIndex")
func moveRequest() async throws {
    let colRepo = MockCollectionRepository()
    let col1 = Collection(id: UUID(), name: "A", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
    let col2 = Collection(id: UUID(), name: "B", parentId: nil, sortIndex: 1, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
    colRepo.collections = [col1, col2]

    let reqRepo = MockRequestRepository()
    let request = Request(id: UUID(), name: "Login", method: .post, url: "/login", headers: [], body: .none, auth: .inheritFromParent, collectionId: col1.id, sortIndex: 0, createdAt: Date(), updatedAt: Date())
    reqRepo.requests = [request]

    let vm = makeViewModel(collectionRepository: colRepo, requestRepository: reqRepo)
    await vm.loadTree()

    await vm.moveRequest(request.id, toCollection: col2.id, atIndex: 0)

    let moved = vm.requests.first { $0.id == request.id }
    #expect(moved?.collectionId == col2.id)
    #expect(moved?.sortIndex == 0)
}

@Test("moveCollection updates parentId")
func moveCollection() async throws {
    let colRepo = MockCollectionRepository()
    let parent = Collection(id: UUID(), name: "Parent", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
    let child = Collection(id: UUID(), name: "Child", parentId: nil, sortIndex: 1, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
    colRepo.collections = [parent, child]

    let vm = makeViewModel(collectionRepository: colRepo)
    await vm.loadTree()

    await vm.moveCollection(child.id, toParent: parent.id, atIndex: 0)

    let moved = vm.collections.first { $0.id == child.id }
    #expect(moved?.parentId == parent.id)
}

@Test("canDropCollection rejects cycle — cannot drop into own descendant")
func canDropCollectionRejectsCycle() async throws {
    let colRepo = MockCollectionRepository()
    let parent = Collection(id: UUID(), name: "Parent", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
    let child = Collection(id: UUID(), name: "Child", parentId: parent.id, sortIndex: 0, workspaceId: workspaceId, auth: .inheritFromParent, createdAt: Date(), updatedAt: Date())
    colRepo.collections = [parent, child]

    let vm = makeViewModel(collectionRepository: colRepo)
    await vm.loadTree()

    let canDrop = vm.canDropCollection(parent.id, intoParent: child.id)
    #expect(canDrop == false)
}

@Test("canDropCollection rejects exceeding 5-level depth limit")
func canDropCollectionRejectsDepth() async throws {
    let colRepo = MockCollectionRepository()
    // Build chain: root → l1 → l2 → l3 → l4 (4 levels deep)
    let root = Collection(id: UUID(), name: "Root", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
    let l1 = Collection(id: UUID(), name: "L1", parentId: root.id, sortIndex: 0, workspaceId: workspaceId, auth: .inheritFromParent, createdAt: Date(), updatedAt: Date())
    let l2 = Collection(id: UUID(), name: "L2", parentId: l1.id, sortIndex: 0, workspaceId: workspaceId, auth: .inheritFromParent, createdAt: Date(), updatedAt: Date())
    let l3 = Collection(id: UUID(), name: "L3", parentId: l2.id, sortIndex: 0, workspaceId: workspaceId, auth: .inheritFromParent, createdAt: Date(), updatedAt: Date())
    let l4 = Collection(id: UUID(), name: "L4", parentId: l3.id, sortIndex: 0, workspaceId: workspaceId, auth: .inheritFromParent, createdAt: Date(), updatedAt: Date())
    colRepo.collections = [root, l1, l2, l3, l4]

    // Another standalone collection to try moving under l4
    let standalone = Collection(id: UUID(), name: "Standalone", parentId: nil, sortIndex: 1, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
    colRepo.collections.append(standalone)

    let vm = makeViewModel(collectionRepository: colRepo)
    await vm.loadTree()

    // l4 is level 5 — dropping standalone under l4 would make level 6
    let canDrop = vm.canDropCollection(standalone.id, intoParent: l4.id)
    #expect(canDrop == false)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' test 2>&1 | grep -E "(error|FAIL|SUCCEED)"`
Expected: FAIL — methods not found

- [ ] **Step 3: Implement drag-and-drop methods on CollectionTreeViewModel**

Add to `CollectionTreeViewModel`:

```swift
func moveRequest(_ requestId: UUID, toCollection collectionId: UUID, atIndex: Int) async {
    guard var request = requests.first(where: { $0.id == requestId }) else { return }
    request.collectionId = collectionId
    request.sortIndex = atIndex
    request.updatedAt = Date()
    do {
        try await requestRepository.save(request)
        await loadTree()
    } catch {}
}

func moveCollection(_ collectionId: UUID, toParent parentId: UUID?, atIndex: Int) async {
    guard var collection = collections.first(where: { $0.id == collectionId }) else { return }
    guard canDropCollection(collectionId, intoParent: parentId) else { return }
    collection.parentId = parentId
    collection.sortIndex = atIndex
    collection.auth = parentId == nil ? .none : collection.auth
    collection.updatedAt = Date()
    do {
        try await collectionRepository.save(collection)
        await loadTree()
    } catch {}
}

func canDropCollection(_ collectionId: UUID, intoParent parentId: UUID?) -> Bool {
    // Prevent cycle: cannot drop into own descendant
    if let parentId {
        var currentId: UUID? = parentId
        while let id = currentId {
            if id == collectionId { return false }
            currentId = collections.first(where: { $0.id == id })?.parentId
        }
    }

    // Depth check: count depth of target + subtree depth of dragged collection
    let targetDepth = depth(of: parentId)
    let subtreeDepth = maxSubtreeDepth(of: collectionId)
    return targetDepth + subtreeDepth + 1 <= 5
}

private func depth(of collectionId: UUID?) -> Int {
    var count = 0
    var currentId = collectionId
    while let id = currentId {
        count += 1
        currentId = collections.first(where: { $0.id == id })?.parentId
    }
    return count
}

private func maxSubtreeDepth(of collectionId: UUID) -> Int {
    let children = collections.filter { $0.parentId == collectionId }
    if children.isEmpty { return 0 }
    return 1 + children.map { maxSubtreeDepth(of: $0.id) }.max()!
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' test 2>&1 | grep -E "(Test|FAIL|SUCCEED)"`
Expected: All tests PASS

- [ ] **Step 5: Add drag-and-drop modifiers to CollectionTreeView**

Update `CollectionTreeView` — add to `sidebarItemView` for the request case:

```swift
case .request(let request):
    RequestRow(request: request)
        .tag(request.id)
        .draggable(request.id.uuidString)
        .contextMenu { requestContextMenu(request) }
```

Update the `collectionDisclosure` method to add drag and drop on the disclosure group label and content:

```swift
private func collectionDisclosure(_ collection: Collection) -> some View {
    DisclosureGroup(isExpanded: Binding(
        get: { expandedCollections.contains(collection.id) },
        set: { isExpanded in
            if isExpanded {
                expandedCollections.insert(collection.id)
            } else {
                expandedCollections.remove(collection.id)
            }
        }
    )) {
        ForEach(viewModel.children(of: collection.id)) { child in
            sidebarItemView(child)
        }
    } label: {
        CollectionRow(
            collection: collection,
            isExpanded: .constant(expandedCollections.contains(collection.id))
        )
        .tag(collection.id)
        .draggable(collection.id.uuidString)
        .contextMenu { collectionContextMenu(collection) }
    }
    .dropDestination(for: String.self) { items, _ in
        guard let idString = items.first, let itemId = UUID(uuidString: idString) else { return false }
        if viewModel.requests.contains(where: { $0.id == itemId }) {
            Task { await viewModel.moveRequest(itemId, toCollection: collection.id, atIndex: 0) }
            return true
        } else if viewModel.canDropCollection(itemId, intoParent: collection.id) {
            Task { await viewModel.moveCollection(itemId, toParent: collection.id, atIndex: 0) }
            return true
        }
        return false
    }
}
```

- [ ] **Step 6: Build to verify it compiles**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add appi/Presentation/ViewModels/CollectionTreeViewModel.swift appi/Presentation/Views/Sidebar/CollectionTreeView.swift appiTests/Presentation/ViewModels/CollectionTreeViewModelTests.swift
git commit -m "feat: add drag-and-drop with reorder, reparent, and depth/cycle validation"
```

---

## Task 10: Search Filtering

**Files:**
- Modify: `appi/Presentation/ViewModels/CollectionTreeViewModel.swift`
- Modify: `appiTests/Presentation/ViewModels/CollectionTreeViewModelTests.swift`

- [ ] **Step 1: Write failing tests for search filtering**

Append to `CollectionTreeViewModelTests`:

```swift
@Test("filteredChildren returns all items when searchQuery is empty")
func filteredChildrenNoQuery() async throws {
    let colRepo = MockCollectionRepository()
    let collection = Collection(id: UUID(), name: "API", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
    colRepo.collections = [collection]

    let reqRepo = MockRequestRepository()
    let request = Request(id: UUID(), name: "Login", method: .post, url: "/login", headers: [], body: .none, auth: .inheritFromParent, collectionId: collection.id, sortIndex: 0, createdAt: Date(), updatedAt: Date())
    reqRepo.requests = [request]

    let vm = makeViewModel(collectionRepository: colRepo, requestRepository: reqRepo)
    await vm.loadTree()
    vm.searchQuery = ""

    let roots = vm.filteredChildren(of: nil)
    #expect(roots.count == 1) // collection
}

@Test("filteredChildren matches request name case-insensitively")
func filteredChildrenMatchesRequest() async throws {
    let colRepo = MockCollectionRepository()
    let collection = Collection(id: UUID(), name: "API", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
    colRepo.collections = [collection]

    let reqRepo = MockRequestRepository()
    let match = Request(id: UUID(), name: "Login", method: .post, url: "/login", headers: [], body: .none, auth: .inheritFromParent, collectionId: collection.id, sortIndex: 0, createdAt: Date(), updatedAt: Date())
    let noMatch = Request(id: UUID(), name: "Logout", method: .post, url: "/logout", headers: [], body: .none, auth: .inheritFromParent, collectionId: collection.id, sortIndex: 1, createdAt: Date(), updatedAt: Date())
    reqRepo.requests = [match, noMatch]

    let vm = makeViewModel(collectionRepository: colRepo, requestRepository: reqRepo)
    await vm.loadTree()
    vm.searchQuery = "login"

    // Collection should be visible because it contains a matching request
    let roots = vm.filteredChildren(of: nil)
    #expect(roots.count == 1)

    let collectionChildren = vm.filteredChildren(of: collection.id)
    #expect(collectionChildren.count == 1)
    #expect(collectionChildren.first?.name == "Login")
}

@Test("filteredChildren matches collection name")
func filteredChildrenMatchesCollection() async throws {
    let colRepo = MockCollectionRepository()
    let matchCol = Collection(id: UUID(), name: "Auth API", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
    let noMatchCol = Collection(id: UUID(), name: "Users", parentId: nil, sortIndex: 1, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
    colRepo.collections = [matchCol, noMatchCol]

    let vm = makeViewModel(collectionRepository: colRepo)
    await vm.loadTree()
    vm.searchQuery = "auth"

    let roots = vm.filteredChildren(of: nil)
    #expect(roots.count == 1)
    #expect(roots.first?.name == "Auth API")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' test 2>&1 | grep -E "(error|FAIL|SUCCEED)"`
Expected: FAIL — `filteredChildren` not found

- [ ] **Step 3: Implement filteredChildren on CollectionTreeViewModel**

Add to `CollectionTreeViewModel`:

```swift
/// Returns filtered sidebar items for a given parent.
/// When searchQuery is non-empty, only shows items matching the query
/// and collections that contain matching descendants.
func filteredChildren(of parentId: UUID?) -> [SidebarItem] {
    guard !searchQuery.isEmpty else {
        return children(of: parentId)
    }

    let query = searchQuery.lowercased()

    let childCollections = collections
        .filter { $0.parentId == parentId }
        .filter { collectionMatchesSearch($0, query: query) }
        .map { SidebarItem.collection($0) }

    let childRequests: [SidebarItem]
    if let parentId {
        childRequests = requests
            .filter { $0.collectionId == parentId }
            .filter { $0.name.lowercased().contains(query) }
            .map { SidebarItem.request($0) }
    } else {
        childRequests = []
    }

    return (childCollections + childRequests).sorted { $0.sortIndex < $1.sortIndex }
}

/// Returns true if collection name matches or any descendant matches
private func collectionMatchesSearch(_ collection: Collection, query: String) -> Bool {
    if collection.name.lowercased().contains(query) { return true }

    // Check if any child requests match
    let hasMatchingRequest = requests
        .filter { $0.collectionId == collection.id }
        .contains { $0.name.lowercased().contains(query) }
    if hasMatchingRequest { return true }

    // Check if any child collections match (recursive)
    let childCollections = collections.filter { $0.parentId == collection.id }
    return childCollections.contains { collectionMatchesSearch($0, query: query) }
}
```

- [ ] **Step 4: Update CollectionTreeView to use filteredChildren**

In `CollectionTreeView`, replace `viewModel.children(of: nil)` with `viewModel.filteredChildren(of: nil)` in the `List` body, and `viewModel.children(of: collection.id)` with `viewModel.filteredChildren(of: collection.id)` in `collectionDisclosure`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' test 2>&1 | grep -E "(Test|FAIL|SUCCEED)"`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add appi/Presentation/ViewModels/CollectionTreeViewModel.swift appi/Presentation/Views/Sidebar/CollectionTreeView.swift appiTests/Presentation/ViewModels/CollectionTreeViewModelTests.swift
git commit -m "feat: add search filtering for sidebar — matches request and collection names"
```

---

## Task 11: Wire Request Deletion → Tab Reload

**Files:**
- Modify: `appi/Presentation/ViewModels/CollectionTreeViewModel.swift`
- Modify: `appi/App/ContentView.swift`
- Modify: `appiTests/Presentation/ViewModels/CollectionTreeViewModelTests.swift`

Orphan cleanup is already handled: `CollectionTreeViewModel.deleteRequest` calls `tabRepository.cleanupOrphanedLinks()` (Task 4). Now we need to notify `TabBarViewModel` to reload its in-memory state after cleanup.

- [ ] **Step 1: Write failing test for deleteRequest calling cleanupOrphanedLinks**

Append to `CollectionTreeViewModelTests`:

```swift
@Test("deleteRequest calls cleanupOrphanedLinks on tabRepository")
func deleteRequestCleansUpOrphans() async throws {
    let colRepo = MockCollectionRepository()
    let collection = Collection(id: UUID(), name: "API", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
    colRepo.collections = [collection]

    let reqRepo = MockRequestRepository()
    let request = Request(id: UUID(), name: "Login", method: .post, url: "/login", headers: [], body: .none, auth: .inheritFromParent, collectionId: collection.id, sortIndex: 0, createdAt: Date(), updatedAt: Date())
    reqRepo.requests = [request]

    let tabRepo = MockTabRepository()
    let vm = makeViewModel(collectionRepository: colRepo, requestRepository: reqRepo, tabRepository: tabRepo)
    await vm.loadTree()

    await vm.deleteRequest(request)

    #expect(tabRepo.cleanupOrphanedLinksCalled)
}
```

- [ ] **Step 2: Run test to verify it passes** (already implemented in Task 4)

Run: `xcodebuild -scheme appi -destination 'platform=macOS' test 2>&1 | grep -E "(deleteRequestCleansUp|FAIL|SUCCEED)"`
Expected: PASS

- [ ] **Step 3: Add onTreeChanged callback to CollectionTreeViewModel**

Add to `CollectionTreeViewModel`:

```swift
var onTreeChanged: (() -> Void)?
```

Call it at the end of `deleteRequest` and `deleteCollection` after `loadTree()`:

```swift
func deleteRequest(_ request: Request) async {
    do {
        try await requestRepository.delete(request)
        try await tabRepository.cleanupOrphanedLinks()
        await loadTree()
        onTreeChanged?()
    } catch {}
}

func deleteCollection(_ collection: Collection) async {
    do {
        try await collectionRepository.delete(collection)
        try await tabRepository.cleanupOrphanedLinks()
        await loadTree()
        onTreeChanged?()
    } catch {}
}
```

- [ ] **Step 4: Wire callback in ContentView**

In `ContentView`'s `.task` block, after setting `onRequestSelected`, add:

```swift
treeVM.onTreeChanged = {
    Task { await tabVM.reloadTabs() }
}
```

- [ ] **Step 5: Run all tests**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' test 2>&1 | grep -E "(Test|FAIL|SUCCEED)"`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add appi/Presentation/ViewModels/CollectionTreeViewModel.swift appi/App/ContentView.swift appiTests/Presentation/ViewModels/CollectionTreeViewModelTests.swift
git commit -m "feat: wire request/collection deletion to tab reload (RN-17)"
```

---

## Task 12: Final Build & Test Verification

**Files:** None (verification only)

- [ ] **Step 1: Run full build**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Run full test suite**

Run: `xcodebuild -scheme appi -destination 'platform=macOS' test 2>&1 | grep -E "(Test|FAIL|SUCCEED|Executed)"`
Expected: All tests PASS

- [ ] **Step 3: Run SwiftLint**

Run: `swiftlint lint --strict 2>&1 | tail -10`
Expected: No errors (warnings acceptable)

- [ ] **Step 4: Fix any lint issues if found, then commit**

```bash
git add -A
git commit -m "chore: fix SwiftLint issues from Sprint 2"
```
