// appi/Domain/Models/Tab.swift
import Foundation

struct Tab: Equatable, Identifiable {
    let id: UUID
    var linkedRequestId: UUID?
    var draft: RequestDraft
    var originalDraft: RequestDraft?
    var sortIndex: Int
    var isActive: Bool
    let createdAt: Date

    var isDirty: Bool {
        guard let originalDraft else { return false }
        return draft != originalDraft
    }
}
