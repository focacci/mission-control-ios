import Foundation
import Observation

/// Bus for navigation requests originating outside the nav stack — currently
/// just `MessagePart.navigate` rows tapped from chat. The chat sheet sits on
/// top of `ContentView`, so the only thing that can actually push a
/// destination is the underlying tab. The router decouples emitter (chat row)
/// from listeners (`ContentView` for tab switch + sheet dismissal, individual
/// tabs for path appends).
///
/// Set `pending` to request navigation; listeners react via `onChange` and
/// call `consume()` once they've handled it. Multiple listeners run in
/// parallel — `ContentView` always handles tab switch + sheet dismiss, while
/// only the matching tab consumes the link to push detail.
@MainActor
@Observable
final class DeepLinkRouter {
    /// The current pending request. `nil` between events. Listeners observe
    /// the change, do their part, then call `consume()` to clear.
    private(set) var pending: DeepLink?

    func open(_ link: DeepLink) {
        pending = link
    }

    func consume() {
        pending = nil
    }
}
