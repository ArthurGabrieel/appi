# Appi — Claude Code Guidelines

## Project

Appi is a native HTTP client for macOS 14+ built with SwiftUI + SwiftData. Think Postman, but native Apple.

## Documentation

Read before making changes:
- `docs/requirements.md` — functional/non-functional requirements, business rules
- `docs/domain.md` — entities, value objects, error types
- `docs/architecture.md` — MVVM + Repository, DI, concurrency, protocols
- `docs/testing-strategy.md` — what to test, how to mock, conventions
- `docs/ui-navigation.md` — screen hierarchy, navigation flows, adaptive layout
- `docs/data-model.md` — entity relationships diagram
- `docs/coding-conventions.md` — naming, file organization, SwiftLint rules

## Build & Test

```bash
# Build
xcodebuild -scheme appi -destination 'platform=macOS' build

# Test
xcodebuild -scheme appi -destination 'platform=macOS' test

# Lint
swiftlint lint --strict
```

## Architecture Rules

- **MVVM + Repository + SOLID** — ViewModels never touch SwiftData directly.
- **Two model layers** — Domain structs (`Request`) in `Domain/Models/`, @Model classes (`RequestModel`) in `Data/Models/`. Repositories map between them via `toDomain()` and `init(from:)`.
- **DI via DependencyContainer** — factory pattern, injected via `@Environment`. Never instantiate ViewModels directly in Views.
- **Concurrency** — Repositories are `@ModelActor`, ViewModels are `@MainActor`, Services are structs or actors. Never share `ModelContext` across actors.
- **Auth chain** — resolved by `AuthResolver` before execution. Never resolve auth in Views.
- **Errors inline** — always displayed in context, never modal alerts (except destructive action confirmations).

## Key Conventions

- All UI strings via `String(localized:)` — never hardcode. Languages: pt-BR, en.
- Every View gets `accessibilityLabel` + Dynamic Type support.
- Domain layer is pure — no SwiftData/Keychain references. Infrastructure details in Data layer only.
- `EnvResolver` resolves variables and validates URL (throws `RequestError.invalidURL`).
- `HTTPClient` returns `Response` without `requestId` — binding happens only at persistence.
- Root collections have `auth = .none`, never `.inheritFromParent`.
- Swift Testing framework (not XCTest). See `docs/testing-strategy.md`.

## Don'ts

- Don't add external dependencies for networking, auth, or UI. Everything native.
- Don't put business logic in Views.
- Don't pass @Model objects across actor boundaries — convert to domain structs first.
- Don't skip accessibility labels on new Views.
- Don't hardcode strings — use String Catalogs.
- Don't store OAuth2 tokens in SwiftData — Keychain only (RN-09).
- Don't expose `Inherit from parent` auth option on root collections.
