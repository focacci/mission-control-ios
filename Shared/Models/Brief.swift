import Foundation
import SwiftUI

// MARK: - Kind

enum BriefKind: String, Codable, CaseIterable, Hashable {
    case morning, afternoon, evening

    var label: String {
        switch self {
        case .morning:   return "Morning Brief"
        case .afternoon: return "Afternoon Brief"
        case .evening:   return "Evening Brief"
        }
    }
    var shortLabel: String {
        switch self {
        case .morning:   return "Morning"
        case .afternoon: return "Afternoon"
        case .evening:   return "Evening"
        }
    }
    var icon: String {
        switch self {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "moon.stars.fill"
        }
    }
    var color: Color {
        switch self {
        case .morning:   return .orange
        case .afternoon: return .yellow
        case .evening:   return .indigo
        }
    }

    /// Map a `DailyBrief` enum case (legacy static enum) to the Codable kind.
    init(daily: DailyBrief) {
        switch daily {
        case .morning:   self = .morning
        case .afternoon: self = .afternoon
        case .evening:   self = .evening
        }
    }

    var dailyBrief: DailyBrief {
        switch self {
        case .morning:   return .morning
        case .afternoon: return .afternoon
        case .evening:   return .evening
        }
    }
}

// MARK: - Status

/// Backend states. Phase 2 emits `pending | drafting | ready | acknowledged | error`.
/// `generating` is preserved as a legacy alias so older rows from before the
/// migration still decode cleanly. Any unknown raw value falls back to
/// `.unknown` so a future server change can't crash the client.
enum BriefStatus: String, Codable, Hashable {
    case pending
    /// Legacy Phase-1 status — server-side migration rewrites these to
    /// `drafting`, but pre-migration in-flight responses may still use this.
    case generating
    case drafting
    case ready
    case acknowledged
    case error
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = BriefStatus(rawValue: raw) ?? .unknown
    }
}

// MARK: - Brief Row

/// Mirrors `briefs` table rows. `body` and `references` are stored as raw JSON
/// strings on the server; we keep them as `String?` here and lazily decode the
/// structured shape via `decodedBody` / `decodedReferences`. Phase-2 columns
/// (`acknowledgedAt`, `revealAt`, `windowStart`, `windowEnd`) are optional so
/// the model decodes either schema.
struct Brief: Codable, Identifiable, Hashable {
    let id: String
    let date: String
    let kind: BriefKind
    let status: BriefStatus
    let title: String?
    let body: String?
    let references: String?
    let invocationId: String?
    let generatedAt: String?
    let acknowledgedAt: String?
    let revealAt: String?
    let windowStart: String?
    let windowEnd: String?
    let createdAt: String
    let updatedAt: String

    var decodedBody: BriefBody? {
        guard let body, let data = body.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(BriefBody.self, from: data)
    }

    var decodedReferences: BriefReferences? {
        guard let references, let data = references.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(BriefReferences.self, from: data)
    }
}

// MARK: - Structured Body (Phase 2/3)

/// Phase-2 structured shape of `briefs.body`. Phase 1 will see this only on
/// hand-authored rows; the renderer falls back to plain text or the static
/// enum copy when it's absent.
struct BriefBody: Codable, Hashable {
    let summary: String
    let sections: BriefSections
}

struct BriefSections: Codable, Hashable {
    let agentWork: [BriefAgentWorkItem]
    let openQuestions: [BriefQuestionItem]
    let userAccomplishments: [BriefAccomplishmentItem]
    let profileGaps: [BriefProfileGapItem]
    let worldSignal: [BriefWorldSignalItem]
}

/// One completed agent_output that fell inside the brief's window. Mirrors
/// the API discriminated union; `kind` is decoded for completeness even
/// though we already know it from the array we're in.
struct BriefAgentWorkItem: Codable, Hashable, Identifiable {
    let kind: String?
    let agentOutputId: String
    let agentAssignmentId: String?
    let agentId: String?
    let agentName: String?
    let agentEmoji: String?
    let title: String
    let oneLineSummary: String?
    let tokensIn: Int?
    let tokensOut: Int?
    let durationMs: Int?
    let endedAt: String?
    var id: String { agentOutputId }

    /// Combined token count for compact UI rendering.
    var totalTokens: Int? {
        let i = tokensIn ?? 0
        let o = tokensOut ?? 0
        let total = i + o
        return total > 0 ? total : nil
    }
}

struct BriefQuestionItem: Codable, Hashable, Identifiable {
    let kind: String?
    let questionId: String
    let prompt: String
    let source: String?
    let agentOutputId: String?
    let invocationId: String?
    let chatMessageId: String?
    let raisedAt: String?
    var id: String { questionId }
}

struct BriefAccomplishmentItem: Codable, Hashable, Identifiable {
    let kind: String?
    let source: String
    let refId: String
    let title: String
    let detail: String?
    let occurredAt: String?
    var id: String { "\(source):\(refId)" }
}

struct BriefProfileGapItem: Codable, Hashable, Identifiable {
    let kind: String?
    let profileSectionId: String
    let profileEntryId: String?
    let prompt: String
    let raisedAt: String?
    var id: String { profileEntryId ?? profileSectionId }
}

struct BriefWorldSignalItem: Codable, Hashable, Identifiable {
    let kind: String?
    let provider: String
    let headline: String
    let detail: String?
    let url: String?
    let occurredAt: String?
    var id: String { "\(provider):\(headline)" }
}

struct BriefReferences: Codable, Hashable {
    let agentOutputIds: [String]?
    let invocationIds: [String]?
    let taskIds: [String]?
    let requirementIds: [String]?
    let profileEntryIds: [String]?
    let profileSectionIds: [String]?
    let slotIds: [String]?
    let chatMessageIds: [String]?
    let urls: [String]?
    /// Set by the Phase-3 finalizer when the LLM synthesis step fails. UI may
    /// surface a banner so the user knows the summary is a fallback.
    let synthesisFailed: Bool?
}

// MARK: - Availability

/// Centralized rule for "can the user open this brief?" (§7.5). Every UI
/// surface that links to a specific brief routes through this so disabled
/// state is consistent.
enum BriefAvailability: Hashable {
    /// No row exists for the (date, kind) yet — the day hasn't reached the
    /// reveal window.
    case missing
    /// Row exists but isn't revealable yet (pending/generating/drafting).
    case drafting
    /// Reveal time has passed and the brief is unread.
    case ready
    /// User has already opened this brief at least once.
    case acknowledged
    /// Generation pipeline failed; UI should show an error affordance.
    case error

    /// Whether the corresponding tap target should be enabled.
    var isEnabled: Bool {
        switch self {
        case .missing, .drafting: return false
        case .ready, .acknowledged, .error: return true
        }
    }

    /// Whether to show an "unread" badge (Phase 1: `ready` status).
    var hasUnreadBadge: Bool { self == .ready }

    static func from(brief: Brief?) -> BriefAvailability {
        guard let brief else { return .missing }
        switch brief.status {
        case .pending, .generating, .drafting: return .drafting
        case .ready:                            return .ready
        case .acknowledged:                     return .acknowledged
        case .error:                            return .error
        case .unknown:                          return .drafting
        }
    }
}
