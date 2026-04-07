import Foundation
@testable import appi

final class MockEnvResolver: EnvResolver, @unchecked Sendable {
    var resolveResult: Result<PreparedRequest, Error> = .failure(RequestError.invalidURL(""))
    var unresolvedKeysResult: [String] = []

    func resolve(_ draft: RequestDraft, using environment: Environment?) throws -> PreparedRequest {
        try resolveResult.get()
    }

    func unresolvedKeys(in draft: RequestDraft, environment: Environment?) -> [String] {
        unresolvedKeysResult
    }
}
