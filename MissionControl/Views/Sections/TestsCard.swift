import SwiftUI

struct TestsCard: View {
    let tests: [TaskTest]
    let onDelete: (String) -> Void
    let onAdd: () -> Void

    var body: some View {
        SectionCard(title: "Tests", icon: "checkmark.shield") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tests) { test in
                    HStack(spacing: 10) {
                        Image(systemName: test.passed ? "checkmark.shield.fill" : "shield")
                            .foregroundStyle(test.passed ? .green : .secondary)
                            .font(.title3)

                        Text(test.description)
                            .font(.body)

                        Spacer()
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onDelete(test.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                Button(action: onAdd) {
                    Label("Add Test", systemImage: "plus")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                .padding(.top, tests.isEmpty ? 0 : 4)
            }
        }
    }
}
