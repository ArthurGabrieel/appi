import Foundation
@testable import appi

final class MockAuthResolver: AuthResolver, @unchecked Sendable {
    var resolveResult: Result<ResolvedAuth, Error> = .success(.none)
    var shouldThrow: (any Error)?

    func resolve(for auth: AuthConfig, chain: [Collection]) async throws -> ResolvedAuth {
        if let shouldThrow { throw shouldThrow }
        return try resolveResult.get()
    }
}
