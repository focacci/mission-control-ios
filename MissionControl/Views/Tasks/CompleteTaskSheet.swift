import SwiftUI

struct CompleteTaskSheet: View {
    let onComplete: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var summary = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Completion Summary") {
                    TextEditor(text: $summary)
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if summary.isEmpty {
                                Text("Describe what was accomplished…")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }
            .navigationTitle("Complete Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onComplete(summary)
                        dismiss()
                    }
                    .disabled(summary.isEmpty)
                }
            }
        }
    }
}
