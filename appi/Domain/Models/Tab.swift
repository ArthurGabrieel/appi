import Foundation

struct Tab: Equatable, Identifiable {
    let id: UUID
    var linkedRequestId: UUID?
    var draft: RequestDraft
    var sortIndex: Int
    var isActive: Bool
    let createdAt: Date
}
