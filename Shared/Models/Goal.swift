import SwiftUI

struct Goal: Codable, Identifiable, Hashable {
    let id: String
    let emoji: String
    let name: String
    let displayName: String?
    let focus: String          // sprint | steady | simmer | dormant
    let focusIcon: String?
    let timeline: String?
    let story: String?
    let initiatives: [Initiative]?

    var resolvedName: String { displayName ?? name }

    var focusColor: Color {
        switch focus {
        case "sprint":  return .blue
        case "steady":  return .green
        case "simmer":  return .yellow
        default:        return .gray
        }
    }

    var focusLabel: String {
        focus.prefix(1).uppercased() + focus.dropFirst()
    }
}
