import SwiftUI

struct GoalEditSheet: View {
    let goal: Goal
    let onSave: (UpdateGoalBody) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var emoji: String
    @State private var name: String
    @State private var focus: String
    @State private var timeline: String
    @State private var story: String

    private let focusOptions = ["sprint", "steady", "simmer", "dormant"]

    init(goal: Goal, onSave: @escaping (UpdateGoalBody) -> Void) {
        self.goal = goal
        self.onSave = onSave
        _emoji = State(initialValue: goal.emoji)
        _name = State(initialValue: goal.name)
        _focus = State(initialValue: goal.focus)
        _timeline = State(initialValue: goal.timeline ?? "")
        _story = State(initialValue: goal.story ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Info") {
                    HStack {
                        Text("Emoji")
                        Spacer()
                        TextField("🎯", text: $emoji)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                    }
                    TextField("Goal name", text: $name)
                }

                Section("Focus") {
                    Picker("Focus Level", selection: $focus) {
                        ForEach(focusOptions, id: \.self) { f in
                            Text(f.prefix(1).uppercased() + f.dropFirst()).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("Timeline (optional)", text: $timeline)
                }

                Section("Story") {
                    TextEditor(text: $story)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(UpdateGoalBody(
                            emoji: emoji.isEmpty ? nil : emoji,
                            name: name.isEmpty ? nil : name,
                            focus: focus,
                            timeline: timeline.isEmpty ? nil : timeline,
                            story: story.isEmpty ? nil : story
                        ))
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
