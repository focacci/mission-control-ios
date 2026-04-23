struct ServerHealth: Codable {
    let status: String
    let goals: Int?
    /// Phase 2+: reports whether the WS connection to the OpenClaw gateway is
    /// live. Absent on pre-slice-2 API builds.
    let gateway: Gateway?

    var isHealthy: Bool { status == "ok" }

    struct Gateway: Codable {
        let connected: Bool
        let lastHelloAt: String?
        let deviceTokenPresent: Bool
    }
}
