import SwiftUI

struct OutputsCard: View {
    let outputs: [TaskOutput]

    var body: some View {
        SectionCard(title: "Outputs", icon: "doc.fill") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(outputs) { output in
                    HStack {
                        Image(systemName: "paperclip")
                            .foregroundStyle(.secondary)

                        if let urlStr = output.url, let url = URL(string: urlStr) {
                            Link(output.label, destination: url)
                                .font(.body)
                        } else {
                            Text(output.label)
                                .font(.body)
                        }

                        Spacer()
                    }
                }
            }
        }
    }
}
