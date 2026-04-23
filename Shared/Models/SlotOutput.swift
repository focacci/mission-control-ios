import SwiftUI

/// Artifact an agent created, updated, or deleted while running during a
/// scheduled slot. Outputs live on the slot (not the task) because they
/// represent the agent's work trace for that execution window.
struct SlotOutput: Codable, Identifiable, Hashable {
    enum Kind: String, Codable, Hashable, CaseIterable {
        case created, updated, deleted

        var icon: String {
            switch self {
            case .created: return "plus.circle.fill"
            case .updated: return "pencil.circle.fill"
            case .deleted: return "minus.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .created: return .green
            case .updated: return .blue
            case .deleted: return .red
            }
        }

        var label: String {
            switch self {
            case .created: return "Created"
            case .updated: return "Updated"
            case .deleted: return "Deleted"
            }
        }
    }

    let id: String
    let slotId: String
    var label: String
    var url: String?
    var kind: Kind
    var createdAt: String
}
