import SwiftUI

@main
struct MissionControlWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}

struct WatchContentView: View {
    var body: some View {
        TabView {
            WatchGoalList()
            WatchTaskList()
        }
        .tabViewStyle(.page)
    }
}
