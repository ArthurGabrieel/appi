import Foundation

protocol AuthResolver: Sendable {
    func resolve(for auth: AuthConfig, chain: [Collection]) async throws -> ResolvedAuth
}
