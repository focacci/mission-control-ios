import SwiftUI

/// Single dispatcher for one strip of an agent turn. Owns the mapping from
/// `TurnSegment` cases to per-kind renderers so `TurnView` stays a flat
/// `ForEach(segments) { MessageSegmentView(segment:entityCache:) }`.
///
/// `.quickReplies` is intentionally a no-op here — chips render above the
/// composer in `QuickReplyChipBar`, not inline in the bubble stack. The
/// segment still travels in the turn so the chip bar can pluck the latest
/// assistant turn's suggestions out of `ChatConversationState.turns`.
struct MessageSegmentView: View {
    let segment: TurnSegment
    let entityCache: EntityCache

    var body: some View {
        switch segment {
        case .text(_, let content):
            AgentTextBubble(content: content, isError: false)
        case .toolCall(_, let call):
            ToolStepRow(call: call)
        case .card(_, let kind, let entityId):
            InlineCardView(kind: kind, entityId: entityId, cache: entityCache)
        case .quickReplies:
            EmptyView()
        case .navigate(_, let route, let label):
            NavigateRow(route: route, label: label)
        case .attachment(_, let attachment):
            AttachmentRow(attachment: attachment)
        }
    }
}
