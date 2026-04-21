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

            PlansView()
                .floatingChatButton(isPresented: $chatContextStore.showingChat)
                .tabItem { Label("Plans", systemImage: "list.bullet") }
                .tag(1)

            ScheduleView()
                .floatingChatButton(isPresented: $chatContextStore.showingChat)
                .tabItem { Label("Schedule", systemImage: "calendar") }
                .tag(2)

            AgentsListView()
                .tabItem { Label("Agents", systemImage: "person.2.wave.2") }
                .tag(3)

            FaithView()
                .floatingChatButton(isPresented: $chatContextStore.showingChat)
                .tabItem { Label("Faith", systemImage: "cross") }
                .tag(4)

            HealthView()
                .floatingChatButton(isPresented: $chatContextStore.showingChat)
                .tabItem { Label("Health", systemImage: "heart") }
                .tag(5)
        }
        .environment(chatContextStore)
        .sheet(isPresented: $chatContextStore.showingChat) {
            NavigationStack {
                ChatView()
                    .environment(chatContextStore)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}
