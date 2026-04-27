import SwiftUI

struct TaskActionBar: View {
    let task: MCTask
    let isSaving: Bool
    let onComplete: () -> Void
    let onReopen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if task.isDone {
                Button(action: onReopen) {
                    Label("Reopen", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isSaving)
            } else {
                Button(action: onComplete) {
                    Label("Done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isSaving)
            }
        }
    }
}
