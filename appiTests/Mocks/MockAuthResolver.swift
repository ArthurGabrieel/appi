import Foundation
@testable import appi

final class MockAuthResolver: AuthResolver, @unchecked Sendable {
    var resolveResult: Result<ResolvedAuth, Error> = .success(.none)

    func resolve(for auth: AuthConfig, chain: [Collection]) async throws -> ResolvedAuth {
        try resolveResult.get()
    }
}
