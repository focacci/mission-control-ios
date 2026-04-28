import SwiftUI

/// Single dispatcher for one strip of an agent turn. Owns the mapping from
/// `TurnSegment` cases to per-kind renderers so `TurnView` stays a flat
/// `ForEach(segments) { MessageSegmentView(segment:entityCache:) }`.
///
/// Three segment kinds ship today: `.text`, `.toolCall`, and `.card`. New
/// cases (`.quickReplies`, `.navigate`, `.attachment`) land in later
/// build-order steps and slot in as additional switch arms without touching
/// callers.
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
        }
    }
}
