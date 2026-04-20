import SwiftUI

struct TaskEditSheet: View {
    let task: MCTask
    let onSave: (UpdateTaskBody) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var objective: String

    init(task: MCTask, onSave: @escaping (UpdateTaskBody) -> Void) {
        self.task = task
        self.onSave = onSave
        _name = State(initialValue: task.name)
        _objective = State(initialValue: task.objective ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Info") {
                    TextField("Task name", text: $name)
                }

                Section("Objective") {
                    TextEditor(text: $objective)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(UpdateTaskBody(
                            name: name.isEmpty ? nil : name,
                            objective: objective.isEmpty ? nil : objective,
                            status: nil
                        ))
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
