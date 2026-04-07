import Foundation

struct Request: Equatable, Identifiable {
    let id: UUID
    var name: String
    var method: HTTPMethod
    var url: String
    var headers: [Header]
    var body: RequestBody
    var auth: AuthConfig
    var collectionId: UUID
    var sortIndex: Int
    let createdAt: Date
    var updatedAt: Date
}
