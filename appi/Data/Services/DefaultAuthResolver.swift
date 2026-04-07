import Foundation

struct DefaultAuthResolver: AuthResolver {
    nonisolated func resolve(for auth: AuthConfig, chain: [Collection]) async throws -> ResolvedAuth {
        // Stub — full implementation in Sprint 3
        switch auth {
        case .inheritFromParent:
            // Walk chain to find first non-inherit auth
            for collection in chain {
                if case .inheritFromParent = collection.auth { continue }
                return try await resolve(for: collection.auth, chain: [])
            }
            return .none
        case .none:
            return .none
        case .basic(let username, let password):
            return .basic(username: username, password: password)
        case .bearer(let token):
            return .bearer(token: token)
        case .oauth2:
            // OAuth2 token resolution requires AuthService — Sprint 3
            return .none
        }
    }
}
