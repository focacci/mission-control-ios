import XCTest
@testable import MissionControl

/// Round-trips the API's wire shape through `MessagePart` to catch
/// discriminator drift between `mission-control-api/src/types/index.types.ts`
/// (`MessagePartSchema`) and the Swift mirror.
final class MessagePartTests: XCTestCase {

    // MARK: - Fixtures

    /// One fixture per shipped part kind, keyed by the wire `kind` string. The
    /// payloads match the shapes the runner emits today (verified against
    /// `mcpBridge.ts` + `pendingParts.service.ts`).
    private static let wireFixtures: [String: String] = [
        "text": #"""
        { "kind": "text", "text": "hello world" }
        """#,
        "card": #"""
        { "kind": "card", "cardType": "task", "entityId": "tsk_abc123" }
        """#,
        "prompt": #"""
        {
            "kind": "prompt",
            "promptType": "choice",
            "promptId": "p1",
            "question": "Which slot works?",
            "choices": [
                { "id": "a", "label": "Mon 10am" },
                { "id": "b", "label": "Tue 2pm", "emoji": "⏰" }
            ]
        }
        """#,
        "prompt_reply": #"""
        { "kind": "prompt_reply", "promptId": "p1", "choiceId": "a" }
        """#,
        "quick_replies": #"""
        {
            "kind": "quick_replies",
            "suggestions": [
                { "id": "yes", "label": "Yes" },
                { "id": "no",  "label": "No"  }
            ]
        }
        """#,
        "navigate": #"""
        { "kind": "navigate", "route": "/tasks/tsk_abc", "label": "Open task" }
        """#,
        "attachment": #"""
        {
            "kind": "attachment",
            "mimeType": "image/png",
            "name": "diagram.png",
            "url": "workspace://attachments/sess_1/diagram.png",
            "size": 4096
        }
        """#,
        "live_activity_ref": #"""
        { "kind": "live_activity_ref", "activityId": "la_1", "title": "Focus block" }
        """#,
    ]

    // MARK: - Decode

    func test_decode_eachKind_roundTripsToExpectedCase() throws {
        let dec = JSONDecoder()

        for (wireKind, json) in Self.wireFixtures {
            let part = try dec.decode(MessagePart.self, from: Data(json.utf8))
            XCTAssertEqual(part.kind, wireKind, "kind discriminator mismatch for \(wireKind)")
        }
    }

    func test_decode_card_extractsCardKindAndEntityId() throws {
        let part = try decode(Self.wireFixtures["card"]!)
        guard case .card(let kind, let entityId) = part else {
            return XCTFail("expected .card, got \(part)")
        }
        XCTAssertEqual(kind, .task)
        XCTAssertEqual(entityId, "tsk_abc123")
    }

    func test_decode_prompt_choicesRoundTrip() throws {
        let part = try decode(Self.wireFixtures["prompt"]!)
        guard case .prompt(let p) = part else {
            return XCTFail("expected .prompt, got \(part)")
        }
        XCTAssertEqual(p.promptType, .choice)
        XCTAssertEqual(p.promptId, "p1")
        XCTAssertEqual(p.choices?.count, 2)
        XCTAssertEqual(p.choices?[1].emoji, "⏰")
    }

    func test_decode_quickReplies_preservesOrder() throws {
        let part = try decode(Self.wireFixtures["quick_replies"]!)
        guard case .quickReplies(let suggestions) = part else {
            return XCTFail("expected .quickReplies, got \(part)")
        }
        XCTAssertEqual(suggestions.map(\.id), ["yes", "no"])
    }

    func test_decode_attachment_optionalSizeOmitted() throws {
        let json = #"""
        {
            "kind": "attachment",
            "mimeType": "application/pdf",
            "name": "spec.pdf",
            "url": "https://example.com/spec.pdf"
        }
        """#
        let part = try decode(json)
        guard case .attachment(let a) = part else {
            return XCTFail("expected .attachment, got \(part)")
        }
        XCTAssertNil(a.size)
    }

    // MARK: - Round-trip

    func test_encodeThenDecode_preservesEveryFixture() throws {
        let dec = JSONDecoder()
        let enc = JSONEncoder()

        for (wireKind, json) in Self.wireFixtures {
            let original = try dec.decode(MessagePart.self, from: Data(json.utf8))
            let reEncoded = try enc.encode(original)
            let roundTripped = try dec.decode(MessagePart.self, from: reEncoded)

            XCTAssertEqual(original, roundTripped, "round-trip diverged for \(wireKind)")
            XCTAssertEqual(original.kind, roundTripped.kind)
        }
    }

    func test_encode_writesKindDiscriminatorAtTopLevel() throws {
        let part = MessagePart.card(.goal, entityId: "gol_1")
        let data = try JSONEncoder().encode(part)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(dict["kind"] as? String, "card")
        XCTAssertEqual(dict["cardType"] as? String, "goal")
        XCTAssertEqual(dict["entityId"] as? String, "gol_1")
    }

    // MARK: - Forward compatibility

    func test_decode_unknownKind_fallsBackToTextSentinel() throws {
        let json = #"""
        { "kind": "totally_new_kind_2027", "anything": 42 }
        """#
        let part = try decode(json)
        guard case .text(let s) = part else {
            return XCTFail("expected .text fallback, got \(part)")
        }
        XCTAssertTrue(s.contains("totally_new_kind_2027"),
                      "fallback should surface the unknown kind, got \(s)")
    }

    func test_decode_unknownCardKind_fallsBackToCardKindUnknown() throws {
        let json = #"""
        { "kind": "card", "cardType": "brand_new_card_kind", "entityId": "x" }
        """#
        let part = try decode(json)
        guard case .card(let kind, _) = part else {
            return XCTFail("expected .card, got \(part)")
        }
        XCTAssertEqual(kind, .unknown)
    }

    // MARK: - partsToText

    func test_partsToText_concatenatesTextNavigatePromptOnly() {
        let parts: [MessagePart] = [
            .text("Here are options:"),
            .quickReplies([QuickReply(id: "y", label: "Yes")]),    // skipped
            .navigate(route: "/tasks/1", label: "Open task"),
            .prompt(PromptPart(promptType: .confirm, question: "Proceed?",
                               promptId: "p", choices: nil)),
            .card(.task, entityId: "t"),                            // skipped
        ]
        XCTAssertEqual(parts.partsToText,
                       "Here are options:\nOpen task\nProceed?")
    }

    // MARK: - Helpers

    private func decode(_ json: String) throws -> MessagePart {
        try JSONDecoder().decode(MessagePart.self, from: Data(json.utf8))
    }
}
