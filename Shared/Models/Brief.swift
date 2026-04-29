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

/// Backend states. Phase 1 only emits `pending | generating | ready | error`.
/// `drafting` and `acknowledged` are forward-compat for Phase 2/3 — decoding
/// any unknown raw value falls back to `.unknown` so a server change can't
/// crash the client.
enum BriefStatus: String, Codable, Hashable {
    case pending
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

struct BriefAgentWorkItem: Codable, Hashable, Identifiable {
    let agentOutputId: String
    let title: String
    let oneLineSummary: String
    let tokens: Int?
    let durationMs: Int?
    var id: String { agentOutputId }
}

struct BriefQuestionItem: Codable, Hashable, Identifiable {
    let id: String
    let question: String
    let context: String?
}

struct BriefAccomplishmentItem: Codable, Hashable, Identifiable {
    let id: String
    let label: String
    let detail: String?
}

struct BriefProfileGapItem: Codable, Hashable, Identifiable {
    let id: String
    let question: String
    let profileEntryId: String?
}

struct BriefWorldSignalItem: Codable, Hashable, Identifiable {
    let id: String
    let label: String
    let detail: String?
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
