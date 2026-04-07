# Appi — Estratégia de Testes

> Framework: Swift Testing (não XCTest)  
> Meta: ≥ 80% de cobertura em ViewModels, repositories e services (RNF-04)

---

## 1. Princípios

- Testar comportamento, não implementação.
- Mocks apenas nos limites de camada (protocols). Nunca mockar tipos internos.
- Cada teste é independente — sem estado compartilhado entre testes.
- Nomes descrevem cenário e expectativa: `func requestComPostEMetodoCorreto()`.
- Testes unitários rodam sem rede, sem Keychain real, sem filesystem (mocks em todos os limites).
- Testes de integração do `AppleKeychainService` usam o Keychain real com itens de teste (limpos no teardown).

---

## 2. O que testar por camada

### Domain/Models — Testes unitários puros

Structs e enums são puros — testáveis sem dependências.

| O que testar | Exemplo |
|---|---|
| Value objects | `HTTPMethod.get.rawValue == "GET"` |
| `RequestDraft.empty()` | Valida defaults (method GET, body none, auth inheritFromParent) |
| `RequestDraft.toRequest()` | Gera Request com UUID e timestamps |
| `RequestDraft.toRequest(existingId:)` | Preserva o ID fornecido |
| `PreparedRequest.withAuth()` | Combina com `ResolvedAuth` corretamente |
| `RequestBody` encoding/decoding | Codable round-trip para cada case (encoding manual — enum com associated values) |
| `AuthConfig` encoding/decoding | Codable round-trip incluindo OAuth2Config (encoding manual — enum com associated values) |

**Sem mocks necessários.** Tudo é struct/enum.

### ViewModels — Testes unitários com mocks

ViewModels são `@MainActor` e dependem de protocols. Injetar mocks.

| O que testar | Como |
|---|---|
| `send()` — sucesso | Mock `EnvResolver` + `AuthResolver` + `HTTPClient` retornando Response. Verificar `response != nil`, `isLoading == false` |
| `send()` — URL inválida | Mock `EnvResolver` lançando `RequestError.invalidURL`. Verificar `error` é `RequestError` |
| `send()` — token expirado | Mock `AuthResolver` lançando `AuthError.tokenExpired`. Verificar `error` é `AuthError` |
| `send()` — salva no histórico | Mock `ResponseRepository`. Verificar `save` chamado com `requestId` correto |
| `send()` — tab sem linkedRequestId | Verificar que `ResponseRepository.save` **não** é chamado |
| `cancelRequest()` | Duas tabs enviando ao mesmo tempo → cancelar uma não afeta a outra |
| `save()` — request novo | Verificar `tab.linkedRequestId` é preenchido após save |
| `save()` — request existente | Verificar que `toRequest(existingId:)` preserva o ID |
| Sync do draft para `Tab` | Modificar draft, verificar que `TabRepository.save()` recebe a tab atualizada |
| `isDirty` | Modificar draft, verificar que isDirty muda |

**Padrão de mock:**

```swift
final class MockHTTPClient: HTTPClient {
    var result: Result<Response, Error> = .failure(RequestError.cancelled)
    var executedRequest: ResolvedRequest?

    func execute(_ request: ResolvedRequest) async throws -> Response {
        executedRequest = request
        return try result.get()
    }
}
```

Cada mock armazena inputs recebidos (para assertions de chamada) e retorna valores configuráveis.

### Repositories — Testes de integração com SwiftData in-memory

Testam a implementação concreta (`SwiftDataRequestRepository`, etc.) contra um `ModelContainer` in-memory.

| O que testar | Exemplo |
|---|---|
| CRUD básico | save → fetchAll retorna o item |
| Cascade delete | Deletar collection remove requests e sub-collections |
| `ancestorChain` | Hierarquia de 3 níveis retorna cadeia correta |
| `ResponseRepository.save` com limite 50 | Salvar 51 responses → a mais antiga é descartada (RN-03) |
| `EnvironmentRepository.activate` | Ativar um desativa os demais (RN-02) |
| `TabRepository.cleanupOrphanedLinks` | Request deletado → linkedRequestId vira nil |
| Unicidade de EnvVariable key | Duas vars com mesma key no mesmo env → erro |

**Setup:**

```swift
func makeInMemoryContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: SchemaV1.self,
        configurations: [config]
    )
}
```

### Services — Testes unitários

| Service | O que testar | Tipo |
|---|---|---|
| `DefaultEnvResolver` | Substituição de `{{var}}` em URL, headers, body | Unitário puro |
| `DefaultEnvResolver` | `unresolvedKeys` retorna vars sem match | Unitário puro |
| `DefaultEnvResolver` | URL inválida após substituição → `RequestError.invalidURL` | Unitário puro |
| `DefaultEnvResolver` | Variável com `isEnabled = false` é ignorada | Unitário puro |
| `DefaultAuthResolver` | Cadeia com 3 níveis, auth no meio → retorna auth correta | Unitário com mock AuthService |
| `DefaultAuthResolver` | Toda cadeia inherit → retorna `.none` | Unitário puro |
| `DefaultAuthResolver` | OAuth2 com token expirado → tenta refresh | Unitário com mock AuthService |
| `URLSessionHTTPClient` | Request → Response com status/headers/body | Integração com URLProtocol mock |
| `URLSessionHTTPClient` | Cancelamento em voo retorna `.cancelled` | Integração com URLProtocol mock |
| `URLSessionHTTPClient` | Task pré-cancelada não inicia o protocolo mock | Integração com URLProtocol mock |
| `AppleKeychainService` | save/load/delete round-trip | Integração (Keychain de teste) |

**Mock de URLSession via URLProtocol:**

```swift
final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else { return }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
```

### Import/Export — Testes unitários com fixtures

| O que testar | Fixture |
|---|---|
| `PostmanImportParser.canParse` | JSON Postman válido vs. OpenAPI vs. lixo |
| `PostmanImportParser.parse` | Collection com hierarquia, auth, variáveis |
| `PostmanImportParser.parse` — warnings | Collection com pre-request scripts → warnings |
| `OpenAPIImportParser.parse` | OpenAPI 3.x com paths, servers, security |
| `PostmanExportSerializer.serialize` | Round-trip: import → export → import = mesmos dados |

Fixtures em `Tests/Fixtures/` — arquivos JSON/YAML reais e mínimos.

---

## 3. O que NÃO testar

- Views (SwiftUI puro sem lógica — coberto por UI tests manuais e previews).
- `DependencyContainer` (wiring trivial — testado indiretamente por testes dos ViewModels).
- Codable conformances gerados automaticamente pelo compilador (structs simples como `Header`, `FormField`). Enums com associated values (`RequestBody`, `AuthConfig`) têm encoding manual e **devem** ser testados (seção 2).
- Getters/setters triviais.

---

## 4. Organização de arquivos

```
appiTests/
├── Domain/
│   └── Models/
│       ├── RequestDraftTests.swift
│       ├── PreparedRequestTests.swift
│       └── AuthConfigTests.swift
├── Presentation/
│   └── ViewModels/
│       ├── RequestEditorViewModelTests.swift
│       ├── CollectionTreeViewModelTests.swift
│       └── EnvironmentViewModelTests.swift
├── Data/
│   ├── Repositories/
│   │   ├── RequestRepositoryTests.swift
│   │   ├── CollectionRepositoryTests.swift
│   │   ├── ResponseRepositoryTests.swift
│   │   ├── EnvironmentRepositoryTests.swift
│   │   └── TabRepositoryTests.swift
│   └── Services/
│       ├── EnvResolverTests.swift
│       ├── AuthResolverTests.swift
│       ├── HTTPClientTests.swift
│       └── KeychainServiceTests.swift
├── Import/
│   ├── PostmanImportParserTests.swift
│   └── OpenAPIImportParserTests.swift
├── Export/
│   └── PostmanExportSerializerTests.swift
├── Mocks/
│   ├── MockRequestRepository.swift
│   ├── MockCollectionRepository.swift
│   ├── MockResponseRepository.swift
│   ├── MockEnvironmentRepository.swift
│   ├── MockHTTPClient.swift
│   ├── MockEnvResolver.swift
│   ├── MockAuthResolver.swift
│   ├── MockAuthService.swift
│   └── MockKeychainService.swift
└── Fixtures/
    ├── postman-collection-basic.json
    ├── postman-collection-with-scripts.json
    ├── openapi-petstore.json
    └── openapi-with-security.yaml
```

---

## 5. Convenções Swift Testing

```swift
import Testing

struct RequestDraftTests {
    @Test("Draft vazio tem método GET e auth inheritFromParent")
    func emptyDraftDefaults() {
        let draft = RequestDraft.empty(in: UUID())

        #expect(draft.method == .get)
        #expect(draft.body == .none)
        #expect(draft.auth == .inheritFromParent)
        #expect(draft.headers.isEmpty)
    }

    @Test("toRequest() gera ID único")
    func toRequestGeneratesUniqueId() {
        let draft = RequestDraft.empty(in: UUID())
        let r1 = draft.toRequest()
        let r2 = draft.toRequest()

        #expect(r1.id != r2.id)
    }

    @Test("toRequest(existingId:) preserva o ID")
    func toRequestPreservesId() {
        let draft = RequestDraft.empty(in: UUID())
        let existingId = UUID()
        let request = draft.toRequest(existingId: existingId)

        #expect(request.id == existingId)
    }
}
```

**Regras:**
- `@Test("descrição legível")` em todo teste.
- `#expect()` em vez de `XCTAssert`.
- `#require()` para pré-condições que, se falharem, invalidam o teste.
- `@Suite` para agrupar testes relacionados quando necessário.
- Sem `setUp`/`tearDown` — cada teste constrói o que precisa.

---

*Ver também: `architecture.md` (protocols de mock), `coding-conventions.md`*
