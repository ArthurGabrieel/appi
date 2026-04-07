import Foundation
import SwiftData

@Model
final class EnvVariableModel {
    @Attribute(.unique) var id: UUID
    var key: String
    var value: String
    var isSecret: Bool
    var isEnabled: Bool
    var environmentId: UUID
    var environment: EnvironmentModel?

    init(id: UUID, key: String, value: String, isSecret: Bool, isEnabled: Bool, environmentId: UUID) {
        self.id = id
        self.key = key
        self.value = value
        self.isSecret = isSecret
        self.isEnabled = isEnabled
        self.environmentId = environmentId
    }

    convenience init(from variable: EnvVariable) {
        self.init(
            id: variable.id,
            key: variable.key,
            value: variable.value,
            isSecret: variable.isSecret,
            isEnabled: variable.isEnabled,
            environmentId: variable.environmentId
        )
    }

    func toDomain() -> EnvVariable {
        EnvVariable(
            id: id,
            key: key,
            value: value,
            isSecret: isSecret,
            isEnabled: isEnabled,
            environmentId: environmentId
        )
    }
}
