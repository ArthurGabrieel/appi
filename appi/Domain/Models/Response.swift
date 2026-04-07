import Foundation

struct Response: Equatable, Identifiable {
    let id: UUID
    let statusCode: Int
    let statusMessage: String
    let headers: [Header]
    let body: Data
    let contentType: String?
    let duration: TimeInterval
    let size: Int
    let createdAt: Date
}
