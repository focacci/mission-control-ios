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
        case .decodingError(let e): return "Decode error: \(e.localizedDescription)"
        case .networkError(let e):  return e.localizedDescription
        case .serverError(let m):   return m
        }
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

    func startTask(id: String) async throws -> MCTask {
        try await send("/api/tasks/\(id)/start", method: "POST")
    }

    func completeTask(id: String, body: CompleteTaskBody) async throws -> MCTask {
        try await send("/api/tasks/\(id)/done", method: "POST", body: body)
    }

    func blockTask(id: String, reason: String) async throws -> MCTask {
        try await send("/api/tasks/\(id)/block", method: "POST", body: ["reason": reason])
    }

    func cancelTask(id: String) async throws -> MCTask {
        try await send("/api/tasks/\(id)/cancel", method: "POST")
    }

    func deleteTask(id: String) async throws {
        try await sendNoBody("/api/tasks/\(id)", method: "DELETE")
    }

    // MARK: - Requirements

    func addRequirement(taskId: String, description: String) async throws -> Requirement {
        try await send("/api/tasks/\(taskId)/requirements", method: "POST",
                       body: ["description": description])
    }

    func checkRequirement(taskId: String, reqId: String) async throws -> Requirement {
        try await send("/api/tasks/\(taskId)/requirements/\(reqId)/check", method: "POST")
    }

    func uncheckRequirement(taskId: String, reqId: String) async throws -> Requirement {
        try await send("/api/tasks/\(taskId)/requirements/\(reqId)/uncheck", method: "POST")
    }

    func deleteRequirement(taskId: String, reqId: String) async throws {
        try await sendNoBody("/api/tasks/\(taskId)/requirements/\(reqId)", method: "DELETE")
    }

    // MARK: - Tests

    func addTest(taskId: String, description: String) async throws -> TaskTest {
        try await send("/api/tasks/\(taskId)/tests", method: "POST",
                       body: ["description": description])
    }

    func deleteTest(taskId: String, testId: String) async throws {
        try await sendNoBody("/api/tasks/\(taskId)/tests/\(testId)", method: "DELETE")
    }

    // MARK: - Outputs

    func addOutput(taskId: String, label: String, url: String?) async throws -> TaskOutput {
        var body: [String: String?] = ["label": label]
        body["url"] = url
        // Use a concrete Encodable wrapper
        return try await send("/api/tasks/\(taskId)/outputs", method: "POST",
                              body: OutputBody(label: label, url: url))
    }

    func deleteOutput(taskId: String, outputId: String) async throws {
        try await sendNoBody("/api/tasks/\(taskId)/outputs/\(outputId)", method: "DELETE")
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

    func assignTask(taskId: String, slotId: String) async throws -> ScheduleSlot {
        try await send("/api/schedule/assign", method: "POST",
                       body: AssignTaskBody(taskId: taskId, slotId: slotId))
    }

    // MARK: - Board

    func board() async throws -> BoardResponse {
        try await fetch("/api/board")
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
    let tests: [String]?
}

struct UpdateTaskBody: Encodable {
    let name: String?
    let objective: String?
    let status: String?
}

struct CompleteTaskBody: Encodable {
    let summary: String
    let outputs: [OutputBody]
}

struct OutputBody: Encodable {
    let label: String
    let url: String?
}

struct AssignTaskBody: Encodable {
    let taskId: String
    let slotId: String
}
