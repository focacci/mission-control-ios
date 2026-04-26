import Foundation

// MARK: - AgentEvent (server union mirror)

/// Swift mirror of the server-side `AgentEvent` union — see
/// `mission-control-api/src/agent/events.ts`. Each frame's JSON `data` payload
/// carries a `type` discriminator and the dispatch is keyed on it.
///
/// `tool_use.input` and `tool_result.output` are decoded into `JSONValue` so
/// they can be re-encoded later when step 4 wires live tool rows. For step 2
/// they're decoded but ignored by the reducer.
enum AgentEvent: Decodable, Equatable {
    case sessionStarted(sessionId: String, invocationId: String, runId: String)
    case textDelta(text: String)
    case toolUse(id: String, name: String, input: JSONValue)
    case toolResult(id: String, output: JSONValue, isError: Bool, durationMs: Int, summary: String?)
    case messageComplete(messageId: String)
    case done(tokensIn: Int, tokensOut: Int)
    case error(message: String, code: String?, fatal: Bool)
    case ping(ts: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case sessionId, invocationId, runId
        case text
        case id, name, input
        case output, isError, durationMs, summary
        case messageId
        case tokensIn, tokensOut
        case error, code, fatal
        case ts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "session_started":
            self = .sessionStarted(
                sessionId: try c.decode(String.self, forKey: .sessionId),
                invocationId: try c.decode(String.self, forKey: .invocationId),
                runId: try c.decode(String.self, forKey: .runId)
            )
        case "text_delta":
            self = .textDelta(text: try c.decode(String.self, forKey: .text))
        case "tool_use":
            self = .toolUse(
                id: try c.decode(String.self, forKey: .id),
                name: try c.decode(String.self, forKey: .name),
                input: (try? c.decode(JSONValue.self, forKey: .input)) ?? .null
            )
        case "tool_result":
            self = .toolResult(
                id: try c.decode(String.self, forKey: .id),
                output: (try? c.decode(JSONValue.self, forKey: .output)) ?? .null,
                isError: try c.decode(Bool.self, forKey: .isError),
                durationMs: try c.decode(Int.self, forKey: .durationMs),
                summary: try c.decodeIfPresent(String.self, forKey: .summary)
            )
        case "message_complete":
            self = .messageComplete(messageId: try c.decode(String.self, forKey: .messageId))
        case "done":
            self = .done(
                tokensIn: try c.decode(Int.self, forKey: .tokensIn),
                tokensOut: try c.decode(Int.self, forKey: .tokensOut)
            )
        case "error":
            self = .error(
                message: try c.decode(String.self, forKey: .error),
                code: try c.decodeIfPresent(String.self, forKey: .code),
                fatal: (try c.decodeIfPresent(Bool.self, forKey: .fatal)) ?? false
            )
        case "ping":
            self = .ping(ts: try c.decode(String.self, forKey: .ts))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: c,
                debugDescription: "unknown AgentEvent type: \(type)"
            )
        }
    }
}

// MARK: - JSONValue (lossless JSON shape for tool payloads)

/// Decodes any JSON value. Used for `tool_use.input` and `tool_result.output`
/// where the schema is tool-specific and the consumer only needs to re-encode
/// the raw shape.
indirect enum JSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        throw DecodingError.dataCorruptedError(
            in: c,
            debugDescription: "unknown JSON value"
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null:           try c.encodeNil()
        case .bool(let b):    try c.encode(b)
        case .number(let n):  try c.encode(n)
        case .string(let s):  try c.encode(s)
        case .array(let a):   try c.encode(a)
        case .object(let o):  try c.encode(o)
        }
    }
}

// MARK: - SSE Parser

/// Minimal SSE decoder. Accumulates `data:` lines until a blank line, then
/// decodes the joined payload as `AgentEvent`. Tracks no other fields —
/// dispatch is by the `type` field inside each `data` payload, matching
/// `serialize()` in `src/agent/events.ts`.
struct SSEParser {
    private var dataLines: [String] = []
    private let decoder = JSONDecoder()

    /// Feed one line (without trailing `\n`). Returns the event closed by a
    /// blank-line terminator, otherwise `nil`. Lines starting with `event:` or
    /// a comment (`:`) are ignored — the JSON `type` is authoritative.
    mutating func feed(line: String) -> AgentEvent? {
        if line.isEmpty {
            defer { dataLines.removeAll(keepingCapacity: true) }
            guard !dataLines.isEmpty else { return nil }
            let payload = dataLines.joined(separator: "\n")
            guard let bytes = payload.data(using: .utf8) else { return nil }
            return try? decoder.decode(AgentEvent.self, from: bytes)
        }
        if line.hasPrefix("data:") {
            let start = line.index(line.startIndex, offsetBy: 5)
            var s = String(line[start...])
            if s.hasPrefix(" ") { s.removeFirst() }
            dataLines.append(s)
        }
        return nil
    }
}

// MARK: - Stream result

struct ChatStreamResult {
    let sessionId: String?
    let invocationId: String?
}
