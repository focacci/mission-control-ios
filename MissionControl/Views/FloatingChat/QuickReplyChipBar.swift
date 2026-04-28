import SwiftUI

/// Horizontally scrolling row of chips rendered above the composer. Picks up
/// the most recent assistant turn's `quick_replies` segment — older turns'
/// chips disappear once the user has moved past them, so the bar always
/// reflects "what could I tap right now".
///
/// Tapping a chip submits the chip's `label` as a synthetic user message via
/// `onTap`. The plan's open question (vanish vs. persist) defaults to vanish:
/// once a new turn starts the previous suggestions go with it. Per
/// IOS_MESSAGE_PARTS_PLAN §5.1 max 6 chips; anything beyond that is clipped
/// and accessible via horizontal scroll.
struct QuickReplyChipBar: View {
    let suggestions: [QuickReply]
    let onTap: (QuickReply) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions.prefix(6)) { reply in
                    Button {
                        onTap(reply)
                    } label: {
                        Text(reply.label)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}
