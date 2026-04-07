import Testing
import Foundation
@testable import appi

struct EnvResolverTests {
    let resolver = DefaultEnvResolver()

    @Test("Resolves {{variable}} in URL")
    func resolvesUrlVariable() throws {
        var draft = RequestDraft.empty(in: UUID())
        draft.url = "{{baseUrl}}/users"

        let env = Environment(
            id: UUID(), name: "Dev", isActive: true, workspaceId: UUID(),
            variables: [
                EnvVariable(id: UUID(), key: "baseUrl", value: "https://api.dev.com", isSecret: false, isEnabled: true, environmentId: UUID())
            ],
            createdAt: Date(), updatedAt: Date()
        )

        let prepared = try resolver.resolve(draft, using: env)
        #expect(prepared.url.absoluteString == "https://api.dev.com/users")
    }

    @Test("Disabled variable is not resolved")
    func disabledVariableIgnored() throws {
        var draft = RequestDraft.empty(in: UUID())
        draft.url = "{{baseUrl}}/users"

        let env = Environment(
            id: UUID(), name: "Dev", isActive: true, workspaceId: UUID(),
            variables: [
                EnvVariable(id: UUID(), key: "baseUrl", value: "https://api.dev.com", isSecret: false, isEnabled: false, environmentId: UUID())
            ],
            createdAt: Date(), updatedAt: Date()
        )

        let keys = resolver.unresolvedKeys(in: draft, environment: env)
        #expect(keys == ["baseUrl"])
    }

    @Test("Empty URL throws invalidURL")
    func emptyUrlThrows() {
        let draft = RequestDraft.empty(in: UUID())

        #expect(throws: RequestError.self) {
            try resolver.resolve(draft, using: nil)
        }
    }

    @Test("Invalid URL after resolution throws invalidURL")
    func invalidUrlThrows() {
        var draft = RequestDraft.empty(in: UUID())
        draft.url = ""

        let env = Environment(
            id: UUID(), name: "Dev", isActive: true, workspaceId: UUID(),
            variables: [
                EnvVariable(id: UUID(), key: "host", value: "", isSecret: false, isEnabled: true, environmentId: UUID())
            ],
            createdAt: Date(), updatedAt: Date()
        )

        // URL resolves to empty string after substitution, which is invalid
        draft.url = "{{host}}"
        #expect(throws: RequestError.self) {
            try resolver.resolve(draft, using: env)
        }
    }

    @Test("Resolves variables in headers")
    func resolvesHeaderVariable() throws {
        var draft = RequestDraft.empty(in: UUID())
        draft.url = "https://api.example.com"
        draft.headers = [
            Header(id: UUID(), key: "Authorization", value: "Bearer {{token}}", isEnabled: true)
        ]

        let env = Environment(
            id: UUID(), name: "Dev", isActive: true, workspaceId: UUID(),
            variables: [
                EnvVariable(id: UUID(), key: "token", value: "abc123", isSecret: false, isEnabled: true, environmentId: UUID())
            ],
            createdAt: Date(), updatedAt: Date()
        )

        let prepared = try resolver.resolve(draft, using: env)
        #expect(prepared.headers[0].value == "Bearer abc123")
    }

    @Test("No environment resolves URL without substitution")
    func noEnvironment() throws {
        var draft = RequestDraft.empty(in: UUID())
        draft.url = "https://api.example.com/users"

        let prepared = try resolver.resolve(draft, using: nil)
        #expect(prepared.url.absoluteString == "https://api.example.com/users")
    }
}
