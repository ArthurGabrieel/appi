import Foundation

protocol ExportSerializer: Sendable {
    func serialize(
        _ rootCollection: Collection,
        descendants: [Collection],
        requests: [Request],
        environment: Environment?
    ) throws -> Data
}
