import Foundation

protocol AuthService: Sendable {
    func authorize(with config: OAuth2Config) async throws -> TokenSet
    func refreshIfNeeded(tokenSet: TokenSet, config: OAuth2Config) async throws -> TokenSet
    func loadToken(for config: OAuth2Config) throws -> TokenSet?
    func saveToken(_ tokenSet: TokenSet, for config: OAuth2Config) throws
}
