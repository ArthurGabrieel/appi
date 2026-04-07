# Appi — UI e Navegação

> Plataforma: macOS 14+  
> Framework: SwiftUI  
> Referência: Postman desktop  
> Ver também: `requirements.md`, `architecture.md`

---

## 1. Estrutura da janela principal

Layout de 2 colunas com `NavigationSplitView`:

```
┌─────────────────────────────────────────────────────────────────────┐
│  Menu bar (Commands {} do App struct — atalhos registrados aqui)    │
├──────────────┬──────────────────────────────────────────────────────┤
│              │  ┌─────┬─────┬─────┬───┐                            │
│   Sidebar    │  │ Tab1│ Tab2│ Tab3│ + │  ← Tab bar                 │
│              │  ├─────┴─────┴─────┴───┴────────────────────────────┤
│  ┌────────┐  │  │                                                  │
│  │ 🔍 Search│  │  │  URL bar: [GET ▼] [{{baseUrl}}/users    ] [Send]│
│  ├────────┤  │  │                                                  │
│  │        │  │  ├──────────────────────────────────────────────────┤
│  │ My     │  │  │  [Params] [Headers] [Body] [Auth]               │
│  │ Collect │  │  │                                                  │
│  │  ├ GET  │  │  │  ┌────────────────────────────────────────────┐ │
│  │  ├ POST │  │  │  │  Request editor (conteúdo da aba ativa)   │ │
│  │  └ PUT  │  │  │  │                                            │ │
│  │        │  │  │  └────────────────────────────────────────────┘ │
│  │ Auth   │  │  ├──────────────────────────────────────────────────┤
│  │  └ GET  │  │  │  [Body] [Headers] [History]                    │
│  │        │  │  │                                                  │
│  ├────────┤  │  │  ┌────────────────────────────────────────────┐ │
│  │ Env:   │  │  │  │  Response viewer                           │ │
│  │[Prod ▼]│  │  │  │  200 OK — 142ms — 3.2 KB                  │ │
│  └────────┘  │  │  │  { "users": [...] }                        │ │
│              │  │  └────────────────────────────────────────────┘ │
├──────────────┴──┴──────────────────────────────────────────────────┤
│  Status bar: erros inline / loading indicator                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Hierarquia de Views

```
AppiApp (@main)
└── ContentView
    └── NavigationSplitView
        ├── SidebarView
        │   ├── SearchField
        │   ├── CollectionTreeView (recursive)
        │   │   ├── CollectionRow (disclosure group)
        │   │   │   ├── CollectionRow (sub-collection, recursivo)
        │   │   │   └── RequestRow
        │   │   └── RequestRow
        │   └── EnvironmentPicker
        │
        └── DetailView
            ├── TabBarView
            │   ├── TabItemView (por tab)
            │   └── NewTabButton
            │
            ├── RequestEditorView (tab ativa)
            │   ├── URLBarView (método + URL + botão Send)
            │   ├── RequestSegmentedControl (Params/Headers/Body/Auth)
            │   ├── HeadersEditorView
            │   ├── BodyEditorView
            │   │   ├── RawBodyEditor (com ContentTypePicker)
            │   │   └── FormDataEditor (campos text + file)
            │   └── AuthEditorView
            │       ├── AuthTypePicker
            │       ├── BasicAuthFields
            │       ├── BearerTokenField
            │       ├── OAuth2ConfigFields + GetTokenButton
            │       └── InheritedAuthPreview (read-only)
            │
            ├── ResponseViewerView
            │   ├── ResponseSegmentedControl (Body/Headers/History)
            │   ├── ResponseBodyView (pretty-print JSON, syntax highlight)
            │   ├── ResponseHeadersView
            │   └── ResponseHistoryView
            │       └── ResponseHistoryRow
            │
            └── EmptyStateView (quando não há tabs)

Modais / Sheets:
├── ImportSheet (file picker + relatório de warnings)
├── ExportSheet (file picker + opções)
├── EnvironmentEditorSheet
│   └── EnvVariableRow (key/value/secret/enabled)
├── DeleteConfirmationAlert (collection, request)
└── DirtyTabConfirmationAlert
```

---

## 3. ViewModel ↔ View mapping

| ViewModel | View(s) | Responsabilidade |
|---|---|---|
| `CollectionTreeViewModel` | `SidebarView`, `CollectionTreeView` | CRUD collections/requests, drag-and-drop, busca |
| `RequestEditorViewModel` | `RequestEditorView`, subviews | Draft editing, send, save |
| `TabBarViewModel` | `TabBarView`, `TabItemView` | Gestão de tabs, seleção, dirty state, restauração |
| `EnvironmentViewModel` | `EnvironmentPicker`, `EnvironmentEditorSheet` | CRUD environments, ativar/desativar, variáveis |
| `ResponseViewModel` | `ResponseViewerView`, `ResponseHistoryView` | Response atual, histórico, formatação |
| `ImportViewModel` | `ImportSheet` | Parse de arquivo, exibição de warnings, confirmação |
| `ExportViewModel` | `ExportSheet` | Serialização, file picker, opções |

**Regra:** cada ViewModel é criado via `DependencyContainer.make*()`. Views acessam o container via `@Environment(DependencyContainer.self)`.

---

## 4. Fluxos de navegação

### 4.1 First launch
```
App abre → Workspace default criado → Collection "My Collection" criada
→ Tab vazia com "New Request" aberta → Foco na URL bar
```

### 4.2 Abrir request existente
```
Clique em RequestRow na sidebar
→ Se já aberto em tab: ativa a tab existente
→ Se não: cria nova Tab com draft = RequestDraft.from(request)
→ Tab ativada, editor carrega draft
```

### 4.3 Executar request
```
⌘ Return (ou clique em Send)
→ Loading spinner no botão Send
→ EnvResolver.resolve(draft, environment)
  → URL vazia ou inválida após substituição? → RequestError.invalidURL → erro na aba de response
→ AuthResolver.resolve(auth, chain)
  → Token expirado e refresh falhou? → AuthError.tokenExpired → erro na aba de auth
→ HTTPClient.execute(resolved) → Response exibida no ResponseViewer
→ Se tab tem linkedRequestId: salva no histórico
```

### 4.4 Fechar tab dirty
```
⌘ W (ou clique no X da tab)
→ Tab tem linkedRequestId E isDirty?
  → Sim: Alert "Salvar alterações?" [Salvar / Descartar / Cancelar]
  → Não (draft novo sem linkedRequestId): descarta silenciosamente
→ Última tab fechada? → EmptyStateView
```

### 4.5 Import
```
⌘ ⇧ I → File picker (.json, .yaml)
→ Detecção automática de formato (Postman vs OpenAPI)
→ Parse → ImportSheet com resumo:
  "12 requests importados, 3 collections criadas, 2 items ignorados"
  Lista de warnings
→ Confirmar → Dados salvos → Sidebar atualizada
```

### 4.6 OAuth2 — obter token
```
Auth tab → OAuth2 selecionado → Preencher config
→ Clique "Get Token" → ASWebAuthenticationSession abre browser
→ Usuário autoriza → Callback com code
→ Troca code por token → TokenSet salvo no Keychain
→ Badge "Token obtained" na aba de auth
```

### 4.7 OAuth2 — token expirado durante send
```
send() → AuthResolver detecta token expirado
→ Tenta refresh silencioso
  → Sucesso: continua com novo token
  → Falha: AuthError.tokenExpired
→ Erro inline na aba de auth: "Token expirado. [Re-authorize]"
```

---

## 5. Estados da UI

### EmptyStateView (sem tabs)
- Ícone + texto "Abra um request ou crie um novo"
- Botão "New Request" (`⌘ T`)
- Atalhos visíveis: `⌘ N` (novo request), `⌘ ⇧ I` (import)

### Loading state (request em andamento)
- Botão Send vira "Cancel" com spinner
- Tab mostra indicador de loading sutil
- `⌘ .` cancela

### Error state
- Erros de request (rede, timeout, SSL, URL inválida): banner na aba de response
- Erros de auth (token expirado, refresh falhou): inline na aba de auth
- Erros de persistência: banner no topo do editor
- Dismissível com clique ou auto-dismiss após 5s (exceto erros de auth que requerem ação)

### Dirty state
- Tab mostra indicador visual (ponto ou cor diferente no título)
- `⌘ S` salva, indicador desaparece

---

## 6. Atalhos e menu bar

Todos os atalhos registrados via `Commands {}` no App struct — aparecem nos menus macOS nativos.

Ver tabela completa em `requirements.md` seção RF-08.

**Menu structure:**
```
File
├── New Request         ⌘N
├── New Collection      ⌘⇧N
├── New Tab             ⌘T
├── Close Tab           ⌘W
├── Save                ⌘S
├── Duplicate Request   ⌘D
├── ─────────────
├── Import...           ⌘⇧I
└── Export...           ⌘⇧E

Edit
├── Copy URL            ⌘⇧C
└── Rename              ↩

View
├── Toggle Sidebar      ⌘⇧S
├── Focus URL Bar       ⌘L
└── Find in Sidebar     ⌘F

Request
├── Send                ⌘↩
└── Cancel              ⌘.

Window
├── Next Tab            ⌘⇧]
├── Previous Tab        ⌘⇧[
└── Tab 1...9           ⌘1...⌘9
```

---

*Ver também: `requirements.md`, `architecture.md`, `coding-conventions.md`*
