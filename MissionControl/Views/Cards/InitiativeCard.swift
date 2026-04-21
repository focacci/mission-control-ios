import SwiftUI

struct InitiativeCard: View {
    let initiative: Initiative

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Text(initiative.emoji)
                    .font(.system(size: 28))

                Spacer()

                Label(initiative.statusLabel, systemImage: initiative.statusIcon)
                    .font(.caption)
                    .foregroundStyle(initiative.statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(initiative.statusColor.opacity(0.15), in: Capsule())
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 4) {
                Text(initiative.name)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.primary)

                if let mission = initiative.mission, !mission.isEmpty {
                    Text(mission)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardStyle()
    }
}
