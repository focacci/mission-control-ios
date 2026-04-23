import SwiftUI

// MARK: - Feature List Tab Root
//
// Replaces the auto-generated iOS "More" tab with a custom landing page that
// mirrors the overflow list's appearance but owns its own NavigationStack so
// destinations push with a single header and support swipe-back. The page
// also binds a `.featureList` chat context so the floating chat knows which
// optional features are available to the user.

struct FeatureListView: View {
    var body: some View {
        NavigationStack {
            List {
                ForEach(FeatureListEntry.allCases) { entry in
                    NavigationLink(value: entry) {
                        Label {
                            Text(entry.title)
                        } icon: {
                            Image(systemName: entry.icon)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .chatContext(.featureList(features: FeatureListEntry.allCases.map(\.title)))
            .chatContextToolbar()
            .navigationDestination(for: FeatureListEntry.self) { entry in
                entry.destination
            }
        }
    }
}

// MARK: - Entries

enum FeatureListEntry: String, CaseIterable, Identifiable, Hashable {
    case profile
    case faith
    case health
    case briefings
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile:   return "Profile"
        case .faith:     return "Faith"
        case .health:    return "Health"
        case .briefings: return "Briefings"
        case .settings:  return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .profile:   return "person.text.rectangle"
        case .faith:     return "cross"
        case .health:    return "heart"
        case .briefings: return "briefcase"
        case .settings:  return "gearshape"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .profile:   ProfileView()
        case .faith:     FaithView()
        case .health:    HealthView()
        case .briefings: BriefsView()
        case .settings:  SettingsView()
        }
    }
}
