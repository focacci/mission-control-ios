import SwiftUI

struct TaskActionBar: View {
    let task: MCTask
    let isSaving: Bool
    let onStart: () -> Void
    let onComplete: () -> Void
    let onBlock: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if task.canStart {
                Button(action: onStart) {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(isSaving)
            }

            if task.canComplete {
                Button(action: onComplete) {
                    Label("Complete", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isSaving)
            }

            if task.canBlock {
                Button(action: onBlock) {
                    Label("Block", systemImage: "exclamationmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(isSaving)
            }
        }
    }
}
