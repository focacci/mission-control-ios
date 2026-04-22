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

@Observable
final class ChatContextStore {
    var context: ChatContextKind = .app
    var showingChat: Bool = false
    var isLocked: Bool = false

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

    var displayLabel: String {
        switch context {
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
            case .week:
                let cal = Calendar.current
                let weekday = cal.component(.weekday, from: d) - 1
                let sunday = cal.date(byAdding: .day, value: -weekday, to: d) ?? d
                f.dateFormat = "MMM d"
                return "Week of \(f.string(from: sunday))"
            case .month: f.dateFormat = "MMMM yyyy"
            case .year:  f.dateFormat = "yyyy"
            }
            return f.string(from: d)
        case .health(let s):             return s
        case .faith(let s):              return s
        }
    }

    var displayIcon: String {
        switch context {
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
        }
    }

    var contextTypeName: String {
        switch context {
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
            case .week:  return "Schedule - Week"
            case .month: return "Schedule - Month"
            case .year:  return "Schedule - Year"
            }
        case .health:       return "Health"
        case .faith:        return "Faith"
        }
    }

    var welcomeMessage: String {
        switch context {
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
            case .week:
                let cal = Calendar.current
                let weekday = cal.component(.weekday, from: d) - 1
                let sunday = cal.date(byAdding: .day, value: -weekday, to: d) ?? d
                f.dateFormat = "MMM d"
                return "You're looking at the **week of \(f.string(from: sunday))**. I can help rebalance tasks across days or spot under-booked slots."
            case .month:
                f.dateFormat = "MMMM yyyy"
                return "You're looking at **\(f.string(from: d))**. I can help you plan themes for the month, or zoom in on a week or day."
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
        case .app:
            return "Hey! I'm your Mission Control agent. I can help with goals, tasks, scheduling, and more. What do you need?"
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
                if let kind { store.context = kind }
            }
            .onChange(of: kind) { _, newKind in
                if let newKind { store.context = newKind }
            }
    }
}
