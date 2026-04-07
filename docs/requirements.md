# Appi — Requisitos

> Projeto: **Appi** — cliente HTTP nativo para macOS em SwiftUI  
> Versão: 1.0 — escopo MVP+

---

## 1. Visão geral

Appi é um cliente HTTP nativo para macOS 14+ para criação, organização e execução de requisições HTTP. Foco em experiência nativa de primeira classe: integração com Keychain, Spotlight, atalhos de teclado e NavigationSplitView.

Referência de UX: **Postman** — seguimos seus padrões de interação como benchmark, adaptando para experiência nativa Apple.

---

## 2. Stack e ferramentas

### Plataforma

| Item | Decisão |
|---|---|
| Linguagem | Swift 5.10+ |
| UI | SwiftUI |
| Persistência | SwiftData (macOS 14+) |
| Concorrência | Swift Concurrency (async/await, Actor, @ModelActor) |
| Rede | URLSession nativo |
| Secrets | Keychain via Security framework |
| Testes | Swift Testing (novo framework Apple) |
| Linting | SwiftLint |
| Localização | String Catalogs (.xcstrings) — pt-BR e en |
| CI | Xcode Cloud ou GitHub Actions com `xcodebuild` |

### Dependências externas (mínimo intencional)

| Lib | Uso | Justificativa |
|---|---|---|
| `OpenAPIKit` | Parse de OpenAPI 3.x no import | Evita reimplementar `$ref` resolver |
| `swift-collections` | `OrderedDictionary` para headers | Headers têm ordem relevante |

> Regra do projeto: sem dependências para networking, autenticação ou UI. Tudo nativo.

---

## 3. Requisitos funcionais

### RF-01 — Request builder
- Seletor de método HTTP (GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS).
- Campo de URL com resolução inline de variáveis (highlight amarelo para vars não encontradas).
- Editor de headers chave/valor com toggle enable/disable por linha.
- Editor de body com três modos:
  - `none` — sem body.
  - `raw` — editor de texto com seletor de content-type (JSON, XML, Text, HTML).
  - `form-data` — campos chave/valor com suporte a **text** e **file upload** (imagem, documento, etc.), com toggle enable/disable por campo.
- Aba de autenticação: `Inherit from parent`, `No Auth`, Basic, Bearer, OAuth2 com PKCE.
- Quando `Inherit from parent`, exibir em modo somente-leitura a auth efetiva resolvida da cadeia pai.

> Fora de escopo v1.0: `x-www-form-urlencoded` e `binary` como tipos de body.

### RF-02 — Execução e resposta
- Executar request com feedback de loading e cancelamento.
- Exibir status code, tempo de resposta e tamanho em bytes.
- Viewer de response body com pretty-print JSON e syntax highlight.
- Viewer de response headers.
- Histórico das últimas 50 responses por request, acessível via aba "History" no painel de response:
  - Cada entrada exibe: status code, método, duração e data/hora.
  - Clicar em uma entrada carrega a response completa no viewer (read-only).
  - Sem comparação entre responses na v1.0.
  - Sem delete individual — limpeza automática pelo limite de 50.

### RF-03 — Collections e organização
- Sidebar com árvore hierárquica de collections e requests.
- Criar, renomear, mover e deletar collections e requests.
- Drag-and-drop para reordenar.
- Busca por nome de request e de collection.

### RF-04 — Tabs múltiplas
- Barra de tabs no topo do painel central.
- Abrir qualquer request em nova tab.
- Indicador visual de tab com mudanças não salvas (`isDirty`).
- Tabs persistidas via SwiftData — restauração completa ao reabrir o app, incluindo drafts com mudanças não salvas.
- Fechar última tab → exibir empty state com botão "New Request" e atalho `⌘ T`.
- Se o request vinculado a uma tab foi deletado entre sessões → tab vira draft órfão (`linkedRequestId = nil`) sem perder o conteúdo.
- Sem limite máximo de tabs — sistema gerencia memória.

### RF-05 — Environments e variáveis
- Criar múltiplos environments (vinculados ao workspace implícito).
- Ativar/desativar environment globalmente.
- Editor de variáveis com suporte a:
  - Toggle enable/disable por variável (sem deletar).
  - Valores secretos (mascarados na UI, armazenados no Keychain).
- Resolução de `{{variável}}` em URL, headers e body antes de executar.

### RF-06 — Autenticação
- Seletor de tipo com as opções: `Inherit from parent`, `No Auth`, `Basic Auth`, `Bearer Token`, `OAuth2`.
- `Inherit from parent`: exibe em read-only a auth efetiva herdada da cadeia (collection pai, avó, etc.).
- Basic Auth: username + password.
- Bearer Token: campo de token livre.
- OAuth2 com PKCE:
  - Grant type: Authorization Code com PKCE exclusivamente.
  - Suporta public client (sem `clientSecret`) e confidential client (com `clientSecret` opcional).
  - Fluxo: usuário preenche config → clica "Get Token" → `ASWebAuthenticationSession` abre → callback com code → troca por token.
  - Refresh automático silencioso: antes de executar, se token expirado e refresh token disponível, tenta refresh.
  - Se refresh falhar ou token revogado: erro inline na aba de auth com botão "Re-authorize".
  - Tokens armazenados no Keychain, vinculados por chave derivada do `clientId + authURL`.
- Collections também possuem aba de autenticação. Sub-collections oferecem todas as opções; collections raiz oferecem apenas `No Auth`, `Basic Auth`, `Bearer Token` e `OAuth2` (sem `Inherit from parent`).

### RF-07 — Import / Export

**Import Postman Collection v2.1 (`.json`):**
- Importa: collections (com hierarquia), requests, headers, body, auth (Basic, Bearer, OAuth2), variáveis de collection.
- Ignora com warning: pre-request scripts, test scripts, eventos, monitors, mock servers.
- Variáveis de collection Postman → `EnvVariable` em um environment nomeado "[Collection Name] Variables".
- Detecção automática de formato.

**Import OpenAPI 3.x (`.json` ou `.yaml`):**
- Cada path+method vira um request.
- Servers → variável `{{baseUrl}}` no environment criado.
- Security schemes → auth config nos requests quando mapeável (Bearer, Basic).
- Ignora com warning: schemas/models, webhooks, callbacks, links, examples complexos.
- Requests agrupados por tag em sub-collections. Sem tag → collection "Ungrouped".

**Export Postman v2.1:**
- Exporta: collections, requests, headers, body, auth (Basic, Bearer).
- OAuth2 → exporta a config (URLs, clientId, scopes) sem tokens.
- Variáveis secretas excluídas por padrão (RN-06).

**Relatório pós-import:**
- Sheet com resumo: "N requests importados, M collections criadas, X items ignorados".
- Lista detalhada dos warnings com item afetado e motivo.

### RF-08 — Atalhos de teclado

Implementados via `.keyboardShortcut()` no SwiftUI.

#### Execução
| Ação | Atalho |
|---|---|
| Enviar request | `⌘ Return` |
| Cancelar request em andamento | `⌘ .` |

#### Tabs
| Ação | Atalho |
|---|---|
| Nova tab vazia | `⌘ T` |
| Fechar tab ativa | `⌘ W` |
| Próxima tab | `⌘ ⇧ ]` ou `⌃ Tab` |
| Tab anterior | `⌘ ⇧ [` ou `⌃ ⇧ Tab` |
| Ir para tab N (1–9) | `⌘ 1` … `⌘ 9` |

#### Navegação
| Ação | Atalho |
|---|---|
| Foco na barra de URL | `⌘ L` |
| Buscar na sidebar | `⌘ F` |
| Alternar sidebar | `⌘ ⇧ S` |
| Novo request na collection selecionada | `⌘ N` |
| Nova collection | `⌘ ⇧ N` |

#### Edição
| Ação | Atalho |
|---|---|
| Salvar request | `⌘ S` |
| Duplicar request selecionado | `⌘ D` |
| Renomear item selecionado na sidebar | `Return` (com item em foco) |
| Deletar item selecionado | `⌫` (com item em foco) |

#### Utilitários
| Ação | Atalho |
|---|---|
| Copiar URL do request ativo | `⌘ ⇧ C` |
| Importar collection | `⌘ ⇧ I` |
| Exportar collection selecionada | `⌘ ⇧ E` |

**Regras de implementação**
- Todos os atalhos registrados no `Commands {}` do `App` struct para aparecerem no menu macOS.
- Atalhos conflitantes com o sistema (`⌘ Q`, `⌘ H`) nunca são sobrescritos.

- Atalhos `⌘ 1`…`⌘ 9` são desabilitados dinamicamente quando não há tab correspondente.

### RF-09 — First launch
- Primeiro launch cria workspace default e uma collection "My Collection" vazia.
- Abre uma tab vazia com "New Request" pronto para editar.
- Sem onboarding ou tutorial — a interface é autoexplicativa seguindo padrões do Postman.

---

## 4. Regras de negócio

| # | Regra |
|---|---|
| RN-01 | Variáveis secretas nunca aparecem em plaintext em logs, exports ou snapshots de UI. |
| RN-02 | Apenas um environment ativo por workspace — garantido no `EnvironmentRepository.activate()`. |
| RN-03 | Histórico de responses limitado a 50 por request — garantido no `ResponseRepository.save()`. |
| RN-04 | Execução requer URL não vazia após resolução de variáveis. |
| RN-05 | Collections suportam no máximo 5 níveis de aninhamento. |
| RN-06 | Export exclui valores de variáveis secretas por padrão. |
| RN-07 | Fechar tab dirty vinculada a request existente exige confirmação. |
| RN-08 | Chaves de `EnvVariable` são únicas por environment (case-sensitive). |
| RN-09 | Tokens OAuth2 ficam no Keychain — nunca no SwiftData. |
| RN-10 | Deleção em cascade: workspace remove collections, sub-collections, requests, responses e environments. Deleção de collection remove todas as sub-collections descendentes, requests e responses. |
| RN-11 | Auth é resolvida em cascata do request até a collection raiz. Collections raiz nascem com `auth = .none` e não oferecem `Inherit from parent` na UI. Resolvido pelo `AuthResolver` antes de executar — nunca na View. |
| RN-12 | Requests novos têm `auth = .inheritFromParent` por padrão. |
| RN-13 | A opção `none` é explícita — significa "sem auth", não "herdar". |
| RN-14 | Workspace default é criado automaticamente no primeiro launch e não pode ser deletado na v1.0. |
| RN-15 | OAuth2 — refresh automático silencioso antes de executar. Se falhar, erro inline com opção de re-autorização manual. |
| RN-16 | Import exibe relatório com warnings de features ignoradas. Nunca falha silenciosamente. |
| RN-17 | Tab cujo request vinculado foi deletado vira draft órfão sem perder conteúdo. |

---

## 5. Requisitos não funcionais

| # | Requisito | Meta |
|---|---|---|
| RNF-01 | Cold start | < 400ms até primeiro frame interativo (sidebar + editor visíveis e responsivos) |
| RNF-02 | Execução de request simples (sem auth) | < 50ms de overhead no app |
| RNF-03 | Parse de collection Postman com 500 requests | < 2s |
| RNF-04 | Cobertura de testes em ViewModels, repositories e services | ≥ 80% |
| RNF-05 | Suporte a macOS | 14.0+ (nativo) |
| RNF-06 | Sem crash em response body > 10MB | App exibe response sem crash, sem freezar a UI por mais de 1s |
| RNF-07 | Modo offline | app abre e navega collections sem rede |
| RNF-08 | Localização | Todas as strings de UI via `String(localized:)`. Idiomas: pt-BR, en |
| RNF-09 | Acessibilidade | Toda View com `accessibilityLabel`, suporte a Dynamic Type e VoiceOver desde o Sprint 1 |

---

## 6. Tratamento de erros

Erros são sempre apresentados **inline no contexto** onde ocorreram:

| Contexto | Apresentação |
|---|---|
| Erros de request (rede, timeout, SSL, URL inválida) | Banner na aba de response |
| Erros de auth (token expirado, refresh falhou) | Inline na aba de autenticação |
| Erros de import (formato inválido, arquivo corrompido) | Relatório na sheet de import |
| Erros de persistência | Banner no topo do editor |

Alerts modais são reservados exclusivamente para **confirmação de ações destrutivas** (deletar collection, fechar tab dirty).

---

## 7. Fora de escopo (v1.0)

- WebSocket / SSE streaming
- Script runner pré/pós request (JavaScript sandbox)
- gRPC e GraphQL
- Proxy/interceptor de tráfego externo
- Colaboração em tempo real
- Sync entre contas (somente iCloud Drive para backup manual)
- Testes automatizados de API (assertions pós-response)
- Multi-workspace (infra de dados pronta, sem UI)
- Body types: `x-www-form-urlencoded` e `binary`
- Comparação entre responses no histórico

---

## 8. Ordem de implementação sugerida

```
Sprint 1 — Core funcional
  ├── Setup: String Catalogs (pt-BR, en), DependencyContainer, SchemaV1
  ├── Domain: models + repository protocols
  ├── Data: SwiftDataRequestRepository + SwiftDataCollectionRepository (@ModelActor)
  ├── Data/Services: HTTPClient + EnvResolver + KeychainService
  ├── Presentation: RequestEditorViewModel + RequestEditorView
  └── Presentation: ResponseViewer
  └── Regra transversal: accessibilityLabel + Dynamic Type em toda View

Sprint 2 — Organização
  ├── CollectionRepository + CollectionTree (sidebar)
  ├── Drag-and-drop na sidebar
  ├── TabBarViewModel + Tab (@Model SwiftData) + restauração de estado
  ├── Busca por request
  └── RF-09: first launch (workspace default + collection vazia)

Sprint 3 — Auth + Environments
  ├── EnvironmentRepository + EnvironmentViewModel
  ├── AuthResolver: Basic + Bearer (resolução direta) + cascata com ancestorChain
  ├── AuthService: OAuth2 com PKCE (ASWebAuthenticationSession)
  └── EnvResolver integrado na UI (highlight de vars não encontradas)

Sprint 4 — Import / Export
  ├── PostmanImportParser (implements ImportParser → ImportResult)
  ├── OpenAPIImportParser (implements ImportParser, usa OpenAPIKit)
  ├── PostmanExportSerializer (implements ExportSerializer)
  └── Relatório pós-import com warnings

Sprint 5 — Polimento
  ├── Atalhos de teclado (Commands + .keyboardShortcut)
  ├── SwiftLint + correções
  ├── Testes: ViewModels, repositories e services com mocks
  ├── Performance: response > 10MB, collections grandes
  └── VersionedSchema + SchemaMigrationPlan documentado para futuro
```

---

## 9. Glossário

| Termo | Definição |
|---|---|
| Workspace | Raiz organizacional. Agrupa collections e environments. Na v1.0, único e implícito. |
| Collection | Pasta hierárquica que agrupa requests e sub-collections. Até 5 níveis. |
| Request | Definição de uma requisição HTTP (método, URL, headers, body, auth). |
| Response | Resultado imutável de uma execução de request. |
| Environment | Conjunto nomeado de variáveis. Apenas um ativo por workspace. |
| Draft | Cópia mutável de um request usada na edição (tabs). Não é a entidade salva. |
| Tab | Aba do editor. Vinculada a um request salvo ou a um draft novo. Persistida via SwiftData. |
| Auth chain | Cadeia de herança de autenticação: request → collection → ... → collection raiz. Retorna a primeira auth concreta encontrada. Collections raiz sempre têm auth concreta (nunca `Inherit from parent`). |
| Resolved request | Request com todas as variáveis substituídas e auth concreta, pronto para execução. |

---

*Ver também: `architecture.md`, `domain.md`*
