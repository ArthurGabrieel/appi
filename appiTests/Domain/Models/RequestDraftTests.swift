import Foundation
import Testing
@testable import appi

struct RequestDraftTests {
    @Test("Empty draft has GET method, no body, and inheritFromParent auth")
    func emptyDraftDefaults() {
        let collectionId = UUID()
        let draft = RequestDraft.empty(in: collectionId)

        #expect(draft.name == "New Request")
        #expect(draft.method == .get)
        #expect(draft.url == "")
        #expect(draft.headers.isEmpty)
        #expect(draft.body == .none)
        #expect(draft.auth == .inheritFromParent)
        #expect(draft.collectionId == collectionId)
    }

    @Test("toRequest() generates unique IDs on each call")
    func toRequestGeneratesUniqueIds() {
        let draft = RequestDraft.empty(in: UUID())
        let r1 = draft.toRequest()
        let r2 = draft.toRequest()

        #expect(r1.id != r2.id)
    }

    @Test("toRequest(existingId:) preserves the given ID")
    func toRequestPreservesId() {
        let draft = RequestDraft.empty(in: UUID())
        let existingId = UUID()
        let request = draft.toRequest(existingId: existingId)

        #expect(request.id == existingId)
    }

    @Test("from(request) creates draft matching the request")
    func fromRequest() {
        let request = Request(
            id: UUID(),
            name: "Get Users",
            method: .get,
            url: "https://api.example.com/users",
            headers: [Header(id: UUID(), key: "Accept", value: "application/json", isEnabled: true)],
            body: .none,
            auth: .bearer(token: "abc"),
            collectionId: UUID(),
            sortIndex: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
        let draft = RequestDraft.from(request)

        #expect(draft.name == request.name)
        #expect(draft.method == request.method)
        #expect(draft.url == request.url)
        #expect(draft.headers == request.headers)
        #expect(draft.body == request.body)
        #expect(draft.auth == request.auth)
        #expect(draft.collectionId == request.collectionId)
    }
}
