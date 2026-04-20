import SwiftUI

struct CreateAgentSheet: View {
    let onSave: (_ name: String, _ model: String, _ systemPrompt: String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var model = modelOptions.first ?? ""
    @State private var systemPrompt = ""

    private static let modelOptions: [String] = [
        "github-copilot/claude-opus-4.6",
        "github-copilot/claude-sonnet-4",
        "github-copilot/gpt-5.4",
        "github-copilot/gpt-4o",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Agent") {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Model") {
                    Picker("Model", selection: $model) {
                        ForEach(Self.modelOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    TextEditor(text: $systemPrompt)
                        .frame(minHeight: 140)
                } header: {
                    Text("System Prompt (optional)")
                } footer: {
                    Text("Stored as SOUL.md in the new agent's workspace.")
                }
            }
            .navigationTitle("New Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmedPrompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(
                            name.trimmingCharacters(in: .whitespacesAndNewlines),
                            model,
                            trimmedPrompt.isEmpty ? nil : trimmedPrompt
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isEmpty)
                }
            }
        }
    }
}
