import SwiftUI

struct InitiativeDetailHeader: View {
    let initiative: Initiative

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(initiative.emoji)
                    .font(.system(size: 56))

                Text(initiative.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)

                Spacer()
            }

            HStack(spacing: 12) {
                Label(initiative.statusLabel, systemImage: initiative.statusIcon)
                    .font(.subheadline)
                    .foregroundStyle(initiative.statusColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(initiative.statusColor.opacity(0.15), in: Capsule())

                Spacer()
            }

            if let mission = initiative.mission, !mission.isEmpty {
                Text(mission)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
