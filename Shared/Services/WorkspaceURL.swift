import Foundation

/// Resolves the `workspace://` URL scheme used by the `attach` interface tool.
/// The agent writes attachments into `WORKSPACE_PATH/attachments/<sessionId>/`
/// on the server and emits URLs of the form
/// `workspace://attachments/<sessionId>/<file>`. iOS rewrites those into
/// `<APIClient.baseURL>/api/workspace/attachments/<sessionId>/<file>` for
/// rendering. Plain `https://` and `http://` URLs pass through unchanged.
///
/// API gap noted in IOS_MESSAGE_PARTS_PLAN §5.4: the static-serving route on
/// the API side is required before this resolves to a real download. Until
/// then iOS still renders the attachment row; the inline preview just falls
/// back to the icon + filename when the fetch 404s.
enum WorkspaceURL {
    /// Translate any URL string the agent might emit into something
    /// `URLSession`/`AsyncImage` can fetch. Returns `nil` only when the input
    /// can't be parsed at all — callers fall back to "no preview" on `nil`.
    static func resolve(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let prefix = "workspace://"
        if trimmed.lowercased().hasPrefix(prefix) {
            let rest = String(trimmed.dropFirst(prefix.count))
            let base = APIClient.shared.baseURL
            return URL(string: "\(base)/api/workspace/\(rest)")
        }

        return URL(string: trimmed)
    }
}
