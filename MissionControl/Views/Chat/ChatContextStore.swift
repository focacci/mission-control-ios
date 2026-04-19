import SwiftUI

enum ChatContextKind: Equatable {
    case app
    case home
    case dashboard(section: String)
    case goal(id: String, emoji: String, name: String)
    case initiative(id: String, emoji: String, name: String)
    case task(id: String, emoji: String, name: String)
    case schedule(date: Date)
    case health(section: String)
    case faith(section: String)
}

@Observable
final class ChatContextStore {
    var context: ChatContextKind = .app

    var displayLabel: String {
        switch context {
        case .app:                       return "Mission Control"
        case .home:                      return "Home"
        case .dashboard(let s):          return s
        case .goal(_, _, let n):         return n
        case .initiative(_, _, let n):   return n
        case .task(_, _, let n):         return n
        case .schedule(let d):
            let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
            return f.string(from: d)
        case .health(let s):             return s
        case .faith(let s):              return s
        }
    }

    var displayIcon: String {
        switch context {
        case .app:          return "cpu"
        case .home:         return "house"
        case .dashboard:    return "list.bullet"
        case .goal:         return "target"
        case .initiative:   return "flag"
        case .task:         return "checkmark.square"
        case .schedule:     return "calendar"
        case .health:       return "heart"
        case .faith:        return "cross"
        }
    }

    var displayEmoji: String? {
        switch context {
        case .goal(_, let e, _),
             .initiative(_, let e, _),
             .task(_, let e, _):
            return e.isEmpty ? nil : e
        default:
            return nil
        }
    }

    var contextTypeName: String {
        switch context {
        case .app, .home:   return "App"
        case .dashboard:    return "Plan"
        case .goal:         return "Goal"
        case .initiative:   return "Initiative"
        case .task:         return "Task"
        case .schedule:     return "Schedule"
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
        case .task(_, _, let name):
            return "Looking at **\(name)**. I can help you break it down, draft requirements, or mark it done. What's up?"
        case .schedule(let d):
            let f = DateFormatter(); f.dateFormat = "EEEE"
            return "You're looking at **\(f.string(from: d))**'s schedule. I can fill open slots with high-priority tasks or help you rearrange things."
        case .health(let s):
            return "You're in **\(s)**. I can help you log entries, spot patterns, or set targets."
        case .dashboard(let s):
            return "You're in the **\(s)** view. I can help you create, organize, or prioritize items."
        case .faith:
            return "You're in Faith. I can help you reflect on scripture, find prayers, or explore the liturgical calendar."
        case .home:
            return "Good to see you. What's on your mind today?"
        case .app:
            return "Hey! I'm your Mission Control agent. I can help with goals, tasks, scheduling, and more. What do you need?"
        }
    }
}
