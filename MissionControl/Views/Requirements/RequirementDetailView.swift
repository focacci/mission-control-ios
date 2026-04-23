import SwiftUI
import Observation

@Observable
final class RequirementDetailViewModel {
    var requirement: Requirement
    var isSaving = false
    var error: String?

    init(requirement: Requirement) {
        self.requirement = requirement
    }

    func updateDescription(_ new: String) async {
        let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != requirement.description else { return }
        isSaving = true
        do {
            requirement = try await APIClient.shared.updateRequirement(reqId: requirement.id, description: trimmed)
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func toggleCheck() async {
        isSaving = true
        do {
            if requirement.completed {
                requirement = try await APIClient.shared.uncheckRequirement(reqId: requirement.id)
            } else {
                requirement = try await APIClient.shared.checkRequirement(reqId: requirement.id)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func addTest(description: String) async {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let test = try await APIClient.shared.addRequirementTest(reqId: requirement.id, description: trimmed)
            var tests = requirement.tests ?? []
            tests.append(test)
            requirement.tests = tests
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleTest(_ test: RequirementTest) async {
        do {
            let updated: RequirementTest
            if test.passed {
                updated = try await APIClient.shared.unpassRequirementTest(reqId: requirement.id, testId: test.id)
            } else {
                updated = try await APIClient.shared.passRequirementTest(reqId: requirement.id, testId: test.id)
            }
            var tests = requirement.tests ?? []
            if let idx = tests.firstIndex(where: { $0.id == updated.id }) {
                tests[idx] = updated
                requirement.tests = tests
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteTest(_ testId: String) async {
        do {
            try await APIClient.shared.deleteRequirementTest(reqId: requirement.id, testId: testId)
            requirement.tests = (requirement.tests ?? []).filter { $0.id != testId }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct RequirementDetailView: View {
    @State var viewModel: RequirementDetailViewModel
    @State private var editedDescription: String
    @State private var showingAddTest = false
    @State private var newTest = ""
    @FocusState private var descriptionFocused: Bool

    let onChange: ((Requirement) -> Void)?

    init(requirement: Requirement, onChange: ((Requirement) -> Void)? = nil) {
        _viewModel = State(initialValue: RequirementDetailViewModel(requirement: requirement))
        _editedDescription = State(initialValue: requirement.description)
        self.onChange = onChange
    }

    private var context: ChatContextKind {
        .requirement(id: viewModel.requirement.id, title: viewModel.requirement.description)
    }

    var body: some View {
        List {
            Section("Description") {
                TextField("Description", text: $editedDescription, axis: .vertical)
                    .lineLimit(2...6)
                    .focused($descriptionFocused)
                    .onChange(of: descriptionFocused) { _, focused in
                        if !focused {
                            Task {
                                await viewModel.updateDescription(editedDescription)
                                onChange?(viewModel.requirement)
                            }
                        }
                    }
            }

            Section("Status") {
                Button {
                    Task {
                        await viewModel.toggleCheck()
                        onChange?(viewModel.requirement)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: viewModel.requirement.completed ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(viewModel.requirement.completed ? .green : .secondary)
                            .font(.title3)
                        Text(viewModel.requirement.completed ? "Completed" : "Mark Complete")
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                }
                .disabled(viewModel.isSaving)
            }

            Section {
                let tests = viewModel.requirement.tests ?? []
                if tests.isEmpty {
                    Text("Add tests to prove this requirement is satisfied.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tests) { test in
                        Button {
                            Task { await viewModel.toggleTest(test) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: test.passed ? "checkmark.shield.fill" : "shield")
                                    .foregroundStyle(test.passed ? .green : .secondary)
                                Text(test.description)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteTest(test.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                Button {
                    showingAddTest = true
                } label: {
                    Label("Add Test", systemImage: "plus")
                }
            } header: {
                Text("Tests")
            } footer: {
                if let progress = viewModel.requirement.tests.map({ _ in viewModel.requirement.testsProgress }),
                   !progress.isEmpty {
                    Text("\(progress) passing")
                }
            }

            if viewModel.requirement.id.hasPrefix("req") || !viewModel.requirement.id.isEmpty {
                ContextChatHistorySection(
                    contextType: "requirement",
                    contextId: viewModel.requirement.id
                )
            }
        }
        .navigationTitle("Requirement")
        .navigationBarTitleDisplayMode(.inline)
        .chatContext(context)
        .chatContextToolbar()
        .alert("Add Test", isPresented: $showingAddTest) {
            TextField("Description", text: $newTest)
            Button("Add") {
                let desc = newTest
                newTest = ""
                Task { await viewModel.addTest(description: desc) }
            }
            Button("Cancel", role: .cancel) { newTest = "" }
        }
        .errorAlert(message: $viewModel.error)
    }
}
