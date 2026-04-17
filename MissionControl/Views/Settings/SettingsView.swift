import SwiftUI

struct SettingsView: View {
    @State private var baseURL: String = APIClient.shared.baseURL
    @State private var health: ServerHealth?
    @State private var isChecking = false
    @State private var connectionError: String?

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        NavigationStack {
            Form {
                Section("API Configuration") {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundStyle(.secondary)
                        TextField("http://10.0.0.12:3737", text: $baseURL)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .onSubmit { saveAndCheck() }
                    }

                    Button("Test Connection") {
                        saveAndCheck()
                    }
                    .disabled(isChecking)
                }

                Section("Connection Status") {
                    HStack {
                        if isChecking {
                            ProgressView()
                                .padding(.trailing, 4)
                            Text("Checking…")
                                .foregroundStyle(.secondary)
                        } else if let health {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading) {
                                Text("Connected")
                                    .fontWeight(.medium)
                                if let goalCount = health.goals {
                                    Text("\(goalCount) goals tracked")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else if let error = connectionError {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .foregroundStyle(.secondary)
                                .font(.callout)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                            Text("Not tested")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "\(appVersion) (\(buildNumber))")
                    LabeledContent("Model", value: "iOS/iPadOS + watchOS")

                    Link(destination: URL(string: "https://github.com")!) {
                        Label("View Source", systemImage: "arrow.up.right.square")
                    }
                }
            }
            .navigationTitle("Settings")
            .task { await checkHealth() }
        }
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
