import Testing
import Foundation
@testable import appi

struct AuthResolverTests {
    func makeResolver(authService: MockAuthService = MockAuthService()) -> DefaultAuthResolver {
        DefaultAuthResolver(authService: authService)
    }

    @Test("No auth in chain returns .none")
    func noneReturnsNone() async throws {
        let resolver = makeResolver()
        let result = try await resolver.resolve(for: .none, chain: [])
        #expect(result == .none)
    }

    @Test("Basic auth resolves directly")
    func basicResolves() async throws {
        let resolver = makeResolver()
        let result = try await resolver.resolve(for: .basic(username: "u", password: "p"), chain: [])
        #expect(result == .basic(username: "u", password: "p"))
    }

    @Test("Bearer token resolves directly")
    func bearerResolves() async throws {
        let resolver = makeResolver()
        let result = try await resolver.resolve(for: .bearer(token: "tok"), chain: [])
        #expect(result == .bearer(token: "tok"))
    }

    @Test("Inherit walks chain and returns first concrete auth")
    func inheritWalksChain() async throws {
        let resolver = makeResolver()
        let colA = Collection(id: UUID(), name: "A", parentId: nil, sortIndex: 0,
                              workspaceId: UUID(), auth: .inheritFromParent,
                              createdAt: Date(), updatedAt: Date())
        let colB = Collection(id: UUID(), name: "B", parentId: nil, sortIndex: 0,
                              workspaceId: UUID(), auth: .bearer(token: "chain-token"),
                              createdAt: Date(), updatedAt: Date())
        let result = try await resolver.resolve(for: .inheritFromParent, chain: [colA, colB])
        #expect(result == .bearer(token: "chain-token"))
    }

    @Test("Inherit through full-none chain returns .none")
    func inheritFullNoneChain() async throws {
        let resolver = makeResolver()
        let colRoot = Collection(id: UUID(), name: "Root", parentId: nil, sortIndex: 0,
                                 workspaceId: UUID(), auth: .none,
                                 createdAt: Date(), updatedAt: Date())
        let result = try await resolver.resolve(for: .inheritFromParent, chain: [colRoot])
        #expect(result == .none)
    }

    @Test("OAuth2 with stored token resolves through refreshIfNeeded fast-path")
    func oauth2WithValidToken() async throws {
        let mockService = MockAuthService()
        let tokenSet = TokenSet(accessToken: "valid", refreshToken: nil, expiresAt: Date.now.addingTimeInterval(3600))
        mockService.loadTokenResult = tokenSet
        mockService.tokenToReturn = tokenSet

        let resolver = makeResolver(authService: mockService)
        let config = OAuth2Config(authURL: "https://auth", tokenURL: "https://token",
                                  clientId: "id", clientSecret: nil, scopes: [], redirectURI: "appi://cb")
        let result = try await resolver.resolve(for: .oauth2(config), chain: [])
        #expect(mockService.refreshCalled)
        if case .oauth2(let c, let ts) = result {
            #expect(c.clientId == "id")
            #expect(ts.accessToken == "valid")
        } else {
            Issue.record("Expected .oauth2 result")
        }
    }

    @Test("OAuth2 with no stored token throws tokenExpired")
    func oauth2NoTokenThrows() async throws {
        let mockService = MockAuthService()
        mockService.loadTokenResult = nil

        let resolver = makeResolver(authService: mockService)
        let config = OAuth2Config(authURL: "https://auth", tokenURL: "https://token",
                                  clientId: "id", clientSecret: nil, scopes: [], redirectURI: "appi://cb")
        await #expect(throws: AuthError.tokenExpired) {
            _ = try await resolver.resolve(for: .oauth2(config), chain: [])
        }
    }
}
