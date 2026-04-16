struct ServerHealth: Codable {
    let status: String
    let goals: Int?

    var isHealthy: Bool { status == "ok" }
}
