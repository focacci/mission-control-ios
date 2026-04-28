import XCTest
@testable import MissionControl

/// Decode coverage for `ChatTranscriptMessage.parts` and the
/// `ChatTurnBuilder` paths that consume them. Verifies that legacy rows
/// (parts absent or empty) keep rendering identically via the `content`
/// fallback, and that new rows surface text parts as `TurnSegment.text`.
final class ChatTranscriptMessageTests: XCTestCase {

    // MARK: - Decode

    func test_decode_legacyRow_withoutPartsField_defaultsToEmpty() throws {
        let json = #"""
        {
            "id": "msg_1",
            "sessionId": "sess_1",
            "invocationId": "inv_1",
            "role": "assistant",
            "content": "hi there",
            "sortOrder": 0,
            "createdAt": "2026-04-27T00:00:00Z"
        }
        """#
        let msg = try JSONDecoder().decode(
            ChatTranscriptMessage.self,
            from: Data(json.utf8)
        )
        XCTAssertEqual(msg.content, "hi there")
        XCTAssertTrue(msg.parts.isEmpty)
    }

    func test_decode_newRow_withMixedParts() throws {
        let json = #"""
        {
            "id": "msg_2",
            "sessionId": "sess_1",
            "invocationId": null,
            "role": "assistant",
            "content": "Here you go\nOpen task",
            "parts": [
                { "kind": "text", "text": "Here you go" },
                { "kind": "card", "cardType": "task", "entityId": "tsk_1" },
                { "kind": "navigate", "route": "/tasks/tsk_1", "label": "Open task" }
            ],
            "sortOrder": 1,
            "createdAt": "2026-04-27T00:00:00Z"
        }
        """#
        let msg = try JSONDecoder().decode(
            ChatTranscriptMessage.self,
            from: Data(json.utf8)
        )
        XCTAssertEqual(msg.parts.count, 3)
        XCTAssertNil(msg.invocationId)
    }

    // MARK: - ChatTurnBuilder.turns(from:)

    func test_turns_legacyAssistantRow_emitsSingleTextSegment() {
        let messages = [
            assistant(id: "m1", content: "Hello!", parts: [])
        ]
        let turns = ChatTurnBuilder.turns(from: messages)
        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns[0].segments.count, 1)
        guard case .text(_, let s) = turns[0].segments[0] else {
            return XCTFail("expected single .text segment")
        }
        XCTAssertEqual(s, "Hello!")
    }

    func test_turns_assistantRowWithTextParts_emitsOneSegmentPerPart() {
        let messages = [
            assistant(
                id: "m1",
                content: "First\nSecond",
                parts: [.text("First"), .text("Second")]
            )
        ]
        let turns = ChatTurnBuilder.turns(from: messages)
        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns[0].segments.count, 2)
        XCTAssertEqual(textContents(turns[0].segments), ["First", "Second"])
    }

    func test_turns_nonTextParts_areDroppedUntilLaterSteps() {
        // Step 3 only handles text parts; cards / quick_replies / etc. get
        // their own renderers in build-order steps 5+.
        let messages = [
            assistant(
                id: "m1",
                content: "Pick one",
                parts: [
                    .text("Pick one"),
                    .card(.task, entityId: "tsk_1"),
                    .quickReplies([QuickReply(id: "a", label: "A")])
                ]
            )
        ]
        let turns = ChatTurnBuilder.turns(from: messages)
        XCTAssertEqual(turns[0].segments.count, 1)
        XCTAssertEqual(textContents(turns[0].segments), ["Pick one"])
    }

    func test_turns_userMessage_startsNewTurn() {
        let messages = [
            user(id: "u1", content: "hi"),
            assistant(id: "m1", content: "hello", parts: [.text("hello")]),
            user(id: "u2", content: "thanks"),
            assistant(id: "m2", content: "yw", parts: [.text("yw")])
        ]
        let turns = ChatTurnBuilder.turns(from: messages)
        XCTAssertEqual(turns.count, 2)
        XCTAssertEqual(turns[0].userContent, "hi")
        XCTAssertEqual(textContents(turns[0].segments), ["hello"])
        XCTAssertEqual(turns[1].userContent, "thanks")
        XCTAssertEqual(textContents(turns[1].segments), ["yw"])
    }

    func test_turns_assistantRowWithEmptyContentAndNoParts_yieldsNoSegments() {
        let messages = [
            assistant(id: "m1", content: "", parts: [])
        ]
        let turns = ChatTurnBuilder.turns(from: messages)
        XCTAssertEqual(turns.count, 1)
        XCTAssertTrue(turns[0].segments.isEmpty)
    }

    // MARK: - Helpers

    private func assistant(
        id: String,
        content: String,
        parts: [MessagePart],
        invocationId: String? = "inv_1"
    ) -> ChatTranscriptMessage {
        ChatTranscriptMessage(
            id: id,
            sessionId: "sess_1",
            invocationId: invocationId,
            role: .assistant,
            content: content,
            parts: parts,
            sortOrder: 0,
            createdAt: "2026-04-27T00:00:00Z"
        )
    }

    private func user(id: String, content: String) -> ChatTranscriptMessage {
        ChatTranscriptMessage(
            id: id,
            sessionId: "sess_1",
            invocationId: nil,
            role: .user,
            content: content,
            parts: [],
            sortOrder: 0,
            createdAt: "2026-04-27T00:00:00Z"
        )
    }

    private func textContents(_ segments: [TurnSegment]) -> [String] {
        segments.compactMap { seg in
            if case .text(_, let s) = seg { return s }
            return nil
        }
    }
}
