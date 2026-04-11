// appi/Data/Services/DefaultAuthResolver.swift
import Foundation

struct DefaultAuthResolver: AuthResolver {
    private let authService: any AuthService

    init(authService: any AuthService) {
        self.authService = authService
    }

    nonisolated func resolve(for auth: AuthConfig, chain: [Collection]) async throws -> ResolvedAuth {
        switch auth {
        case .inheritFromParent:
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
        case .oauth2(let config):
            guard let stored = try authService.loadToken(for: config) else {
                throw AuthError.tokenExpired
            }
            let current = try await authService.refreshIfNeeded(tokenSet: stored, config: config)
            return .oauth2(config, tokenSet: current)
        }
    }
}
