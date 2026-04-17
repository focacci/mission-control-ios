import SwiftUI

struct InitiativeEditSheet: View {
    let initiative: Initiative
    let onSave: (UpdateInitiativeBody) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var emoji: String
    @State private var name: String
    @State private var status: String
    @State private var mission: String

    private let statusOptions = ["active", "backlog", "paused", "completed"]

    init(initiative: Initiative, onSave: @escaping (UpdateInitiativeBody) -> Void) {
        self.initiative = initiative
        self.onSave = onSave
        _emoji = State(initialValue: initiative.emoji)
        _name = State(initialValue: initiative.name)
        _status = State(initialValue: initiative.status)
        _mission = State(initialValue: initiative.mission ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Initiative Info") {
                    HStack {
                        Text("Emoji")
                        Spacer()
                        TextField("🚀", text: $emoji)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                    }
                    TextField("Initiative name", text: $name)
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(statusOptions, id: \.self) { s in
                            Text(s.prefix(1).uppercased() + s.dropFirst()).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Mission") {
                    TextEditor(text: $mission)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Edit Initiative")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(UpdateInitiativeBody(
                            emoji: emoji.isEmpty ? nil : emoji,
                            name: name.isEmpty ? nil : name,
                            status: status,
                            mission: mission.isEmpty ? nil : mission,
                            goalId: nil
                        ))
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
