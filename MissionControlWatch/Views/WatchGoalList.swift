import SwiftUI

struct WatchGoalList: View {
    @State private var goals: [Goal] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && goals.isEmpty {
                    ProgressView()
                } else if let error {
                    VStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                        Text(error)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                        Button("Retry") { Task { await load() } }
                    }
                } else if goals.isEmpty {
                    Text("No goals")
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(goals) { goal in
                            NavigationLink(destination: WatchGoalDetail(goal: goal)) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(goal.focusColor)
                                        .frame(width: 8, height: 8)
                                    Text(goal.emoji)
                                        .font(.title3)
                                    Text(goal.name)
                                        .font(.body)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Goals")
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            goals = try await APIClient.shared.goals()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct WatchGoalDetail: View {
    let goal: Goal
    @State private var goalDetail: Goal?
    @State private var isLoading = false

    private var activeTasks: Int {
        (goalDetail?.initiatives ?? goal.initiatives ?? [])
            .flatMap { $0.tasks ?? [] }
            .filter { $0.status == "in-progress" }
            .count
    }

    private var initiativeCount: Int {
        (goalDetail?.initiatives ?? goal.initiatives ?? []).count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(goal.emoji)
                    .font(.system(size: 40))

                Text(goal.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Label(goal.focusLabel, systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(goal.focusColor)

                Divider()

                HStack {
                    VStack {
                        Text("\(initiativeCount)")
                            .font(.title3.bold())
                        Text("Initiatives")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack {
                        Text("\(activeTasks)")
                            .font(.title3.bold())
                            .foregroundStyle(.blue)
                        Text("Active")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle(goal.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isLoading = true
            goalDetail = try? await APIClient.shared.goal(id: goal.id)
            isLoading = false
        }
    }
}
