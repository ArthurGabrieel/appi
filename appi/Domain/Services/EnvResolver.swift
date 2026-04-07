import Foundation

protocol EnvResolver: Sendable {
    func resolve(_ draft: RequestDraft, using environment: Environment?) throws -> PreparedRequest
    func unresolvedKeys(in draft: RequestDraft, environment: Environment?) -> [String]
}
