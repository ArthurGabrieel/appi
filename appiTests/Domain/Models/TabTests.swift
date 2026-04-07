// appiTests/Domain/Models/TabTests.swift
import Testing
import Foundation
@testable import appi

struct TabTests {
    @Test("isDirty is false for new tab without originalDraft")
    func newTabNotDirty() {
        let tab = Tab(
            id: UUID(), linkedRequestId: nil,
            draft: RequestDraft.empty(in: UUID()),
            originalDraft: nil,
            sortIndex: 0, isActive: true, createdAt: Date()
        )
        #expect(tab.isDirty == false)
    }

    @Test("isDirty is false when draft matches originalDraft")
    func unchangedTabNotDirty() {
        let draft = RequestDraft.empty(in: UUID())
        let tab = Tab(
            id: UUID(), linkedRequestId: UUID(),
            draft: draft,
            originalDraft: draft,
            sortIndex: 0, isActive: true, createdAt: Date()
        )
        #expect(tab.isDirty == false)
    }

    @Test("isDirty is true when draft differs from originalDraft")
    func modifiedTabIsDirty() {
        let original = RequestDraft.empty(in: UUID())
        var modified = original
        modified.url = "https://changed.example.com"
        let tab = Tab(
            id: UUID(), linkedRequestId: UUID(),
            draft: modified,
            originalDraft: original,
            sortIndex: 0, isActive: true, createdAt: Date()
        )
        #expect(tab.isDirty == true)
    }
}
