import Foundation
@testable import appi

final class MockAuthService: AuthService, @unchecked Sendable {
    var tokenToReturn: TokenSet?
    var authorizeCalled = false
    var refreshCalled = false
    var loadTokenResult: TokenSet?
    var shouldThrowOnRefresh = false

    func authorize(with config: OAuth2Config) async throws -> TokenSet {
        authorizeCalled = true
        guard let token = tokenToReturn else { throw AuthError.authorizationDenied }
        return token
    }

    func refreshIfNeeded(tokenSet: TokenSet, config: OAuth2Config) async throws -> TokenSet {
        refreshCalled = true
        if shouldThrowOnRefresh { throw AuthError.refreshFailed(AuthError.tokenExpired) }
        return tokenToReturn ?? tokenSet
    }

    func loadToken(for config: OAuth2Config) throws -> TokenSet? {
        loadTokenResult
    }

    func saveToken(_ tokenSet: TokenSet, for config: OAuth2Config) throws {}
}
