# Appi — Arquitetura

> Padrão: MVVM + Repository (SSOT) + SOLID  
> Ver também: `domain.md`, `requirements.md`

---

## 1. Visão geral

O Appi segue o padrão MVVM: ViewModels `@Observable` consomem repositories que atuam como Single Source of Truth (SSOT). A lógica de negócio fica nos repositories e services — nunca nas Views.

---

## 2. Estrutura de camadas

```
App/
├── Domain/
│   ├── Models/             ← structs/enums puros (Codable, Equatable). Sem @Model, sem SwiftData.
│   ├── Repositories/       ← protocols — interfaces que definem o contrato (SOLID-DIP)
│   ├── Services/           ← protocols de services (KeychainService, ImportParser, etc.)
│   └── Errors/             ← RequestError, AuthError, ImportError, PersistenceError
│
├── Data/
│   ├── Models/             ← @Model classes SwiftData (RequestModel, CollectionModel, etc.)
│   ├── Repositories/       ← implementações concretas dos protocols (@ModelActor + SwiftData)
│   ├── Services/           ← HTTPClient, EnvResolver, AuthService, AuthResolver, ImportService
│   └── Keychain/           ← AppleKeychainService (impl concreta do KeychainService protocol)
│
├── Presentation/
│   ├── ViewModels/          ← @Observable @MainActor, consome repositories via protocol
│   └── Views/               ← SwiftUI puro, sem lógica de negócio
│
├── DI/
│   └── DependencyContainer  ← factory de ViewModels e wiring de dependências
│
└── Resources/
    └── Localizable.xcstrings ← String Catalogs (pt-BR, en)
```

---

## 3. Fluxo de dados

```
View  →  ViewModel (@Observable, @MainActor)  →  Repository (protocol)
                                                       ↓
                                               Data/Repository (@ModelActor)
                                                       ↓
                                                SwiftData / Keychain
```

**Regras:**
- View nunca acessa repository diretamente.
- ViewModel nunca conhece SwiftData — só o protocol do repository.
- Repository é injetado no ViewModel via inicializador (SOLID-DIP, facilita mock nos testes).
- Services são injetados da mesma forma que repositories.

---

## 4. Injeção de dependências — DependencyContainer

```swift
@Observable
final class DependencyContainer {
    // Repositories
    let workspaceRepository: WorkspaceRepository
    let collectionRepository: CollectionRepository
    let requestRepository: RequestRepository
    let responseRepository: ResponseRepository
    let environmentRepository: EnvironmentRepository
    
    // Services
    let httpClient: HTTPClient
    let envResolver: EnvResolver
    let authResolver: AuthResolver
    let authService: AuthService
    let keychainService: KeychainService
    
    // Tab
    let tabRepository: TabRepository
    
    init(modelContainer: ModelContainer) {
        let keychain = AppleKeychainService()
        self.keychainService = keychain
        self.workspaceRepository = SwiftDataWorkspaceRepository(modelContainer: modelContainer)
        self.collectionRepository = SwiftDataCollectionRepository(modelContainer: modelContainer)
        self.requestRepository = SwiftDataRequestRepository(modelContainer: modelContainer)
        self.responseRepository = SwiftDataResponseRepository(modelContainer: modelContainer)
        self.environmentRepository = SwiftDataEnvironmentRepository(
            modelContainer: modelContainer,
            keychainService: keychain
        )
        self.httpClient = URLSessionHTTPClient() // seguro compartilhar: stateless, sem cancelamento global
        self.envResolver = DefaultEnvResolver()
        self.authService = PKCEAuthService(keychainService: keychain)
        self.authResolver = DefaultAuthResolver(authService: self.authService)
        self.tabRepository = SwiftDataTabRepository(modelContainer: modelContainer)
    }
    
    // MARK: - Factories
    
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
    
    func makeEnvironmentViewModel(workspaceId: UUID) -> EnvironmentViewModel {
        EnvironmentViewModel(
            workspaceId: workspaceId,
            environmentRepository: environmentRepository
        )
    }
    
    // ... demais factories
}
```

**Wiring no App struct:**
```swift
@main
struct AppiApp: App {
    let modelContainer: ModelContainer
    let container: DependencyContainer
    
    init() {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let container = try! ModelContainer(for: schema)
        self.modelContainer = container
        self.container = DependencyContainer(modelContainer: container)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(container)
        }
    }
}
```

Views acessam o container via `@Environment(DependencyContainer.self)` e chamam factory methods para criar ViewModels.

> `workspaceId` não é inferido dentro dos ViewModels. O bootstrap inicial (`ContentView` ou um `RootViewModel`) resolve o workspace atual uma vez: busca o workspace default no `WorkspaceRepository`, cria se não existir no first launch, guarda `currentWorkspaceId` e passa esse ID para as factories que carregam collections e environments. Mesmo com um único workspace na v1.0, o ID continua explícito para manter os contratos consistentes.

---

## 5. Concorrência

| Camada | Isolamento | Motivo |
|---|---|---|
| Views | `@MainActor` (implícito SwiftUI) | Atualização de UI |
| ViewModels | `@MainActor` | Alimentam Views, publicam estado observável |
| Repositories | `@ModelActor` | `ModelContext` isolado, operações em background sem bloquear UI |
| HTTPClient | Struct stateless | `URLSession` é thread-safe. Cancelamento é request-scoped via cancelamento da `Task` chamadora; o client não mantém task global |
| EnvResolver | Struct stateless | Sem estado mutável, sem restrição de actor |
| AuthResolver | Struct com dependência de AuthService | Async por causa do refresh de token; sem estado próprio |
| AuthService | Actor | Gerencia estado de tokens, acesso ao Keychain serializado |
| KeychainService | Struct | Chamadas ao Security framework são thread-safe |

**Regras:**
- `ModelContext` nunca é compartilhado entre actors. Cada `@ModelActor` cria o seu.
- `async let` para operações paralelas (ex: carregar collections e environments simultaneamente).

### Domain structs vs SwiftData @Model

O projeto mantém **dois conjuntos de tipos separados**:

| Camada | Tipo | Exemplo | Usado por |
|---|---|---|---|
| `Domain/Models/` | Structs puros | `Request`, `Collection` | ViewModels, Services, testes |
| `Data/Models/` | @Model classes | `RequestModel`, `CollectionModel` | Repositories (interno) |

Repositories fazem a conversão entre os dois:
```swift
// Dentro do SwiftDataRequestRepository (@ModelActor)
func fetchAll(in collectionId: UUID) async throws -> [Request] {
    let models = try context.fetch(...)  // [RequestModel]
    return models.map { $0.toDomain() }  // [Request] — struct puro
}

func save(_ request: Request) async throws {
    let model = RequestModel(from: request)  // @Model
    context.insert(model)
    try context.save()
}
```

**Por que dois tipos:**
- Domain fica 100% desacoplado do SwiftData — testável sem `ModelContainer`.
- `@Model` objects não cruzam fronteiras de actor — só structs viajam.
- ViewModels nunca lidam com `ModelContext` ou lifecycle de objetos gerenciados.

**Convenção de nomes:** domain struct = `Request`, @Model class = `RequestModel`. Cada `@Model` tem `toDomain() -> Request` e `init(from: Request)`.

---

## 6. Repository protocols

```swift
// Domain/Repositories/WorkspaceRepository.swift
protocol WorkspaceRepository {
    func fetchAll() async throws -> [Workspace]
    func save(_ workspace: Workspace) async throws
    func delete(_ workspace: Workspace) async throws
}

// Domain/Repositories/CollectionRepository.swift
protocol CollectionRepository {
    func fetchAll(in workspaceId: UUID) async throws -> [Collection]
    func save(_ collection: Collection) async throws
    func delete(_ collection: Collection) async throws
    func move(_ collection: Collection, to parent: Collection?) async throws
    /// Retorna a cadeia [collection, pai, avô, ..., raiz] para resolução de auth
    func ancestorChain(for collectionId: UUID) async throws -> [Collection]
}

// Domain/Repositories/RequestRepository.swift
protocol RequestRepository {
    func fetchAll(in collectionId: UUID) async throws -> [Request]
    func save(_ request: Request) async throws
    func delete(_ request: Request) async throws
    func duplicate(_ request: Request) async throws -> Request
}

// Domain/Repositories/ResponseRepository.swift
protocol ResponseRepository {
    func fetchHistory(for requestId: UUID) async throws -> [Response]
    func save(_ response: Response, forRequestId: UUID) async throws
    // Aplica RN-03: descarta responses antigas além do limite de 50
}

// Domain/Repositories/EnvironmentRepository.swift
protocol EnvironmentRepository {
    func fetchAll(in workspaceId: UUID) async throws -> [Environment]
    func activate(_ environment: Environment) async throws
    // Garante RN-02: desativa todos os outros do workspace
    func save(_ environment: Environment) async throws
    func delete(_ environment: Environment) async throws
}

// Domain/Repositories/TabRepository.swift
protocol TabRepository {
    func fetchAll() async throws -> [Tab]
    func save(_ tab: Tab) async throws
    func delete(_ tab: Tab) async throws
    func cleanupOrphanedLinks() async throws
    // Tabs cujo linkedRequestId aponta para request deletado → seta linkedRequestId = nil (RN-17)
}
```

---

## 7. Service protocols

```swift
// Executa o URLRequest e retorna Response — sem persistência
// Cancelamento é responsabilidade do chamador (ex: ViewModel), via Task cancellation
protocol HTTPClient {
    func execute(_ request: ResolvedRequest) async throws -> Response
}

// Substitui {{variáveis}} e valida URL — stateless, sem side effects
// Retorna PreparedRequest (sem auth) — auth é resolvida separadamente pelo AuthResolver
// Lança RequestError.invalidURL se a URL resultante não for válida (RN-04)
protocol EnvResolver {
    func resolve(_ draft: RequestDraft, using environment: Environment?) throws -> PreparedRequest
    func unresolvedKeys(in draft: RequestDraft, environment: Environment?) -> [String]
}

// Resolve a auth efetiva percorrendo a cadeia request → collection → ... → collection raiz
// Para OAuth2: carrega token do Keychain e faz refresh se necessário (RN-15)
// Retorna ResolvedAuth (tipo seguro, nunca .inheritFromParent)
// Async porque OAuth2 pode exigir refresh de token
protocol AuthResolver {
    func resolve(for auth: AuthConfig, chain: [Collection]) async throws -> ResolvedAuth
}

// Gerencia fluxo OAuth2: autorização inicial, refresh e armazenamento de tokens
protocol AuthService {
    func authorize(with config: OAuth2Config) async throws -> TokenSet
    func refreshIfNeeded(tokenSet: TokenSet, config: OAuth2Config) async throws -> TokenSet
    func loadToken(for config: OAuth2Config) throws -> TokenSet?
    func saveToken(_ tokenSet: TokenSet, for config: OAuth2Config) throws
}

// Keychain — acesso a secrets (tokens OAuth2, variáveis secretas)
protocol KeychainService {
    func save(_ data: Data, for key: String) throws
    func load(for key: String) throws -> Data?
    func delete(for key: String) throws
}

// Novos formatos de import adicionam nova impl sem modificar as existentes (SOLID-OCP)
protocol ImportParser {
    func canParse(_ data: Data) -> Bool
    func parse(_ data: Data) throws -> ImportResult
}

protocol ExportSerializer {
    func serialize(
        _ rootCollection: Collection,
        descendants: [Collection],    // sub-collections em toda a sub-árvore
        requests: [Request],          // requests de toda a sub-árvore
        environment: Environment?     // inclui variáveis; secrets excluídos por RN-06
    ) throws -> Data
}
```

---

## 8. Exemplo — ViewModel corrigido

```swift
// Presentation/ViewModels/RequestEditorViewModel.swift
@Observable @MainActor
final class RequestEditorViewModel {
    var draft: RequestDraft {
        didSet { syncDraftToTab() }
    }
    var response: Response?
    var isLoading: Bool = false
    var error: (any LocalizedError)?
    
    private var tab: Tab
    private var sendTask: Task<Void, Never>?
    private var activeSendID: UUID?
    private let tabRepository: TabRepository
    private let requestRepository: RequestRepository
    private let responseRepository: ResponseRepository
    private let collectionRepository: CollectionRepository
    private let httpClient: HTTPClient
    private let envResolver: EnvResolver
    private let authResolver: AuthResolver

    init(
        draft: RequestDraft,
        tab: Tab,
        tabRepository: TabRepository,
        requestRepository: RequestRepository,
        responseRepository: ResponseRepository,
        collectionRepository: CollectionRepository,
        httpClient: HTTPClient,
        envResolver: EnvResolver,
        authResolver: AuthResolver
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
    }

    func startSend(environment: Environment?) {
        sendTask?.cancel()
        let sendID = UUID()
        activeSendID = sendID
        isLoading = true
        error = nil
        sendTask = Task { [weak self] in
            guard let self else { return }
            await self.send(environment: environment, sendID: sendID)
        }
    }

    func cancelRequest() {
        sendTask?.cancel()
        sendTask = nil
        activeSendID = nil
        isLoading = false
    }

    private func send(environment: Environment?, sendID: UUID) async {
        defer { finishSendIfNeeded(sendID: sendID) }
        do {
            try Task.checkCancellation()

            // 1. Resolve variáveis + valida URL → PreparedRequest (sem auth)
            //    Lança RequestError.invalidURL se URL inválida após substituição (RN-04)
            let prepared = try envResolver.resolve(draft, using: environment)
            try Task.checkCancellation()
            
            // 2. Resolve auth chain completa → ResolvedAuth
            //    Para OAuth2: carrega token do Keychain e faz refresh se expirado (RN-15)
            //    Lança AuthError.tokenExpired se refresh falhar → UI mostra "Re-authorize"
            let chain = try await collectionRepository.ancestorChain(for: draft.collectionId)
            let auth = try await authResolver.resolve(for: draft.auth, chain: chain)
            try Task.checkCancellation()
            
            // 3. Combina → ResolvedRequest (completo)
            let resolved = prepared.withAuth(auth)
            
            // 4. Executa
            let result = try await httpClient.execute(resolved)
            guard activeSendID == sendID else { return }
            
            // 5. Salva no histórico (apenas se vinculado a request existente)
            if let requestId = tab.linkedRequestId {
                try await responseRepository.save(result, forRequestId: requestId)
            }
            
            response = result
        } catch let requestError as RequestError {
            guard activeSendID == sendID else { return }
            self.error = requestError          // URL inválida, rede, timeout, SSL
        } catch let authError as AuthError {
            guard activeSendID == sendID else { return }
            self.error = authError             // token expirado, refresh falhou
        } catch let persistenceError as PersistenceError {
            guard activeSendID == sendID else { return }
            self.error = persistenceError      // ancestorChain ou save falharam
        } catch is CancellationError {
            guard activeSendID == sendID else { return }
            self.error = RequestError.cancelled
        } catch {
            guard activeSendID == sendID else { return }
            self.error = RequestError.networkError(
                error as? URLError ?? URLError(.unknown)
            )
        }
    }

    func save() async throws {
        let request: Request
        if let existingId = tab.linkedRequestId {
            request = draft.toRequest(existingId: existingId)
        } else {
            request = draft.toRequest()
            tab.linkedRequestId = request.id
        }
        try await requestRepository.save(request)
        tab.draft = draft
        try await tabRepository.save(tab)
    }

    private func syncDraftToTab() {
        guard tab.draft != draft else { return }
        tab.draft = draft
        let snapshot = tab
        Task {
            try? await tabRepository.save(snapshot)
        }
    }

    private func finishSendIfNeeded(sendID: UUID) {
        guard activeSendID == sendID else { return }
        sendTask = nil
        activeSendID = nil
        isLoading = false
    }
}
```

**Contrato importante para Sprint 2:**
- Cancelamento é por aba: `RequestEditorViewModel` cancela apenas sua própria `sendTask`.
- `HTTPClient` permanece compartilhado no container porque é stateless.
- Toda mudança relevante no draft é espelhada em `tab.draft` e persistida via `TabRepository.save(_:)`, garantindo restauração após relaunch.
- `TabBarViewModel` cuida da coleção de tabs, seleção e restauração; cada `RequestEditorViewModel` cuida da sincronização da sua `Tab` ativa.

---

## 9. Migração de dados

O Appi usa `VersionedSchema` do SwiftData desde a v1.0 para preparar migrações futuras.

```swift
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [WorkspaceModel.self, CollectionModel.self, RequestModel.self,
         ResponseModel.self, EnvironmentModel.self, EnvVariableModel.self, TabModel.self]
    }
}

enum AppiMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }  // vazio na v1.0
}
```

**Regra para futuro:** toda mudança de model a partir da v1.1 deve:
1. Criar novo `SchemaVN` com os models atualizados.
2. Adicionar `MigrationStage` no `AppiMigrationPlan`.
3. Testar migração com dados reais da versão anterior.

---

## 10. SOLID aplicado por camada

| Princípio | Onde se aplica no Appi |
|---|---|
| **S** — Single Responsibility | Cada repository cuida de uma entidade. `HTTPClient` só executa. `EnvResolver` só resolve variáveis. `AuthResolver` só resolve a cadeia de auth. `KeychainService` só acessa Keychain. |
| **O** — Open/Closed | Novos formatos de import adicionam nova impl de `ImportParser` sem modificar as existentes. |
| **L** — Liskov Substitution | `MockRequestRepository` substitui `SwiftDataRequestRepository` nos testes sem quebrar o ViewModel. |
| **I** — Interface Segregation | Protocols pequenos e focados por entidade — não um `DatabaseRepository` genérico. |
| **D** — Dependency Inversion | ViewModels dependem do protocol, nunca da impl concreta. `DependencyContainer` faz o wiring. |

---

## 11. Diretrizes transversais

### Localização
- Toda string visível ao usuário via `String(localized:)` ou `LocalizedStringKey`.
- String Catalogs (`.xcstrings`) com idiomas: pt-BR, en.
- Nunca hardcodar strings na UI.

### Acessibilidade
- Toda View com `accessibilityLabel` descritivo.
- `accessibilityHint` quando a ação não é óbvia.
- Suporte a Dynamic Type em todos os textos.
- Navegação VoiceOver coerente em todas as telas.
- Implementada desde o Sprint 1 — não é polimento.

### Tratamento de erros
- Erros sempre inline no contexto (ver `requirements.md` seção 6).
- Todos os error enums implementam `LocalizedError` com mensagens localizadas.
- Alerts modais apenas para confirmação de ações destrutivas.

---

*Ver também: `domain.md`, `requirements.md`*
