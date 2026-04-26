import Foundation

/// Drives `POST /api/chat/stream`. Opens an SSE connection, feeds bytes through
/// `SSEParser`, and dispatches each decoded `AgentEvent` to the supplied
/// `apply` closure on the main actor.
///
/// Throws only for transport failures *before* the first frame; mid-stream
/// errors arrive as `.error` events through `apply` so the caller can fold
/// them into the in-memory turn.
@MainActor
final class ChatStream {
    /// Dedicated session for SSE. `URLSession.shared` defaults
    /// `timeoutIntervalForRequest` to 60s — too short for chat turns where the
    /// server may go silent between heartbeats. `URLRequest.timeoutInterval`
    /// sometimes fails to override the session config for streaming
    /// contexts, so we set both at the session level explicitly.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600        // idle gap between frames
        config.timeoutIntervalForResource = 24 * 3600 // total stream lifetime
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpAdditionalHeaders = ["Accept": "text/event-stream"]
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// Open the stream and reduce events into the supplied closure. Returns
    /// the final session/invocation ids observed via `session_started`. The
    /// loop exits on `.done` or `.error(fatal: true)`.
    func run(
        message: String,
        context: ChatContextKind,
        sessionId: String?,
        useDefaultAgent: Bool,
        apply: @MainActor (AgentEvent) -> Void
    ) async throws -> ChatStreamResult {
        guard let url = URL(string: APIClient.shared.baseURL + "/api/chat/stream") else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 600

        let body = ChatRequestBuilder.body(
            message: message,
            context: context,
            sessionId: sessionId,
            useDefaultAgent: useDefaultAgent
        )
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (byteStream, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (byteStream, response) = try await Self.session.bytes(for: req)
        } catch {
            print("[ChatStream] bytes(for:) failed: \(error)")
            throw error
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[ChatStream] non-2xx response: \(code)")
            throw APIError.httpError(code)
        }

        var parser = SSEParser()
        var observedSession: String?
        var observedInvocation: String?

        // We iterate raw bytes and split on `\n` ourselves rather than using
        // `byteStream.lines`. `AsyncLineSequence` silently drops blank lines
        // (verified empirically: an SSE response of `event:\ndata:\n\n…`
        // yields only the two non-empty lines per frame). The SSE parser
        // depends on the blank line as a frame terminator, so with `.lines`
        // no frame ever closes, no `AgentEvent` is ever emitted, and the
        // typing indicator hangs forever. R1 of IOS_STREAM_CONSUMER_PLAN.md
        // anticipated this.
        var lineBuf: [UInt8] = []
        lineBuf.reserveCapacity(1024)
        var shouldStop = false

        func flushLine() {
            // Strip optional trailing `\r` for `\r\n` framing.
            if lineBuf.last == 0x0D { lineBuf.removeLast() }
            let line = String(decoding: lineBuf, as: UTF8.self)
            lineBuf.removeAll(keepingCapacity: true)
            if let event = parser.feed(line: line) {
                if case .sessionStarted(let sid, let invId, _) = event {
                    observedSession = sid
                    observedInvocation = invId
                }
                apply(event)
                if case .done = event { shouldStop = true }
                if case .error(_, _, let fatal) = event, fatal { shouldStop = true }
            }
        }

        do {
            for try await byte in byteStream {
                if byte == 0x0A { // \n
                    flushLine()
                    if shouldStop { break }
                } else {
                    lineBuf.append(byte)
                }
            }
            // Flush a trailing partial line on stream close (no terminating \n).
            if !lineBuf.isEmpty { flushLine() }
        } catch {
            print("[ChatStream] byte iterator failed: \(error)")
            throw error
        }

        return ChatStreamResult(
            sessionId: observedSession,
            invocationId: observedInvocation
        )
    }
}
