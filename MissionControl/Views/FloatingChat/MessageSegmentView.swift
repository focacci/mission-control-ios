import SwiftUI

/// Single dispatcher for one strip of an agent turn. Owns the mapping from
/// `TurnSegment` cases to per-kind views so `TurnView` stays a flat
/// `ForEach(segments) { MessageSegmentView(segment:) }`.
///
/// Only the two segment kinds that ship today are handled here — `.text` and
/// `.toolCall`. New cases (`.card`, `.quickReplies`, `.navigate`,
/// `.attachment`) land in later build-order steps and slot in as additional
/// switch arms without touching callers.
struct MessageSegmentView: View {
    let segment: TurnSegment

    var body: some View {
        switch segment {
        case .text(_, let content):
            AgentTextBubble(content: content, isError: false)
        case .toolCall(_, let call):
            ToolStepRow(call: call)
        }
    }
}
