# Appi — Coding Conventions

> Linguagem: Swift 5.10+  
> Plataforma: macOS 14+  
> Ver também: `architecture.md`, `testing-strategy.md`

---

## 1. Naming

### Geral
- Tipos: `PascalCase` — `RequestEditorViewModel`, `CollectionModel`
- Propriedades e funções: `camelCase` — `isLoading`, `fetchAll()`
- Constantes globais: `camelCase` — `let maxResponseHistory = 50`
- Acrônimos como palavras: `urlBar`, `httpClient`, `oAuth2Config` (não `URLBar`, `HTTPClient` em nomes compostos de variáveis)

### Convenção de nomes por camada

| Camada | Sufixo | Exemplo |
|---|---|---|
| Domain model (struct) | Sem sufixo | `Request`, `Collection` |
| SwiftData model | `Model` | `RequestModel`, `CollectionModel` |
| Repository protocol | `Repository` | `RequestRepository` |
| Repository impl | `SwiftData` + `Repository` | `SwiftDataRequestRepository` |
| Service protocol | Nome descritivo | `HTTPClient`, `EnvResolver`, `AuthService` |
| Service impl | Prefixo descritivo | `URLSessionHTTPClient`, `DefaultEnvResolver`, `PKCEAuthService` |
| ViewModel | `ViewModel` | `RequestEditorViewModel` |
| View | Nome descritivo + `View` | `RequestEditorView`, `SidebarView` |
| Mock (testes) | `Mock` + protocol name | `MockRequestRepository`, `MockHTTPClient` |

### Booleanos
- Prefixo `is`, `has`, `should`, `can`: `isLoading`, `isDirty`, `hasChanges`, `canSend`
- Nunca negativos: `isEnabled` (não `isDisabled`)

---

## 2. Organização de arquivos

### Estrutura de pastas
```
appi/
├── App/
│   ├── AppiApp.swift
│   └── ContentView.swift
├── Domain/
│   ├── Models/
│   │   ├── Workspace.swift
│   │   ├── Collection.swift
│   │   ├── Request.swift
│   │   ├── Response.swift
│   │   ├── Environment.swift
│   │   ├── EnvVariable.swift
│   │   ├── Tab.swift
│   │   └── ValueObjects.swift          ← HTTPMethod, Header, RequestBody, AuthConfig, etc.
│   ├── Repositories/
│   │   ├── WorkspaceRepository.swift
│   │   ├── CollectionRepository.swift
│   │   ├── RequestRepository.swift
│   │   ├── ResponseRepository.swift
│   │   ├── EnvironmentRepository.swift
│   │   └── TabRepository.swift
│   ├── Services/
│   │   ├── HTTPClient.swift
│   │   ├── EnvResolver.swift
│   │   ├── AuthResolver.swift
│   │   ├── AuthService.swift
│   │   ├── KeychainService.swift
│   │   ├── ImportParser.swift
│   │   └── ExportSerializer.swift
│   └── Errors/
│       └── Errors.swift                ← RequestError, AuthError, ImportError, PersistenceError
├── Data/
│   ├── Models/
│   │   ├── WorkspaceModel.swift
│   │   ├── CollectionModel.swift
│   │   ├── RequestModel.swift
│   │   ├── ResponseModel.swift
│   │   ├── EnvironmentModel.swift
│   │   ├── EnvVariableModel.swift
│   │   ├── TabModel.swift
│   │   └── Schema.swift                ← SchemaV1, AppiMigrationPlan
│   ├── Repositories/
│   │   ├── SwiftDataWorkspaceRepository.swift
│   │   ├── SwiftDataCollectionRepository.swift
│   │   ├── SwiftDataRequestRepository.swift
│   │   ├── SwiftDataResponseRepository.swift
│   │   ├── SwiftDataEnvironmentRepository.swift
│   │   └── SwiftDataTabRepository.swift
│   ├── Services/
│   │   ├── URLSessionHTTPClient.swift
│   │   ├── DefaultEnvResolver.swift
│   │   ├── DefaultAuthResolver.swift
│   │   ├── PKCEAuthService.swift
│   │   ├── PostmanImportParser.swift
│   │   ├── OpenAPIImportParser.swift
│   │   └── PostmanExportSerializer.swift
│   └── Keychain/
│       └── AppleKeychainService.swift
├── Presentation/
│   ├── ViewModels/
│   │   ├── CollectionTreeViewModel.swift
│   │   ├── RequestEditorViewModel.swift
│   │   ├── TabBarViewModel.swift
│   │   ├── EnvironmentViewModel.swift
│   │   ├── ResponseViewModel.swift
│   │   ├── ImportViewModel.swift
│   │   └── ExportViewModel.swift
│   └── Views/
│       ├── Sidebar/
│       │   ├── SidebarView.swift
│       │   ├── CollectionTreeView.swift
│       │   ├── CollectionRow.swift
│       │   ├── RequestRow.swift
│       │   └── EnvironmentPicker.swift
│       ├── Editor/
│       │   ├── RequestEditorView.swift
│       │   ├── URLBarView.swift
│       │   ├── HeadersEditorView.swift
│       │   ├── BodyEditorView.swift
│       │   ├── RawBodyEditor.swift
│       │   ├── FormDataEditor.swift
│       │   └── AuthEditorView.swift
│       ├── Response/
│       │   ├── ResponseViewerView.swift
│       │   ├── ResponseBodyView.swift
│       │   ├── ResponseHeadersView.swift
│       │   └── ResponseHistoryView.swift
│       ├── Tabs/
│       │   ├── TabBarView.swift
│       │   └── TabItemView.swift
│       ├── Sheets/
│       │   ├── ImportSheet.swift
│       │   ├── ExportSheet.swift
│       │   └── EnvironmentEditorSheet.swift
│       └── Common/
│           ├── EmptyStateView.swift
│           └── InlineErrorBanner.swift
├── DI/
│   └── DependencyContainer.swift
└── Resources/
    └── Localizable.xcstrings
```

### Regras
- Um tipo público por arquivo (exceto value objects pequenos que ficam juntos).
- Nome do arquivo = nome do tipo: `RequestEditorViewModel.swift`.
- Views agrupadas por feature, não por tipo de componente.
- Extensions no mesmo arquivo do tipo, exceto conformances grandes (ex: `RequestModel+Mapping.swift`).

---

## 3. Estilo de código

### MARK comments
```swift
final class RequestEditorViewModel {
    // MARK: - Properties
    var draft: RequestDraft
    
    // MARK: - Private
    private let requestRepository: RequestRepository
    
    // MARK: - Init
    init(...) { }
    
    // MARK: - Public Methods
    func send(environment: Environment?) async { }
    
    // MARK: - Private Methods
    private func validate() throws { }
}
```

### Guard early, return early
```swift
// Sim
func save() async throws {
    guard !draft.name.isEmpty else { return }
    guard let url = URL(string: draft.url) else {
        throw RequestError.invalidURL(draft.url)
    }
    try await requestRepository.save(draft.toRequest())
}

// Não
func save() async throws {
    if !draft.name.isEmpty {
        if let url = URL(string: draft.url) {
            try await requestRepository.save(draft.toRequest())
        } else {
            throw RequestError.invalidURL(draft.url)
        }
    }
}
```

### async/await
```swift
// Preferir async let para operações paralelas independentes
func loadInitialData() async throws {
    async let collections = collectionRepository.fetchAll(in: workspaceId)
    async let environments = environmentRepository.fetchAll(in: workspaceId)
    
    self.collections = try await collections
    self.environments = try await environments
}
```

### Access control
- `@Model` classes: `internal` (default).
- Protocols: `internal` (default).
- ViewModels: properties publicadas `internal`, helpers `private`.
- Views: `internal` (default), subviews extraídas `private`.

---

## 4. SwiftUI conventions

### Views sem lógica
```swift
// Sim — View pura, lógica no ViewModel
struct RequestEditorView: View {
    @State private var viewModel: RequestEditorViewModel
    
    var body: some View {
        VStack {
            URLBarView(
                method: $viewModel.draft.method,
                url: $viewModel.draft.url,
                onSend: { await viewModel.send(environment: activeEnvironment) }
            )
        }
    }
}

// Não — lógica na View
struct RequestEditorView: View {
    var body: some View {
        Button("Send") {
            let url = URL(string: urlString)!
            let request = URLRequest(url: url)
            // ...
        }
    }
}
```

### Localização
```swift
// Sim
Text(String(localized: "newRequest.title"))
Button(String(localized: "action.send")) { }

// Não
Text("New Request")
Button("Send") { }
```

### Acessibilidade
```swift
// Em toda View interativa
Button(action: send) {
    Image(systemName: "paperplane")
}
.accessibilityLabel(String(localized: "action.send"))
.accessibilityHint(String(localized: "action.send.hint"))
```

---

## 5. Git conventions

### Commits
- Mensagem em inglês, imperativo: `add request editor view`, `fix auth chain resolution`
- Prefixos opcionais: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`
- Uma mudança lógica por commit

### Branches
- `main` — branch principal
- `feat/<nome>` — features
- `fix/<nome>` — bug fixes
- `refactor/<nome>` — refactoring

---

## 6. SwiftLint

Regras habilitadas (arquivo `.swiftlint.yml` na raiz):

```yaml
included:
  - appi

excluded:
  - appiTests
  - appiUITests

opt_in_rules:
  - empty_count
  - closure_spacing
  - contains_over_filter_count
  - discouraged_optional_boolean
  - empty_string
  - force_unwrapping
  - implicitly_unwrapped_optional
  - modifier_order
  - trailing_comma
  - vertical_whitespace_closing_braces

disabled_rules:
  - todo
  - line_length

force_cast: error
force_try: error
force_unwrapping: error
```

**Regra zero:** `force_cast`, `force_try` e `force_unwrapping` são erros de compilação no lint. Nunca usar em código de produção (testes podem usar `try!` para setup).

---

*Ver também: `architecture.md`, `testing-strategy.md`*
