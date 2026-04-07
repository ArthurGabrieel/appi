import Foundation

struct RequestDraft: Codable, Equatable {
    var name: String
    var method: HTTPMethod
    var url: String
    var headers: [Header]
    var body: RequestBody
    var auth: AuthConfig
    var collectionId: UUID

    static func empty(in collectionId: UUID) -> RequestDraft {
        RequestDraft(
            name: "New Request",
            method: .get,
            url: "",
            headers: [],
            body: .none,
            auth: .inheritFromParent,
            collectionId: collectionId
        )
    }

    static func from(_ request: Request) -> RequestDraft {
        RequestDraft(
            name: request.name,
            method: request.method,
            url: request.url,
            headers: request.headers,
            body: request.body,
            auth: request.auth,
            collectionId: request.collectionId
        )
    }

    func toRequest() -> Request {
        Request(
            id: UUID(),
            name: name,
            method: method,
            url: url,
            headers: headers,
            body: body,
            auth: auth,
            collectionId: collectionId,
            sortIndex: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func toRequest(existingId: UUID) -> Request {
        Request(
            id: existingId,
            name: name,
            method: method,
            url: url,
            headers: headers,
            body: body,
            auth: auth,
            collectionId: collectionId,
            sortIndex: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
