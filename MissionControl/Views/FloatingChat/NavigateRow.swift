import SwiftUI

/// Inline `navigate` part renderer — a full-width tappable row that fires a
/// `DeepLink` through the shared `DeepLinkRouter`. Per
/// IOS_MESSAGE_PARTS_PLAN §5.3 unresolvable routes (`.unknown`) render as
/// non-tappable text so an older client doesn't dead-end on a path the agent
/// added later.
struct NavigateRow: View {
    let route: String
    let label: String

    @Environment(DeepLinkRouter.self) private var router

    private var link: DeepLink { DeepLink.parse(route) }

    var body: some View {
        if link.isResolved {
            Button {
                router.open(link)
            } label: {
                rowContent(showsChevron: true)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityHint("Opens \(route)")
        } else {
            rowContent(showsChevron: false)
        }
    }

    @ViewBuilder
    private func rowContent(showsChevron: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon(for: link))
                .foregroundStyle(.blue)
                .font(.body)
                .frame(width: 22)
            Text(label)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .cardStyle(.compact)
    }

    private func icon(for link: DeepLink) -> String {
        switch link {
        case .task:             return "checkmark.square"
        case .goal:             return "trophy"
        case .initiative:       return "flag.pattern.checkered"
        case .agentAssignment:  return "person.badge.clock"
        case .schedule:         return "calendar"
        case .home:             return "house"
        case .unknown:          return "link"
        }
    }
}
