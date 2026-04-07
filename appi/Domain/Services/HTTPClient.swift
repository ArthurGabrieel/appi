import Foundation

protocol HTTPClient: Sendable {
    func execute(_ request: ResolvedRequest) async throws -> Response
    func cancel()
}
