// appi/Data/Models/TabModel.swift
import Foundation
import SwiftData

@Model
final class TabModel {
    @Attribute(.unique) var id: UUID
    var linkedRequestId: UUID?
    var draftData: Data
    var originalDraftData: Data?
    var sortIndex: Int
    var isActive: Bool
    var createdAt: Date

    init(id: UUID, linkedRequestId: UUID?, draftData: Data, originalDraftData: Data?, sortIndex: Int, isActive: Bool, createdAt: Date) {
        self.id = id
        self.linkedRequestId = linkedRequestId
        self.draftData = draftData
        self.originalDraftData = originalDraftData
        self.sortIndex = sortIndex
        self.isActive = isActive
        self.createdAt = createdAt
    }

    convenience init(from tab: Tab) {
        self.init(
            id: tab.id,
            linkedRequestId: tab.linkedRequestId,
            draftData: (try? JSONEncoder().encode(tab.draft)) ?? Data(),
            originalDraftData: tab.originalDraft.flatMap { try? JSONEncoder().encode($0) },
            sortIndex: tab.sortIndex,
            isActive: tab.isActive,
            createdAt: tab.createdAt
        )
    }

    func toDomain() -> Tab {
        let draft = (try? JSONDecoder().decode(RequestDraft.self, from: draftData)) ?? RequestDraft.empty(in: UUID())
        let originalDraft = originalDraftData.flatMap { try? JSONDecoder().decode(RequestDraft.self, from: $0) }
        return Tab(
            id: id,
            linkedRequestId: linkedRequestId,
            draft: draft,
            originalDraft: originalDraft,
            sortIndex: sortIndex,
            isActive: isActive,
            createdAt: createdAt
        )
    }
}
