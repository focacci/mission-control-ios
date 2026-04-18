import SwiftUI

struct RosaryCard: View {
    let mystery: RosaryMystery
    @Bindable var state: RosaryState

    var allChecked: Bool {
        mystery.mysteries.allSatisfy { state.checkedMysteries.contains($0.index) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("📿 \(mystery.rawValue) Mysteries", systemImage: "")
                    .font(.headline)
                    .labelStyle(.titleOnly)

                Spacer()

                if allChecked {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            ForEach(mystery.mysteries, id: \.index) { item in
                Button {
                    state.toggle(index: item.index)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: state.checkedMysteries.contains(item.index)
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(state.checkedMysteries.contains(item.index)
                                             ? .green : .secondary)
                            .frame(width: 20)

                        Text("\(item.index). \(item.name)")
                            .font(.subheadline)
                            .foregroundStyle(state.checkedMysteries.contains(item.index)
                                             ? .secondary : .primary)
                            .strikethrough(state.checkedMysteries.contains(item.index),
                                           color: .secondary)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
