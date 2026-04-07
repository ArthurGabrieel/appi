# Sprint 2 — Organização (Design Spec)

> Data: 2026-04-07
> Escopo: CollectionTree sidebar, drag-and-drop, tab bar, busca, first launch

---

## Decisões

| Decisão | Escolha |
|---|---|
| Abordagem | Vertical slices (feature completa end-to-end por vez) |
| Ordem | First launch → Sidebar → Tabs → Drag-and-drop → Search |
| Abrir request na sidebar | Reusa tab se request já aberto, senão nova tab (RF-04) |
| Drag-and-drop | Full: reorder + reparent + mover entre collections (respeita RN-05) |
| Restauração de tabs | Restaura todas as tabs + qual estava ativa |
| Busca | Filtra por nome de request e collection (case-insensitive) |

---

## Slice 1: First Launch (RF-09)

**Owner:** `AppiApp.init()` via `.task {}` no root view.

**Fluxo:**
1. `workspaceRepository.fetchAll()` — se vazio, cria workspace default
2. `collectionRepository.save()` — cria "My Collection" (`parentId = nil`, `auth = .none`, `workspaceId` do workspace criado)
3. `tabRepository.save()` — cria tab com `draft = RequestDraft.empty(in: collectionId)`, `isActive = true`

Se workspace já existe, no-op.

**Testes:** Integração com SwiftData in-memory — verifica criação no DB vazio e no-op quando workspace existe.

---

## Slice 2: CollectionTree Sidebar

### CollectionTreeViewModel

`@Observable @MainActor`. Dependências: `CollectionRepository`, `RequestRepository`, `WorkspaceRepository`.

**Estado:**
- `collections: [Collection]`
- `requests: [Request]` (todos do workspace, agrupados por `collectionId`)
- `selectedItemId: UUID?`
- `searchQuery: String` (Slice 5)

**Responsabilidades:**
- Carregar árvore completa do workspace default (collections + requests)
- CRUD de collections e requests (create, rename, delete)
- Seleção de item — notifica o tab bar quando request é selecionado

**SidebarItem:**
```swift
enum SidebarItem: Identifiable {
    case collection(Collection)
    case request(Request)

    var id: UUID { ... }
    var sortIndex: Int { ... }
}
```

Itens de mesmo nível (sub-collections + requests dentro de uma collection) são mesclados e ordenados por `sortIndex`.

### Views

| View | Responsabilidade |
|---|---|
| `SidebarView` | Container: SearchField + CollectionTreeView + EnvironmentPicker (placeholder) |
| `CollectionTreeView` | `List` recursivo com `DisclosureGroup` para collections |
| `CollectionRow` | Disclosure group: ícone + nome da collection |
| `RequestRow` | Badge de método (colorido) + nome do request |

**Context menus:**
- Collection: New Request, New Sub-collection, Rename, Delete
- Request: Duplicate, Rename, Delete

**Delete:** Confirmação via alert modal (ação destrutiva).
**Rename:** Inline via `TextField`.

---

## Slice 3: Tab Bar

### TabBarViewModel

`@Observable @MainActor`. Dependências: `TabRepository`, `RequestRepository`.

**Estado:**
- `tabs: [Tab]`
- `activeTabId: UUID?`

**Operações:**

| Operação | Comportamento |
|---|---|
| Abrir request | Se já aberto em tab → ativa tab. Senão → nova tab com `RequestDraft.from(request)` |
| Nova tab | `RequestDraft.empty(in: collectionId)`, `linkedRequestId = nil` |
| Fechar tab dirty (com `linkedRequestId`) | Alert: Salvar / Descartar / Cancelar (RN-07) |
| Fechar tab dirty (sem `linkedRequestId`) | Descarta silenciosamente |
| Fechar última tab | `activeTabId = nil` → `EmptyStateView` |
| Restauração no launch | `fetchAll()` + `cleanupOrphanedLinks()` + restaura `isActive` tab |

Toda mutação (criar, reordenar, ativar, atualizar draft) persiste via `TabRepository`.

**Deleção de request aberto em tab:** Quando `CollectionTreeViewModel` deleta um request, notifica `TabBarViewModel`. Tabs com `linkedRequestId` apontando para o request deletado viram draft órfão (`linkedRequestId = nil`) sem perder conteúdo (RN-17). Não fecha a tab.

**Dirty tracking:** Compara `tab.draft` com request salvo (via `RequestRepository`). Tabs sem `linkedRequestId` nunca são dirty.

### Views

| View | Responsabilidade |
|---|---|
| `TabBarView` | Scroll horizontal de tabs + botão "+" |
| `TabItemView` | Nome, badge de método, indicador dirty (ponto), botão fechar (x) |

### Integração

- **Sidebar → Tabs:** `CollectionTreeViewModel` expõe callback `onRequestSelected: (Request) -> Void`. `ContentView` conecta ao `TabBarViewModel.openRequest()`.
- **Tabs → Editor:** Tab ativa alimenta `RequestEditorViewModel` via `DependencyContainer.makeRequestEditorViewModel(draft:tab:)`. Novo ViewModel criado ao trocar de tab.

---

## Slice 4: Drag-and-Drop

Adição ao `CollectionTreeView` existente (Slice 2).

**API SwiftUI:** `draggable()` / `dropDestination()` em `CollectionRow` e `RequestRow`.

**Operações:**
- Reordenar dentro do mesmo pai — atualiza `sortIndex` dos irmãos
- Reparentar request para outra collection — atualiza `collectionId` + `sortIndex`
- Reparentar sub-collection para outro pai — atualiza `parentId` + `sortIndex`

**Validações:**
- Profundidade máxima de 5 níveis (RN-05) — conta subtree completa da collection sendo arrastada
- Prevenção de ciclo — não permite dropar collection dentro de seus próprios descendentes

**ViewModel additions (`CollectionTreeViewModel`):**
- `moveRequest(_ requestId: UUID, toCollection: UUID, atIndex: Int)`
- `moveCollection(_ collectionId: UUID, toParent: UUID?, atIndex: Int)`
- `canDrop(collection: UUID, intoParent: UUID?) -> Bool`

**Feedback visual:** Indicador de drop entre itens (comportamento padrão de `List`). Drops inválidos não mostram indicador.

---

## Slice 5: Search

**Campo:** `SearchField` no topo de `SidebarView`, bound a `CollectionTreeViewModel.searchQuery`.

**Lógica de filtro (in-memory, no ViewModel):**
- Query vazia → árvore completa
- Request match → request visível + cadeia de collections pai expandida
- Collection match → collection visível com todos os filhos
- Case-insensitive, substring match

**Propriedade:** `filteredItems` computada no ViewModel, consumida pela `CollectionTreeView`.

**UX:** `⌘F` foca o campo. Limpar restaura a árvore completa. Sem debounce (dados in-memory).

---

## Arquivos novos esperados

### Presentation/ViewModels/
- `CollectionTreeViewModel.swift`
- `TabBarViewModel.swift`

### Presentation/Views/Sidebar/
- `SidebarView.swift`
- `CollectionTreeView.swift`
- `CollectionRow.swift`
- `RequestRow.swift`

### Presentation/Views/Tabs/
- `TabBarView.swift`
- `TabItemView.swift`

### DI/
- Atualização de `DependencyContainer` — factories para novos ViewModels

### App/
- Atualização de `ContentView` — wiring sidebar + tabs + editor
- Atualização de `AppiApp` — bootstrap first launch

### Testes
- `CollectionTreeViewModelTests.swift`
- `TabBarViewModelTests.swift`
- `FirstLaunchTests.swift` (integração)
