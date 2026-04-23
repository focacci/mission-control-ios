import SwiftUI

enum ChatContextKind: Equatable {
    case app
    case home
    case agents
    case agent(id: String, name: String, emoji: String)
    case agentChat(id: String, name: String, emoji: String)
    case plans(section: String)
    case goal(id: String, emoji: String, name: String)
    case initiative(id: String, emoji: String, name: String)
    case task(id: String, name: String)
    case schedule(date: Date, mode: ScheduleViewMode)
    case health(section: String)
    case faith(section: String)
    case briefs
    case brief(kind: DailyBrief, date: Date)
    case settings(section: String)
    /// User profile page — long-running picture the agent has built of the
    /// user: tendencies, strengths/weaknesses, favorite places/activities,
    /// and the purpose behind their goals. Grounding here tells the agent to
    /// reason about the "why" behind the user.
    case profile(section: String)
    /// The "More" tab's custom landing page — a list of features (Faith,
    /// Health, Briefings, …) that aren't pinned to the main tab bar. The
    /// associated list is the feature names so the agent knows which
    /// features the user has available.
    case featureList(features: [String])
    /// Saved-groups management surface. A Context Group bundles multiple
    /// `ChatContextKind` selections so a chat can be grounded on all of them
    /// at once. The floating chat's context panel exposes them under "Saved
    /// Groups"; this context marks the page where they're created and curated.
    case contextGroups

    /// OpenClaw agent the chat should route through. `nil` means use the
    /// API's default agent (currently `intella`).
    var agentId: String? {
        if case .agent(let id, _, _) = self { return id }
        if case .agentChat(let id, _, _) = self { return id }
        return nil
    }

    /// `contextType` value persisted alongside chat sessions on the API side.
    /// Kept in sync with `ChatService.contextTypeString` — change them together.
    var contextType: String {
        switch self {
        case .app:          return "app"
        case .home:         return "home"
        case .agents:       return "agents"
        case .agent:        return "agent"
        case .agentChat:    return "agent_chat"
        case .plans:        return "plans"
        case .goal:         return "goal"
        case .initiative:   return "initiative"
        case .task:         return "task"
        case .schedule:     return "schedule"
        case .health:       return "health"
        case .faith:        return "faith"
        case .briefs:       return "briefs"
        case .brief:        return "brief"
        case .featureList:  return "feature_list"
        case .contextGroups:return "context_groups"
        case .settings:     return "settings"
        case .profile:      return "profile"
        }
    }

    /// The concrete entity id this context points at, when applicable.
    var contextId: String? {
        switch self {
        case .goal(let id, _, _),
             .initiative(let id, _, _),
             .task(let id, _),
             .agent(let id, _, _),
             .agentChat(let id, _, _):
            return id
        default:
            return nil
        }
    }
}

enum AgentConnectionState: Equatable {
    case connecting
    case connected
    case offline
}

@Observable
final class ChatContextStore {
    /// The page the user is currently viewing. Maintained by the
    /// `chatContext(_:)` view modifier. This is *not* automatically applied
    /// as the chat's grounding — it only drives page-level toolbar pills and
    /// the "Current" card in the floating chat's context picker. To ground
    /// the chat on this page, the user must explicitly select it from the
    /// picker (adding it to `selectedContexts`).
    var pageContext: ChatContextKind = .app

    var showingChat: Bool = false
    var isLocked: Bool = false

    /// Contexts the user has selected to ground the floating chat, in the
    /// order they were added (most recently selected is last). Empty means
    /// the chat runs without context grounding. Cleared by `ContentView` on
    /// sheet dismissal when the chat is unlocked; preserved across dismissals
    /// when locked.
    var selectedContexts: [ChatContextKind] = []

    /// Most recently selected context — used as the primary grounding for
    /// chat routing and the welcome message. `nil` when nothing is selected.
    var primarySelectedContext: ChatContextKind? { selectedContexts.last }

    func isSelected(_ kind: ChatContextKind) -> Bool {
        selectedContexts.contains(kind)
    }

    func toggleSelected(_ kind: ChatContextKind) {
        if let idx = selectedContexts.firstIndex(of: kind) {
            selectedContexts.remove(at: idx)
        } else {
            selectedContexts.append(kind)
        }
    }

    /// Contexts the user has pinned from a page's context toolbar button.
    /// Surfaces in the floating chat's context panel (Pinned section) and on
    /// the Context Groups page (Pinned section) so they're one tap away.
    /// Persistence lands with the backend; in-memory for now.
    var pinnedContexts: [ChatContextKind] = []

    func isPinned(_ kind: ChatContextKind) -> Bool {
        pinnedContexts.contains(kind)
    }

    func togglePinned(_ kind: ChatContextKind) {
        if let idx = pinnedContexts.firstIndex(of: kind) {
            pinnedContexts.remove(at: idx)
        } else {
            pinnedContexts.append(kind)
        }
    }

    func unpin(_ kind: ChatContextKind) {
        if let idx = pinnedContexts.firstIndex(of: kind) {
            pinnedContexts.remove(at: idx)
        }
    }

    /// User-created Context Groups. Each bundles several `ChatContextKind`
    /// selections so they can be applied together when grounding a chat.
    /// In-memory until the backend lands.
    var contextGroups: [ContextGroup] = []

    func isKind(_ kind: ChatContextKind, inGroup groupId: ContextGroup.ID) -> Bool {
        guard let group = contextGroups.first(where: { $0.id == groupId }) else { return false }
        return group.members.contains { $0.matches(kind) }
    }

    func toggleKind(_ kind: ChatContextKind, inGroup groupId: ContextGroup.ID) {
        guard let gIdx = contextGroups.firstIndex(where: { $0.id == groupId }) else { return }
        if let mIdx = contextGroups[gIdx].members.firstIndex(where: { $0.matches(kind) }) {
            contextGroups[gIdx].members.remove(at: mIdx)
        } else {
            contextGroups[gIdx].members.append(
                ContextGroupMember(
                    label: label(for: kind),
                    icon: icon(for: kind),
                    contextType: kind.contextType,
                    contextId: kind.contextId
                )
            )
        }
    }

    @discardableResult
    func createGroup(name: String, icon: String = "point.3.connected.trianglepath.dotted", summary: String = "", members: [ContextGroupMember] = []) -> ContextGroup {
        let group = ContextGroup(name: name, icon: icon, summary: summary, members: members)
        contextGroups.append(group)
        return group
    }

    /// Live connection state for the selected agent. Drives the agent picker
    /// toolbar icon. Mocked on chat open until real transport lands.
    var agentConnectionState: AgentConnectionState = .offline

    /// Agent the floating chat should route through. `nil` falls back to the
    /// workspace default (`intella`). Chosen from the agent picker panel in
    /// the floating chat toolbar.
    var selectedAgentId: String? = nil
    var selectedAgentName: String? = nil
    var selectedAgentEmoji: String? = nil

    /// Persistent conversation state for the floating chat sheet. Survives
    /// sheet dismissals so that locking preserves history; cleared by
    /// `ContentView` when the sheet closes unlocked.
    let floatingChat = ChatConversationState()

    // MARK: - Page-context display (drives toolbar pill + picker "Current" card)

    var displayLabel: String { label(for: pageContext) }
    var displayIcon: String { icon(for: pageContext) }
    var contextTypeName: String { typeName(for: pageContext) }

    func label(for kind: ChatContextKind) -> String {
        switch kind {
        case .app:                       return "Mission Control"
        case .home:
            return Date().formatted(.dateTime.weekday(.wide).month().day())
        case .agents:                    return "List"
        case .agent(_, let n, _):        return n
        case .agentChat(_, let n, _):    return n
        case .plans(let s):              return s
        case .goal(_, _, let n):         return n
        case .initiative(_, _, let n):   return n
        case .task(_, let n):         return n
        case .schedule(let d, let m):
            let f = DateFormatter()
            switch m {
            case .day:   f.dateFormat = "EEE, MMM d"
            case .month: f.dateFormat = "MMMM yyyy"
            case .year:  f.dateFormat = "yyyy"
            }
            return f.string(from: d)
        case .health(let s):             return s
        case .faith(let s):              return s
        case .briefs:                    return "List"
        case .brief(_, let d):
            return d.formatted(.dateTime.month(.abbreviated).day())
        case .featureList:               return "Features"
        case .contextGroups:             return "Groups"
        case .settings(let s):           return s
        case .profile(let s):            return s
        }
    }

    func icon(for kind: ChatContextKind) -> String {
        switch kind {
        case .app:          return "cpu"
        case .home:         return "house"
        case .agents:       return "person.2.wave.2"
        case .agent:        return "person.wave.2"
        case .agentChat:    return "bubble.left.and.text.bubble.right"
        case .plans:        return "list.bullet"
        case .goal:         return "trophy"
        case .initiative:   return "flag.pattern.checkered"
        case .task:         return "list.bullet.clipboard"
        case .schedule:     return "calendar"
        case .health:       return "heart"
        case .faith:        return "cross"
        case .briefs:       return "briefcase"
        case .brief(let k, _):
            switch k {
            case .morning:   return "sunrise"
            case .afternoon: return "sun.max"
            case .evening:   return "moon.stars"
            }
        case .featureList:  return "ellipsis"
        case .contextGroups: return "point.3.connected.trianglepath.dotted"
        case .settings:     return "gearshape"
        case .profile:      return "person.text.rectangle"
        }
    }

    func typeName(for kind: ChatContextKind) -> String {
        switch kind {
        case .app:          return "App"
        case .home:         return "Home"
        case .agents:       return "Agents"
        case .agent:        return "Agent Details"
        case .agentChat:    return "Agent Chat"
        case .plans:        return "Plans"
        case .goal:         return "Goal"
        case .initiative:   return "Initiative"
        case .task:         return "Task"
        case .schedule(_, let m):
            switch m {
            case .day:   return "Schedule - Day"
            case .month: return "Schedule - Month"
            case .year:  return "Schedule - Year"
            }
        case .health:       return "Health"
        case .faith:        return "Faith"
        case .briefs:       return "Briefings"
        case .brief(let k, _):
            switch k {
            case .morning:   return "Morning Brief"
            case .afternoon: return "Afternoon Brief"
            case .evening:   return "Evening Brief"
            }
        case .featureList:  return "Features"
        case .contextGroups: return "Context Groups"
        case .settings:     return "Settings"
        case .profile:      return "Profile"
        }
    }

    // MARK: - Selected-context driven

    /// Greeting for a fresh floating chat thread. Keys off the user's
    /// selected grounding; falls back to a generic greeting when nothing is
    /// selected (same copy as `.app`).
    var welcomeMessage: String {
        welcomeMessage(for: primarySelectedContext ?? .app)
    }

    func welcomeMessage(for kind: ChatContextKind) -> String {
        switch kind {
        case .goal(_, _, let name):
            return "I can see you're looking at the **\(name)** goal. I can suggest new initiatives, help you prioritize, or review progress. What do you need?"
        case .initiative(_, _, let name):
            return "You've got **\(name)** open. I can suggest tasks you might have missed, check for blockers, or help you move things forward."
        case .task(_, let name):
            return "Looking at **\(name)**. I can help you break it down, draft requirements, or mark it done. What's up?"
        case .schedule(let d, let m):
            let f = DateFormatter()
            switch m {
            case .day:
                f.dateFormat = "EEEE"
                return "You're looking at **\(f.string(from: d))**'s schedule. I can fill open slots with high-priority tasks or help you rearrange things."
            case .month:
                f.dateFormat = "MMMM yyyy"
                return "You're looking at **\(f.string(from: d))**. I can help you plan themes for the month, or zoom in on a day."
            case .year:
                f.dateFormat = "yyyy"
                return "You're looking at **\(f.string(from: d))** at a glance. I can help you plan quarterly initiatives or review how the year is shaping up."
            }
        case .health(let s):
            return "You're in **\(s)**. I can help you log entries, spot patterns, or set targets."
        case .plans(let s):
            return "You're in the **\(s)** view. I can help you create, organize, or prioritize items."
        case .faith(let s):
            return "You're in **\(s)**. I can help you reflect on scripture, find a prayer, or explore the liturgical calendar."
        case .home:
            return "Good to see you. What's on your mind today?"
        case .agents:
            return "Hey! What do you want to work through? Goals, tasks, schedule — I'm ready."
        case .agent(_, let name, _):
            return "You're looking at **\(name)**'s details. I can explain how this agent is configured or help you tune it."
        case .agentChat(_, let name, _):
            return "You're chatting with **\(name)**. What can I help you with?"
        case .briefs:
            return "Browsing your briefings. I can summarize a day, compare briefings, or pull out what's actionable."
        case .brief(let k, let d):
            let label: String = {
                switch k {
                case .morning:   return "morning brief"
                case .afternoon: return "afternoon brief"
                case .evening:   return "evening brief"
                }
            }()
            let dateStr = d.formatted(.dateTime.month(.wide).day())
            return "Looking at your **\(label)** for \(dateStr). I can dig into any item, reprioritize, or draft follow-ups."
        case .app:
            return "Hey! I'm your Mission Control agent. I can help with goals, tasks, scheduling, and more. What do you need?"
        case .featureList(let features):
            if features.isEmpty {
                return "You're on your feature list — no optional features enabled yet. What would you like to work on?"
            }
            let list = features.map { "**\($0)**" }.joined(separator: ", ")
            return "You're on your feature list. You have \(list) available. Ask me to jump into one or to help you organize them."
        case .contextGroups:
            return "You're in **Context Groups**. I can help you bundle related contexts — goals, schedules, briefs — into saved groups you can reuse to ground chats."
        case .settings(let s):
            return "You're in **\(s)** settings. I can help you configure the API connection, troubleshoot, or walk through your options."
        case .profile(let s):
            return "You're on your profile's **\(s)** view. Ask me why something here is on file, correct anything I've gotten wrong, or have me reason about how it should shape today's plan."
        }
    }
}

// MARK: - View Modifier

extension View {
    /// Binds the current view to a chat context. Safe to pass `nil` while data
    /// is loading — the context is applied on appear and whenever `kind` changes.
    func chatContext(_ kind: ChatContextKind?) -> some View {
        modifier(ChatContextModifier(kind: kind))
    }
}

private struct ChatContextModifier: ViewModifier {
    @Environment(ChatContextStore.self) private var store
    let kind: ChatContextKind?

    func body(content: Content) -> some View {
        content
            .onAppear {
                if let kind { store.pageContext = kind }
            }
            .onChange(of: kind) { _, newKind in
                if let newKind { store.pageContext = newKind }
            }
    }
}
