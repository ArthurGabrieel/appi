import Foundation

struct EnvVariable: Equatable, Identifiable {
    let id: UUID
    var key: String
    var value: String
    var isSecret: Bool
    var isEnabled: Bool
    var environmentId: UUID
}
