import Foundation

struct Agent: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let identityName: String?
    let identityEmoji: String?
    let workspace: String
    let agentDir: String
    let model: String?
    let bindings: Int
    let isDefault: Bool
    let systemPrompt: String?

    var displayName: String {
        identityName ?? name
    }

    var displayEmoji: String {
        identityEmoji ?? "🤖"
    }
}
