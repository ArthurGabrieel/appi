import Foundation
import SwiftData

@Model
final class ResponseModel {
    @Attribute(.unique) var id: UUID
    var requestId: UUID
    var statusCode: Int
    var statusMessage: String
    var headersData: Data
    var body: Data
    var contentType: String?
    var duration: TimeInterval
    var size: Int
    var createdAt: Date

    init(id: UUID, requestId: UUID, statusCode: Int, statusMessage: String, headersData: Data, body: Data, contentType: String?, duration: TimeInterval, size: Int, createdAt: Date) {
        self.id = id
        self.requestId = requestId
        self.statusCode = statusCode
        self.statusMessage = statusMessage
        self.headersData = headersData
        self.body = body
        self.contentType = contentType
        self.duration = duration
        self.size = size
        self.createdAt = createdAt
    }

    convenience init(from response: Response, requestId: UUID) {
        self.init(
            id: response.id,
            requestId: requestId,
            statusCode: response.statusCode,
            statusMessage: response.statusMessage,
            headersData: (try? JSONEncoder().encode(response.headers)) ?? Data(),
            body: response.body,
            contentType: response.contentType,
            duration: response.duration,
            size: response.size,
            createdAt: response.createdAt
        )
    }

    func toDomain() -> Response {
        let headers = (try? JSONDecoder().decode([Header].self, from: headersData)) ?? []
        return Response(
            id: id,
            statusCode: statusCode,
            statusMessage: statusMessage,
            headers: headers,
            body: body,
            contentType: contentType,
            duration: duration,
            size: size,
            createdAt: createdAt
        )
    }
}
