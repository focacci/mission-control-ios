import Foundation

/// Runtime-flippable toggles backed by `UserDefaults`. Read on demand so a
/// flip in Settings takes effect on the next read without a restart.
enum FeatureFlags {
    private enum Keys {
        static let useStreamingChat = "chat.useStreaming"
    }

    /// SSE-driven chat path on `POST /api/chat/stream`. Defaults to `true` in
    /// DEBUG so the team dogfoods it; `false` in RELEASE until a confidence
    /// build ships. The buffered `POST /api/chat` path stays alive behind the
    /// flag for at least one release cycle (per IOS_STREAM_CONSUMER_PLAN §9).
    static var useStreamingChat: Bool {
        if let v = UserDefaults.standard.object(forKey: Keys.useStreamingChat) as? Bool {
            return v
        }
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static func setUseStreamingChat(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Keys.useStreamingChat)
    }
}
