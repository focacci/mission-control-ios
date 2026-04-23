import SwiftUI

// MARK: - Settings First-Class View
//
// Pushed onto the parent NavigationStack so the user can swipe back. Mirrors
// the section-pill pattern used in HealthView/FaithView and binds a
// `.settings(section:)` chat context so the floating chat is grounded on the
// section the user is reading.

struct SettingsView: View {
    @State private var section: SettingsSection = .connection
    @State private var baseURL: String = APIClient.shared.baseURL
    @State private var health: ServerHealth?
    @State private var isChecking = false
    @State private var connectionError: String?

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SettingsSection.allCases) { s in
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    section = s
                                }
                            } label: {
                                Label(s.label, systemImage: s.icon)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        section == s
                                            ? Color.accentColor
                                            : Color.secondary.opacity(0.15),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(section == s ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }

                Group {
                    switch section {
                    case .connection: ConnectionSection(
                        baseURL: $baseURL,
                        health: $health,
                        isChecking: $isChecking,
                        connectionError: $connectionError,
                        onSave: { saveAndCheck() }
                    )
                    case .debug:      DebugSection()
                    case .about:      AboutSection(appVersion: appVersion, buildNumber: buildNumber)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)
        }
        .chatContext(.settings(section: section.label))
        .chatContextToolbar()
        .task { await checkHealth() }
    }

    private func saveAndCheck() {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        APIClient.shared.baseURL = trimmed
        baseURL = trimmed
        Task { await checkHealth() }
    }

    private func checkHealth() async {
        isChecking = true
        health = nil
        connectionError = nil
        do {
            health = try await APIClient.shared.health()
        } catch {
            connectionError = error.localizedDescription
        }
        isChecking = false
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case connection, debug, about
    var id: String { rawValue }
    var label: String {
        switch self {
        case .connection: return "Connection"
        case .debug:      return "Debug"
        case .about:      return "About"
        }
    }
    var icon: String {
        switch self {
        case .connection: return "server.rack"
        case .debug:      return "ladybug"
        case .about:      return "info.circle"
        }
    }
}

// MARK: - Connection Section

private struct ConnectionSection: View {
    @Binding var baseURL: String
    @Binding var health: ServerHealth?
    @Binding var isChecking: Bool
    @Binding var connectionError: String?
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // API URL card
            VStack(alignment: .leading, spacing: 12) {
                Label("API Server", systemImage: "server.rack")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                    TextField("http://10.0.0.12:3737", text: $baseURL)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .onSubmit(onSave)
                }
                .padding(10)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                Button(action: onSave) {
                    Label(isChecking ? "Testing…" : "Test Connection", systemImage: "bolt.horizontal")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(isChecking)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            // Status card
            VStack(alignment: .leading, spacing: 10) {
                Label("Connection Status", systemImage: "wifi")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 10) {
                    if isChecking {
                        ProgressView()
                            .padding(.trailing, 4)
                        Text("Checking…")
                            .foregroundStyle(.secondary)
                    } else if let health {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connected")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            if let goalCount = health.goals {
                                Text("\(goalCount) goals tracked")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else if let error = connectionError {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    } else {
                        Image(systemName: "circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Not tested")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Debug Section

private struct DebugSection: View {
    var body: some View {
        VStack(spacing: 12) {
            NavigationLink {
                InvocationsListView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Agent Invocations")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("Inspect recent agent runs and tool calls")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - About Section

private struct AboutSection: View {
    let appVersion: String
    let buildNumber: String

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                AboutRow(icon: "app.badge", label: "Version", value: "\(appVersion) (\(buildNumber))")
                Divider().padding(.leading, 14)
                AboutRow(icon: "iphone", label: "Platform", value: "iOS/iPadOS + watchOS")
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 0) {
                AboutLinkRow(
                    icon: "swift",
                    label: "iOS Source",
                    url: URL(string: "https://github.com/focacci/mission-control-ios")!
                )
                Divider().padding(.leading, 14)
                AboutLinkRow(
                    icon: "server.rack",
                    label: "API Source",
                    url: URL(string: "https://github.com/focacci/mission-control-api")!
                )
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct AboutRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
    }
}

private struct AboutLinkRow: View {
    let icon: String
    let label: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
    }
}
