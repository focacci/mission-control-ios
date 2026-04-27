import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid URL"
        case .httpError(let code):  return "HTTP \(code)"
        case .decodingError(let e): return "Decode error: \(Self.describe(e))"
        case .networkError(let e):  return e.localizedDescription
        case .serverError(let m):   return m
        }
    }

    private static func describe(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else { return error.localizedDescription }
        switch decodingError {
        case .keyNotFound(let key, let ctx):
            return "missing key '\(key.stringValue)' at \(path(ctx.codingPath))"
        case .typeMismatch(let type, let ctx):
            return "type mismatch for \(type) at \(path(ctx.codingPath)) — \(ctx.debugDescription)"
        case .valueNotFound(let type, let ctx):
            return "null value for \(type) at \(path(ctx.codingPath))"
        case .dataCorrupted(let ctx):
            return "data corrupted at \(path(ctx.codingPath)) — \(ctx.debugDescription)"
        @unknown default:
            return decodingError.localizedDescription
        }
    }

    private static func path(_ codingPath: [CodingKey]) -> String {
        codingPath.isEmpty ? "<root>" : codingPath.map(\.stringValue).joined(separator: ".")
    }
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    var baseURL: String {
        get { UserDefaults.standard.string(forKey: "apiBaseURL") ?? "http://10.0.0.12:3737" }
        set { UserDefaults.standard.set(newValue, forKey: "apiBaseURL") }
    }

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }()

    // MARK: - Generic request helpers

    private func url(_ path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        return url
    }

    private func fetch<T: Decodable>(_ path: String) async throws -> T {
        let (data, response) = try await session.data(from: try url(path))
        try validate(response, data: data)
        return try decode(data)
    }

    private func send<T: Decodable>(
        _ path: String,
        method: String,
        body: Encodable? = nil
    ) async throws -> T {
        var req = URLRequest(url: try url(path))
        req.httpMethod = method
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await session.data(for: req)
        try validate(response, data: data)
        return try decode(data)
    }

    private func sendNoBody(_ path: String, method: String, body: Encodable? = nil) async throws {
        var req = URLRequest(url: try url(path))
        req.httpMethod = method
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await session.data(for: req)
        try validate(response, data: data)
    }

    private struct APIErrorBody: Decodable { let error: String }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            if let body = try? JSONDecoder().decode(APIErrorBody.self, from: data) {
                throw APIError.serverError(body.error)
            }
            throw APIError.httpError(http.statusCode)
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Health

    func health() async throws -> ServerHealth {
        try await fetch("/health")
    }

    // MARK: - Goals

    func goals(focus: String? = nil) async throws -> [Goal] {
        var path = "/api/goals"
        if let focus { path += "?focus=\(focus)" }
        return try await fetch(path)
    }

    func goal(id: String) async throws -> Goal {
        try await fetch("/api/goals/\(id)")
    }

    func createGoal(_ body: CreateGoalBody) async throws -> Goal {
        try await send("/api/goals", method: "POST", body: body)
    }

    func updateGoal(id: String, body: UpdateGoalBody) async throws -> Goal {
        try await send("/api/goals/\(id)", method: "PATCH", body: body)
    }

    func deleteGoal(id: String) async throws {
        try await sendNoBody("/api/goals/\(id)", method: "DELETE")
    }

    // MARK: - Initiatives

    func initiatives(goalId: String? = nil, status: String? = nil) async throws -> [Initiative] {
        var parts: [String] = []
        if let g = goalId { parts.append("goalId=\(g)") }
        if let s = status  { parts.append("status=\(s)") }
        let path = "/api/initiatives" + (parts.isEmpty ? "" : "?" + parts.joined(separator: "&"))
        return try await fetch(path)
    }

    func initiative(id: String) async throws -> Initiative {
        try await fetch("/api/initiatives/\(id)")
    }

    func createInitiative(_ body: CreateInitiativeBody) async throws -> Initiative {
        try await send("/api/initiatives", method: "POST", body: body)
    }

    func updateInitiative(id: String, body: UpdateInitiativeBody) async throws -> Initiative {
        try await send("/api/initiatives/\(id)", method: "PATCH", body: body)
    }

    func completeInitiative(id: String) async throws -> Initiative {
        try await send("/api/initiatives/\(id)/complete", method: "POST")
    }

    func deleteInitiative(id: String) async throws {
        try await sendNoBody("/api/initiatives/\(id)", method: "DELETE")
    }

    // MARK: - Tasks

    func tasks(initiativeId: String? = nil, statuses: [String] = []) async throws -> [MCTask] {
        var parts: [String] = []
        if let i = initiativeId { parts.append("initiativeId=\(i)") }
        for s in statuses { parts.append("status=\(s)") }
        let path = "/api/tasks" + (parts.isEmpty ? "" : "?" + parts.joined(separator: "&"))
        return try await fetch(path)
    }

    func task(id: String) async throws -> MCTask {
        try await fetch("/api/tasks/\(id)")
    }

    func createTask(_ body: CreateTaskBody) async throws -> MCTask {
        try await send("/api/tasks", method: "POST", body: body)
    }

    func updateTask(id: String, body: UpdateTaskBody) async throws -> MCTask {
        try await send("/api/tasks/\(id)", method: "PATCH", body: body)
    }

    func completeTask(id: String, body: CompleteTaskBody) async throws -> MCTask {
        try await send("/api/tasks/\(id)/done", method: "POST", body: body)
    }

    func reopenTask(id: String) async throws -> MCTask {
        try await send("/api/tasks/\(id)/reopen", method: "POST")
    }

    func deleteTask(id: String) async throws {
        try await sendNoBody("/api/tasks/\(id)", method: "DELETE")
    }

    // MARK: - Requirements

    func addRequirement(taskId: String, description: String) async throws -> Requirement {
        try await send("/api/tasks/\(taskId)/requirements", method: "POST",
                       body: ["description": description])
    }

    func updateRequirement(reqId: String, description: String) async throws -> Requirement {
        try await send("/api/requirements/\(reqId)", method: "PATCH",
                       body: ["description": description])
    }

    func checkRequirement(reqId: String) async throws -> Requirement {
        try await send("/api/requirements/\(reqId)/check", method: "POST")
    }

    func uncheckRequirement(reqId: String) async throws -> Requirement {
        try await send("/api/requirements/\(reqId)/uncheck", method: "POST")
    }

    func deleteRequirement(reqId: String) async throws {
        try await sendNoBody("/api/requirements/\(reqId)", method: "DELETE")
    }

    // MARK: - Requirement Tests

    func addRequirementTest(reqId: String, description: String) async throws -> RequirementTest {
        try await send("/api/requirements/\(reqId)/tests", method: "POST",
                       body: ["description": description])
    }

    func passRequirementTest(reqId: String, testId: String) async throws -> RequirementTest {
        try await send("/api/requirements/\(reqId)/tests/\(testId)/pass", method: "POST")
    }

    func unpassRequirementTest(reqId: String, testId: String) async throws -> RequirementTest {
        try await send("/api/requirements/\(reqId)/tests/\(testId)/unpass", method: "POST")
    }

    func deleteRequirementTest(reqId: String, testId: String) async throws {
        try await sendNoBody("/api/requirements/\(reqId)/tests/\(testId)", method: "DELETE")
    }

    // MARK: - Agent Assignments

    func agentAssignments(taskId: String) async throws -> [AgentAssignment] {
        try await fetch("/api/tasks/\(taskId)/agent-assignments")
    }

    func agentAssignments(goalId: String) async throws -> [AgentAssignment] {
        try await fetch("/api/goals/\(goalId)/agent-assignments")
    }

    func agentAssignments(initiativeId: String) async throws -> [AgentAssignment] {
        try await fetch("/api/initiatives/\(initiativeId)/agent-assignments")
    }

    func agentAssignment(id: String) async throws -> AgentAssignment {
        try await fetch("/api/agent-assignments/\(id)")
    }

    func createAgentAssignment(taskId: String, body: CreateAgentAssignmentBody) async throws -> AgentAssignment {
        try await send("/api/tasks/\(taskId)/agent-assignments", method: "POST", body: body)
    }

    func createAgentAssignment(goalId: String, body: CreateAgentAssignmentBody) async throws -> AgentAssignment {
        try await send("/api/goals/\(goalId)/agent-assignments", method: "POST", body: body)
    }

    func createAgentAssignment(initiativeId: String, body: CreateAgentAssignmentBody) async throws -> AgentAssignment {
        try await send("/api/initiatives/\(initiativeId)/agent-assignments", method: "POST", body: body)
    }

    func updateAgentAssignment(id: String, body: UpdateAgentAssignmentBody) async throws -> AgentAssignment {
        try await send("/api/agent-assignments/\(id)", method: "PATCH", body: body)
    }

    func startAgentAssignment(id: String) async throws -> AgentAssignment {
        try await send("/api/agent-assignments/\(id)/start", method: "POST")
    }

    func completeAgentAssignment(id: String) async throws -> AgentAssignment {
        try await send("/api/agent-assignments/\(id)/complete", method: "POST")
    }

    func blockAgentAssignment(id: String) async throws -> AgentAssignment {
        try await send("/api/agent-assignments/\(id)/block", method: "POST")
    }

    func reopenAgentAssignment(id: String) async throws -> AgentAssignment {
        try await send("/api/agent-assignments/\(id)/reopen", method: "POST")
    }

    func unassignAgentAssignment(id: String) async throws -> AgentAssignment {
        try await send("/api/agent-assignments/\(id)/unassign", method: "POST")
    }

    func deleteAgentAssignment(id: String) async throws {
        try await sendNoBody("/api/agent-assignments/\(id)", method: "DELETE")
    }

    // MARK: - Slot Outputs

    func addSlotOutput(slotId: String, body: SlotOutputBody) async throws -> SlotOutput {
        try await send("/api/schedule/slots/\(slotId)/outputs", method: "POST", body: body)
    }

    func deleteSlotOutput(slotId: String, outputId: String) async throws {
        try await sendNoBody("/api/schedule/slots/\(slotId)/outputs/\(outputId)", method: "DELETE")
    }

    // MARK: - Schedule

    func scheduleToday() async throws -> [ScheduleSlot] {
        try await fetch("/api/schedule/today")
    }

    func scheduleWeek(weekStart: String? = nil) async throws -> WeekResponse {
        var path = "/api/schedule/week"
        if let ws = weekStart { path += "?weekStart=\(ws)" }
        return try await fetch(path)
    }

    func scheduleRange(from: String, to: String) async throws -> RangeResponse {
        try await fetch("/api/schedule/range?from=\(from)&to=\(to)")
    }

    func generateWeekPlan(weekStart: String? = nil) async throws -> GenerateWeekResponse {
        let body = weekStart.map { ["weekStart": $0] } ?? [:]
        return try await send("/api/schedule/generate", method: "POST", body: body)
    }

    func doneSlot(id: String, note: String? = nil) async throws -> ScheduleSlot {
        try await send("/api/schedule/slots/\(id)/done", method: "POST",
                       body: note.map { ["note": $0] } ?? [:])
    }

    func skipSlot(id: String, reason: String? = nil) async throws -> ScheduleSlot {
        try await send("/api/schedule/slots/\(id)/skip", method: "POST",
                       body: reason.map { ["reason": $0] } ?? [:])
    }

    func assignAgentAssignment(agentAssignmentId: String, slotId: String) async throws -> ScheduleSlot {
        try await send("/api/schedule/assign", method: "POST",
                       body: AssignAgentAssignmentBody(agentAssignmentId: agentAssignmentId, slotId: slotId))
    }

    func unassignAgentAssignment(slotId: String) async throws -> ScheduleSlot {
        try await send("/api/schedule/slots/\(slotId)/assignment", method: "DELETE")
    }

    // MARK: - Board

    func board() async throws -> BoardResponse {
        try await fetch("/api/board")
    }

    // MARK: - Agents

    func agents() async throws -> [Agent] {
        try await fetch("/api/agents")
    }

    func agent(id: String) async throws -> Agent {
        try await fetch("/api/agents/\(id)")
    }

    func createAgent(_ body: CreateAgentBody) async throws -> Agent {
        try await send("/api/agents", method: "POST", body: body)
    }

    func updateAgent(id: String, body: UpdateAgentBody) async throws -> Agent {
        try await send("/api/agents/\(id)", method: "PATCH", body: body)
    }

    func deleteAgent(id: String) async throws {
        try await sendNoBody("/api/agents/\(id)", method: "DELETE")
    }

    func repairAgents() async throws -> [Agent] {
        try await send("/api/agents/repair", method: "POST")
    }

    // MARK: - Chat Sessions

    func chatSessions(
        agentId: String? = nil,
        contextType: String? = nil,
        contextId: String? = nil,
        limit: Int? = nil
    ) async throws -> [ChatSession] {
        var parts: [String] = []
        if let a = agentId { parts.append("agentId=\(a)") }
        if let t = contextType { parts.append("contextType=\(t)") }
        if let c = contextId { parts.append("contextId=\(c)") }
        if let l = limit { parts.append("limit=\(l)") }
        let path = "/api/chat/sessions" + (parts.isEmpty ? "" : "?" + parts.joined(separator: "&"))
        return try await fetch(path)
    }

    func chatSession(id: String) async throws -> ChatSession {
        try await fetch("/api/chat/sessions/\(id)")
    }

    func createChatSession(
        agentId: String,
        contextType: String? = nil,
        contextId: String? = nil,
        title: String? = nil
    ) async throws -> ChatSession {
        let body = CreateSessionBody(
            agentId: agentId,
            contextType: contextType,
            contextId: contextId,
            title: title
        )
        return try await send("/api/chat/sessions", method: "POST", body: body)
    }

    func chatMessages(
        sessionId: String,
        limit: Int? = nil,
        before: String? = nil
    ) async throws -> [ChatTranscriptMessage] {
        var parts: [String] = []
        if let l = limit { parts.append("limit=\(l)") }
        if let b = before { parts.append("before=\(b)") }
        let qs = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await fetch("/api/chat/sessions/\(sessionId)/messages\(qs)")
    }

    func deleteChatSession(id: String) async throws {
        try await sendNoBody("/api/chat/sessions/\(id)", method: "DELETE")
    }

    // MARK: - Invocations

    func invocations(
        trigger: String? = nil,
        status: String? = nil,
        limit: Int? = nil,
        since: String? = nil
    ) async throws -> [AgentInvocation] {
        var parts: [String] = []
        if let t = trigger { parts.append("trigger=\(t)") }
        if let s = status { parts.append("status=\(s)") }
        if let l = limit { parts.append("limit=\(l)") }
        if let si = since { parts.append("since=\(si)") }
        let path = "/api/invocations" + (parts.isEmpty ? "" : "?" + parts.joined(separator: "&"))
        return try await fetch(path)
    }

    func invocation(id: String) async throws -> InvocationDetail {
        try await fetch("/api/invocations/\(id)")
    }

    func cancelInvocation(id: String) async throws {
        try await sendNoBody("/api/invocations/\(id)/cancel", method: "POST")
    }
}

// MARK: - Request Bodies

struct CreateGoalBody: Encodable {
    let emoji: String
    let name: String
    let focus: String?
    let timeline: String?
    let story: String?
}

struct UpdateGoalBody: Encodable {
    let emoji: String?
    let name: String?
    let focus: String?
    let timeline: String?
    let story: String?
}

struct CreateInitiativeBody: Encodable {
    let emoji: String
    let name: String
    let goalId: String?
    let mission: String?
    let status: String?
}

struct UpdateInitiativeBody: Encodable {
    let emoji: String?
    let name: String?
    let status: String?
    let mission: String?
    let goalId: String?
}

struct CreateTaskBody: Encodable {
    let name: String
    let objective: String
    let initiativeId: String?
    let emoji: String?
    let requirements: [String]?
}

struct UpdateTaskBody: Encodable {
    let name: String?
    let objective: String?
    let status: String?
}

struct CompleteTaskBody: Encodable {
    let summary: String
}

struct AssignAgentAssignmentBody: Encodable {
    let agentAssignmentId: String
    let slotId: String
}

struct CreateAgentAssignmentBody: Encodable {
    let title: String
    let instructions: String
    let agentId: String?
}

struct UpdateAgentAssignmentBody: Encodable {
    let title: String?
    let instructions: String?
    let agentId: String?
    let sortOrder: Int?
}

struct SlotOutputBody: Encodable {
    let label: String
    let url: String?
    let kind: String
}

struct CreateAgentBody: Encodable {
    let name: String
    let model: String
    let systemPrompt: String?
}

struct UpdateAgentBody: Encodable {
    let systemPrompt: String?
}

struct CreateSessionBody: Encodable {
    let agentId: String
    let contextType: String?
    let contextId: String?
    let title: String?
}
