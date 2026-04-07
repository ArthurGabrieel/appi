import Foundation
import SwiftData

@Model
final class RequestModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var method: String
    var url: String
    var headersData: Data
    var bodyData: Data
    var authData: Data
    var collectionId: UUID
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID, name: String, method: String, url: String, headersData: Data, bodyData: Data, authData: Data, collectionId: UUID, sortIndex: Int, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.method = method
        self.url = url
        self.headersData = headersData
        self.bodyData = bodyData
        self.authData = authData
        self.collectionId = collectionId
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    convenience init(from request: Request) {
        self.init(
            id: request.id,
            name: request.name,
            method: request.method.rawValue,
            url: request.url,
            headersData: (try? JSONEncoder().encode(request.headers)) ?? Data(),
            bodyData: (try? JSONEncoder().encode(request.body)) ?? Data(),
            authData: (try? JSONEncoder().encode(request.auth)) ?? Data(),
            collectionId: request.collectionId,
            sortIndex: request.sortIndex,
            createdAt: request.createdAt,
            updatedAt: request.updatedAt
        )
    }

    func toDomain() -> Request {
        let headers = (try? JSONDecoder().decode([Header].self, from: headersData)) ?? []
        let body = (try? JSONDecoder().decode(RequestBody.self, from: bodyData)) ?? .none
        let auth = (try? JSONDecoder().decode(AuthConfig.self, from: authData)) ?? .inheritFromParent
        return Request(
            id: id,
            name: name,
            method: HTTPMethod(rawValue: method) ?? .get,
            url: url,
            headers: headers,
            body: body,
            auth: auth,
            collectionId: collectionId,
            sortIndex: sortIndex,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
