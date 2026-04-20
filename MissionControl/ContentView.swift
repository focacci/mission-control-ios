import SwiftUI

struct ContentView: View {
    @State private var chatContextStore = ChatContextStore()
    @State private var selectedTab = 0

    var body: some View {
        @Bindable var chatContextStore = chatContextStore

        TabView(selection: $selectedTab) {
            HomeView()
                .floatingChatButton(isPresented: $chatContextStore.showingChat)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
                .onAppear { chatContextStore.context = .home }

            DashboardView()
                .floatingChatButton(isPresented: $chatContextStore.showingChat)
                .tabItem { Label("Plan", systemImage: "list.bullet") }
                .tag(1)
                .onAppear { chatContextStore.context = .dashboard(section: "Goals") }

            ScheduleView()
                .floatingChatButton(isPresented: $chatContextStore.showingChat)
                .tabItem { Label("Schedule", systemImage: "calendar") }
                .tag(2)
                .onAppear { chatContextStore.context = .schedule(date: .now) }

            AgentsListView()
                .tabItem { Label("Agents", systemImage: "bubble.left.and.text.bubble.right") }
                .tag(3)
                .onAppear { chatContextStore.context = .agents }

            FaithView()
                .floatingChatButton(isPresented: $chatContextStore.showingChat)
                .tabItem { Label("Faith", systemImage: "cross") }
                .tag(4)
                .onAppear { chatContextStore.context = .faith(section: "Liturgical Calendar") }

            HealthView()
                .floatingChatButton(isPresented: $chatContextStore.showingChat)
                .tabItem { Label("Health", systemImage: "heart") }
                .tag(5)
                .onAppear { chatContextStore.context = .health(section: "Overview") }
        }
        .environment(chatContextStore)
        .sheet(isPresented: $chatContextStore.showingChat) {
            ChatView()
                .environment(chatContextStore)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}
