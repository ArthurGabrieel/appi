# Appi — Domain

> Modelos, value objects e regras por entidade  
> Ver também: `architecture.md`, `requirements.md`

---

## 1. Entidades

### 1.1 Workspace
Raiz. Agrupa collections e environments. Na v1.0, único e implícito — criado automaticamente no primeiro launch.

**Atributos**
- `id: UUID`
- `name: String`
- `createdAt: Date`

**Regras**
- Todo request pertence indiretamente a um workspace via collection.
- Nome não pode ser vazio.
- Deleção faz cascade em collections, sub-collections, requests, responses e environments (RN-10).
- Na v1.0 não pode ser deletado (RN-14).

---

### 1.2 Collection
Organização hierárquica de requests. Suporta sub-pastas (auto-referência).

**Atributos**
- `id: UUID`
- `name: String`
- `parentId: UUID?` — `nil` = raiz do workspace
- `sortIndex: Int`
- `workspaceId: UUID`
- `auth: AuthConfig` — default depende do nível (ver regras)
- `createdAt: Date`
- `updatedAt: Date`

**Regras**
- Máximo 5 níveis de profundidade (RN-05).
- Deleção em cascade completo: remove todas as sub-collections descendentes, seus requests e responses associadas (RN-10).
- Nome não pode ser vazio.
- Collections raiz (`parentId == nil`) nascem com `auth = .none`. A opção `Inherit from parent` não é oferecida na UI para collections raiz (RN-11).
- Sub-collections (`parentId != nil`) nascem com `auth = .inheritFromParent`.

---

### 1.3 Request
Entidade central do domínio.

**Atributos**
- `id: UUID`
- `name: String`
- `method: HTTPMethod`
- `url: String` — pode conter variáveis `{{baseUrl}}`
- `headers: [Header]`
- `body: RequestBody`
- `auth: AuthConfig` — `inheritFromParent` por padrão (RN-12)
- `collectionId: UUID`
- `sortIndex: Int` — posição dentro da collection pai
- `createdAt: Date`
- `updatedAt: Date`

**Regras**
- URL vazia é permitida no draft, mas não ao executar (RN-04).
- Método padrão é `GET`.
- Headers preservam o case original para exibição.
- Request pode existir sem body (GET, HEAD).

---

### 1.4 Response
Gerada após execução. Imutável após criação.

**Atributos**
- `id: UUID`
- `statusCode: Int`
- `statusMessage: String`
- `headers: [Header]`
- `body: Data`
- `contentType: String?` — extraído dos response headers para facilitar o viewer
- `duration: TimeInterval` — segundos (padrão Swift). UI exibe formatado em milissegundos
- `size: Int` — bytes
- `createdAt: Date`

> `requestId` não faz parte da entidade de domínio. O `HTTPClient` retorna uma `Response` sem vínculo — ela pode ser exibida mesmo sem request salvo (tabs com drafts não persistidos). O vínculo `Response ↔ Request` é responsabilidade exclusiva do `ResponseRepository`, que recebe o `requestId` no momento de persistir (ver `save(_ response:, forRequestId:)` em architecture.md).

**Regras**
- Imutável após salva.
- `contentType` é extraído do header `Content-Type` no momento da criação — usado pelo viewer para decidir pretty-print (JSON), syntax highlight (HTML/XML) ou exibição binária.
- Histórico limitado a 50 por request — as mais antigas são descartadas automaticamente (RN-03). O vínculo por request é gerenciado pelo `ResponseModel` na camada de persistência.

---

### 1.5 Environment
Conjunto de variáveis nomeado. Só um ativo por workspace.

**Atributos**
- `id: UUID`
- `name: String`
- `isActive: Bool`
- `workspaceId: UUID`
- `variables: [EnvVariable]`
- `createdAt: Date`
- `updatedAt: Date`

**Regras**
- Apenas um environment com `isActive = true` por workspace (RN-02).
- Ativar um desativa os demais — garantido no `EnvironmentRepository.activate()`.

---

### 1.6 EnvVariable

**Atributos**
- `id: UUID`
- `key: String`
- `value: String` — armazenado de forma segura quando `isSecret = true` (ver architecture.md)
- `isSecret: Bool`
- `isEnabled: Bool` — permite desabilitar temporariamente sem deletar
- `environmentId: UUID`

**Regras**
- Chaves únicas por environment (case-sensitive) (RN-08).
- Variáveis secretas nunca aparecem em logs ou exports (RN-01).
- Variáveis com `isEnabled = false` são ignoradas na resolução de `{{variáveis}}`.

---

### 1.7 Tab
Entidade persistida. Restauração completa ao reabrir o app (ver architecture.md para detalhes de persistência).

**Atributos**
- `id: UUID`
- `linkedRequestId: UUID?` — `nil` = request novo, ainda não salvo
- `draft: RequestDraft` — estado completo da edição, persistido
- `sortIndex: Int` — ordem das tabs na barra
- `isActive: Bool` — qual tab está selecionada
- `createdAt: Date`

**Propriedades computadas**
- `isDirty: Bool` — `true` quando draft difere do request salvo

**Regras**
- Restauração completa ao reabrir o app, incluindo drafts com mudanças não salvas.
- `isDirty = true` quando draft difere do request salvo.
- Fechar tab dirty com `linkedRequestId != nil` exige confirmação (RN-07).
- Fechar tab dirty sem `linkedRequestId` descarta silenciosamente.
- Request vinculado deletado → tab vira draft órfão (`linkedRequestId = nil`) sem perder conteúdo (RN-17).
- Fechar última tab → empty state com botão "New Request".

---

### 1.8 Ordenação da sidebar

A sidebar exibe sub-collections e requests intercalados no mesmo nível, como o Postman. Ambos possuem `sortIndex: Int` relativo ao pai.

A View constrói a lista mesclando sub-collections e requests do mesmo `parentId`/`collectionId`, ordenando todos por `sortIndex`. Drag-and-drop atualiza os `sortIndex` de ambos os tipos.

> `sortIndex` é um inteiro relativo — ao reordenar, os índices dos irmãos são recalculados sequencialmente (0, 1, 2, ...).

---

## 2. Value objects

```swift
// HTTPMethod
enum HTTPMethod: String, Codable, CaseIterable {
    case get = "GET", post = "POST", put = "PUT"
    case patch = "PATCH", delete = "DELETE"
    case head = "HEAD", options = "OPTIONS"
}

// Header — ordem relevante, usa OrderedDictionary internamente
struct Header: Codable, Equatable, Identifiable {
    let id: UUID
    var key: String
    var value: String
    var isEnabled: Bool
}

// FormFieldValue — suporta text e file upload
enum FormFieldValue: Codable, Equatable {
    case text(String)
    case file(fileName: String, mimeType: String, data: Data)
}

// FormField
struct FormField: Codable, Equatable, Identifiable {
    let id: UUID
    var key: String
    var value: FormFieldValue
    var isEnabled: Bool
}

// RequestBody
enum RequestBody: Codable {
    case none
    case raw(String, contentType: String)   // contentType: "application/json", "text/xml", etc.
    case formData([FormField])               // multipart/form-data com text e file
}

// AuthConfig — usado em Request e Collection para definição de auth
enum AuthConfig: Codable {
    case inheritFromParent   // herda da collection pai (default em requests e collections novas)
    case none                // sem autenticação — explicitamente desativado (RN-13)
    case basic(username: String, password: String)
    case bearer(token: String)
    case oauth2(OAuth2Config)
}

// ResolvedAuth — output do AuthResolver, nunca contém .inheritFromParent
// Usa tipo separado para garantir por sistema de tipos que a auth foi resolvida
enum ResolvedAuth: Codable {
    case none
    case basic(username: String, password: String)
    case bearer(token: String)
    case oauth2(OAuth2Config, tokenSet: TokenSet)
}

// OAuth2Config
struct OAuth2Config: Codable, Equatable {
    var authURL: String
    var tokenURL: String
    var clientId: String
    var clientSecret: String?   // nil = public client, preenchido = confidential client
    var scopes: [String]
    var redirectURI: String
}

// TokenSet — armazenado de forma segura, nunca em persistência genérica (RN-09)
struct TokenSet: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
}

// RequestDraft — cópia mutável usada nas tabs, persistida junto com a Tab
struct RequestDraft: Codable, Equatable {
    var name: String
    var method: HTTPMethod
    var url: String
    var headers: [Header]
    var body: RequestBody
    var auth: AuthConfig
    var collectionId: UUID

    static func empty(in collectionId: UUID) -> RequestDraft {
        RequestDraft(
            name: "New Request",
            method: .get,
            url: "",
            headers: [],
            body: .none,
            auth: .inheritFromParent,
            collectionId: collectionId
        )
    }

    static func from(_ request: Request) -> RequestDraft { ... }

    /// Cria novo Request a partir do draft (para salvar pela primeira vez)
    func toRequest() -> Request { ... }

    /// Atualiza Request existente preservando o ID (para updates)
    func toRequest(existingId: UUID) -> Request { ... }
}

// PreparedRequest — output do EnvResolver
// Variáveis resolvidas, mas auth ainda não resolvida
struct PreparedRequest {
    let method: HTTPMethod
    let url: URL
    let headers: [Header]
    let body: RequestBody

    func withAuth(_ auth: ResolvedAuth) -> ResolvedRequest {
        ResolvedRequest(method: method, url: url, headers: headers, body: body, auth: auth)
    }
}

// ResolvedRequest — input do HTTPClient
// Totalmente resolvido: variáveis substituídas + auth concreta
struct ResolvedRequest {
    let method: HTTPMethod
    let url: URL
    let headers: [Header]
    let body: RequestBody
    let auth: ResolvedAuth
}

// ImportResult — output do ImportParser
struct ImportResult {
    let collections: [Collection]     // suporta hierarquia de sub-collections
    let requests: [Request]
    let environments: [Environment]   // variáveis de collection Postman, servers OpenAPI, etc.
    let warnings: [ImportWarning]     // features não suportadas que foram ignoradas
}

struct ImportWarning {
    let item: String    // nome do request/collection afetado
    let reason: String  // ex: "pre-request script ignorado"
}
```

---

## 3. Herança de auth — cadeia de resolução

A auth é resolvida pelo `AuthResolver` em cascata, do request até a collection raiz, retornando a primeira `AuthConfig` concreta encontrada. O resultado é sempre um `ResolvedAuth` (nunca `AuthConfig`).

O `AuthResolver` recebe a cadeia completa de collections via `CollectionRepository.ancestorChain(for:)`.

```
Request.auth
  └── se .inheritFromParent → Collection direta.auth
        └── se .inheritFromParent → Collection pai.auth
              └── se .inheritFromParent → ... → Collection raiz.auth (sempre concreta, nunca .inheritFromParent)
```

**Exemplos:**

| Request.auth | Collection A (sub).auth | Collection B (raiz).auth | Auth efetiva |
|---|---|---|---|
| `.inheritFromParent` | `.inheritFromParent` | `.bearer("token")` | `.bearer("token")` |
| `.inheritFromParent` | `.basic("u","p")` | `.bearer("token")` | `.basic("u","p")` |
| `.none` | `.bearer("token")` | — | `.none` |
| `.bearer("x")` | `.basic("u","p")` | — | `.bearer("x")` |
| `.inheritFromParent` | `.inheritFromParent` | `.none` | `.none` |

> Nota: a última linha é o caso mais comum — toda a cadeia herda e a raiz tem `.none` (default de collections raiz). Não existe `.inheritFromParent` em collection raiz.

**Regra:** `AuthResolver` é chamado sempre antes de `HTTPClient.execute()`. A View exibe a auth efetiva em modo read-only quando o tipo selecionado é `Inherit from parent`.

---

## 4. Domínio de erros

```swift
enum RequestError: Error, LocalizedError {
    case invalidURL(String)
    case networkError(URLError)
    case timeout
    case cancelled
    case sslError(String)
}

enum AuthError: Error, LocalizedError {
    case tokenExpired
    case refreshFailed(Error)
    case authorizationDenied
    case invalidConfiguration(String)
}

enum ImportError: Error, LocalizedError {
    case unsupportedFormat
    case corruptedFile(String)
    case parseFailed(String)
}

enum PersistenceError: Error, LocalizedError {
    case saveFailed(Error)
    case fetchFailed(Error)
    case migrationFailed(Error)
}
```

Todos os enums implementam `LocalizedError` com `errorDescription` localizado (pt-BR, en).

---

*Ver também: `architecture.md`, `requirements.md`*
