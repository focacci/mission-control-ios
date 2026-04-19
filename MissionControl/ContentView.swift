import SwiftUI

struct ContentView: View {
    @State private var chatContextStore = ChatContextStore()
    @State private var showingChat = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house") }
                    .onAppear { chatContextStore.context = .home }

                DashboardView()
                    .tabItem { Label("Plan", systemImage: "list.bullet") }
                    .onAppear { chatContextStore.context = .dashboard(section: "Goals") }

                ScheduleView()
                    .tabItem { Label("Schedule", systemImage: "calendar") }
                    .onAppear { chatContextStore.context = .schedule(date: .now) }

                FaithView()
                    .tabItem { Label("Faith", systemImage: "cross") }
                    .onAppear { chatContextStore.context = .faith(section: "Liturgical Calendar") }

                HealthView()
                    .tabItem { Label("Health", systemImage: "heart") }
                    .onAppear { chatContextStore.context = .health(section: "Overview") }
            }
            .environment(chatContextStore)

            FloatingChatButton(isPresented: $showingChat)
        }
        .sheet(isPresented: $showingChat) {
            ChatView()
                .environment(chatContextStore)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}
