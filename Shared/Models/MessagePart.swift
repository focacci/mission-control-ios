import Foundation

// MARK: - CardKind

/// Mirrors `CARD_KINDS` in the API
/// (`mission-control-api/src/types/index.types.ts`). Unknown kinds the server
/// adds before iOS ships matching renderers fall back to `.unknown`.
enum CardKind: String, Codable, Hashable, CaseIterable {
    case task
    case goal
    case initiative
    case agentAssignment = "agent_assignment"
    case slot
    case scheduleDay = "schedule_day"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = CardKind(rawValue: raw) ?? .unknown
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

// MARK: - PromptKind

enum PromptKind: String, Codable, Hashable, CaseIterable {
    case confirm
    case choice
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PromptKind(rawValue: raw) ?? .unknown
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

// MARK: - Payload structs

struct PromptChoice: Codable, Hashable, Identifiable {
    let id: String
    let label: String
    let emoji: String?
}

struct PromptPart: Codable, Hashable {
    let promptType: PromptKind
    let question: String
    let promptId: String
    let choices: [PromptChoice]?
}

struct QuickReply: Codable, Hashable, Identifiable {
    let id: String
    let label: String
}

struct Attachment: Codable, Hashable {
    let mimeType: String
    let name: String
    let url: String
    let size: Int?
}

// MARK: - MessagePart

/// Swift mirror of the API discriminated union persisted in
/// `chat_messages.parts` (see `MessagePartSchema` in
/// `mission-control-api/src/types/index.types.ts`). Custom `Codable` impl
/// switches on the `kind` discriminator — Swift's synthesized `Codable` for
/// enums-with-payloads does not match the server shape.
///
/// Decoding an unknown `kind` does not throw: it falls back to a
/// `.text("[unsupported part: <kind>]")` so a future server can add new part
/// kinds without breaking older clients.
enum MessagePart: Hashable, Identifiable {
    case text(String)
    case card(CardKind, entityId: String)
    case prompt(PromptPart)
    case promptReply(promptId: String, choiceId: String)
    case quickReplies([QuickReply])
    case navigate(route: String, label: String)
    case attachment(Attachment)
    case liveActivityRef(activityId: String, title: String)

    /// Stable per-part id — derived from payload so SwiftUI `ForEach` keeps
    /// row identity across re-renders within the same turn.
    var id: String {
        switch self {
        case .text(let s):
            return "text:\(s.hashValue)"
        case .card(let kind, let entityId):
            return "card:\(kind.rawValue):\(entityId)"
        case .prompt(let p):
            return "prompt:\(p.promptId)"
        case .promptReply(let promptId, let choiceId):
            return "promptReply:\(promptId):\(choiceId)"
        case .quickReplies(let suggestions):
            return "quickReplies:\(suggestions.map(\.id).joined(separator: ","))"
        case .navigate(let route, _):
            return "navigate:\(route)"
        case .attachment(let a):
            return "attachment:\(a.url)"
        case .liveActivityRef(let activityId, _):
            return "liveActivity:\(activityId)"
        }
    }

    /// String discriminator written to the wire under the `kind` key.
    var kind: String {
        switch self {
        case .text:             return "text"
        case .card:             return "card"
        case .prompt:           return "prompt"
        case .promptReply:      return "prompt_reply"
        case .quickReplies:     return "quick_replies"
        case .navigate:         return "navigate"
        case .attachment:       return "attachment"
        case .liveActivityRef:  return "live_activity_ref"
        }
    }
}

// MARK: - Codable

extension MessagePart: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        // text
        case text
        // card
        case cardType, entityId
        // prompt
        case promptType, question, promptId, choices
        // prompt_reply
        case choiceId
        // quick_replies
        case suggestions
        // navigate
        case route, label
        // attachment
        case mimeType, name, url, size
        // live_activity_ref
        case activityId, title
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)

        switch kind {
        case "text":
            let text = try c.decode(String.self, forKey: .text)
            self = .text(text)

        case "card":
            let raw = try c.decode(String.self, forKey: .cardType)
            let entityId = try c.decode(String.self, forKey: .entityId)
            self = .card(CardKind(rawValue: raw) ?? .unknown, entityId: entityId)

        case "prompt":
            let promptType = try c.decode(PromptKind.self, forKey: .promptType)
            let question = try c.decode(String.self, forKey: .question)
            let promptId = try c.decode(String.self, forKey: .promptId)
            let choices = try c.decodeIfPresent([PromptChoice].self, forKey: .choices)
            self = .prompt(PromptPart(
                promptType: promptType,
                question: question,
                promptId: promptId,
                choices: choices
            ))

        case "prompt_reply":
            let promptId = try c.decode(String.self, forKey: .promptId)
            let choiceId = try c.decode(String.self, forKey: .choiceId)
            self = .promptReply(promptId: promptId, choiceId: choiceId)

        case "quick_replies":
            let suggestions = try c.decode([QuickReply].self, forKey: .suggestions)
            self = .quickReplies(suggestions)

        case "navigate":
            let route = try c.decode(String.self, forKey: .route)
            let label = try c.decode(String.self, forKey: .label)
            self = .navigate(route: route, label: label)

        case "attachment":
            let mimeType = try c.decode(String.self, forKey: .mimeType)
            let name = try c.decode(String.self, forKey: .name)
            let url = try c.decode(String.self, forKey: .url)
            let size = try c.decodeIfPresent(Int.self, forKey: .size)
            self = .attachment(Attachment(mimeType: mimeType, name: name, url: url, size: size))

        case "live_activity_ref":
            let activityId = try c.decode(String.self, forKey: .activityId)
            let title = try c.decode(String.self, forKey: .title)
            self = .liveActivityRef(activityId: activityId, title: title)

        default:
            self = .text("[unsupported part: \(kind)]")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)

        switch self {
        case .text(let text):
            try c.encode(text, forKey: .text)

        case .card(let kind, let entityId):
            try c.encode(kind.rawValue, forKey: .cardType)
            try c.encode(entityId, forKey: .entityId)

        case .prompt(let p):
            try c.encode(p.promptType, forKey: .promptType)
            try c.encode(p.question, forKey: .question)
            try c.encode(p.promptId, forKey: .promptId)
            try c.encodeIfPresent(p.choices, forKey: .choices)

        case .promptReply(let promptId, let choiceId):
            try c.encode(promptId, forKey: .promptId)
            try c.encode(choiceId, forKey: .choiceId)

        case .quickReplies(let suggestions):
            try c.encode(suggestions, forKey: .suggestions)

        case .navigate(let route, let label):
            try c.encode(route, forKey: .route)
            try c.encode(label, forKey: .label)

        case .attachment(let a):
            try c.encode(a.mimeType, forKey: .mimeType)
            try c.encode(a.name, forKey: .name)
            try c.encode(a.url, forKey: .url)
            try c.encodeIfPresent(a.size, forKey: .size)

        case .liveActivityRef(let activityId, let title):
            try c.encode(activityId, forKey: .activityId)
            try c.encode(title, forKey: .title)
        }
    }
}

// MARK: - Helpers

extension Array where Element == MessagePart {
    /// Mirrors the API's `partsToText` — used as a legacy fallback when
    /// rendering a `ChatTranscriptMessage` whose `parts` array is empty.
    var partsToText: String {
        var out: [String] = []
        for p in self {
            switch p {
            case .text(let s):           out.append(s)
            case .navigate(_, let l):    out.append(l)
            case .prompt(let pp):        out.append(pp.question)
            default:                     break
            }
        }
        return out.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
