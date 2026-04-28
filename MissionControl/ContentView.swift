import SwiftUI

struct ContentView: View {
    @State private var chatContextStore = ChatContextStore()
    @State private var deepLinkRouter = DeepLinkRouter()
    @State private var selectedTab = 0

    var body: some View {
        @Bindable var chatContextStore = chatContextStore

        TabView(selection: $selectedTab) {
            HomeView()
                .floatingChatButton(isPresented: $chatContextStore.showingChat)
                .tabItem { Label("Feed", systemImage: "newspaper") }
                .tag(0)

            PlansView()
                .floatingChatButton(isPresented: $chatContextStore.showingChat)
                .tabItem { Label("Plans", systemImage: "list.bullet.clipboard") }
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
        .environment(deepLinkRouter)
        .onChange(of: deepLinkRouter.pending) { _, link in
            handleDeepLink(link)
        }
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
                    .environment(deepLinkRouter)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    /// Handle a `MessagePart.navigate` tap originating from chat. The chat
    /// sheet always dismisses (so the underlying tab is visible) and the tab
    /// switches to whichever owns the destination. The detail-view push is
    /// the listening tab's job — `PlansView` consumes task/goal/initiative
    /// links via its own `onChange(of: router.pending)`. If no listener
    /// claims the link before the next event, `consume()` clears it on
    /// receipt here.
    private func handleDeepLink(_ link: DeepLink?) {
        guard let link else { return }
        chatContextStore.showingChat = false
        switch link {
        case .home:
            selectedTab = 0
            deepLinkRouter.consume()
        case .task, .goal, .initiative:
            // Plans tab owns the detail push. Switch tab here; PlansView
            // appends to its NavigationPath when it observes `pending`.
            selectedTab = 2
        case .schedule:
            // No date-jump wiring on ScheduleView yet — switch tab so the
            // user lands on the schedule and clear so the link doesn't sit
            // pending. Hooking the date into ScheduleView is a follow-up.
            selectedTab = 3
            deepLinkRouter.consume()
        case .agentAssignment:
            // No dedicated tab today; agent assignments live under tasks.
            // Switch to Plans and let it route through TaskDetail — for now
            // just clear so the link doesn't sit pending.
            selectedTab = 2
            deepLinkRouter.consume()
        case .unknown:
            deepLinkRouter.consume()
        }
    }
}
