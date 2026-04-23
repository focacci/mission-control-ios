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
                .tag(2)

            ScheduleView()
                .floatingChatButton(isPresented: $chatContextStore.showingChat)
                .tabItem { Label("Schedule", systemImage: "calendar") }
                .tag(3)

            AgentsListView()
                .tabItem { Label("Agents", systemImage: "person.2.wave.2") }
                .tag(4)

            FeatureListView()
                .floatingChatButton(isPresented: $chatContextStore.showingChat)
                .tabItem { Label("More", systemImage: "ellipsis") }
                .tag(5)
        }
        .environment(chatContextStore)
        .sheet(isPresented: $chatContextStore.showingChat, onDismiss: {
            // Locking preserves chat history and selected grounding across
            // sheet dismissals. Unlocked dismissal clears both so the next
            // open starts fresh with no context selected.
            if !chatContextStore.isLocked {
                chatContextStore.floatingChat.reset()
                chatContextStore.selectedContexts = []
            }
        }) {
            NavigationStack {
                ChatView()
                    .environment(chatContextStore)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}
