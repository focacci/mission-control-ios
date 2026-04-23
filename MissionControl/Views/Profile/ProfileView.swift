import SwiftUI

// MARK: - User Profile Tab Root
//
// Displays the long-running picture Intella has built of the user: tendencies,
// strengths and weaknesses, favorite places and activities, and the purpose
// behind the goals they pursue. Mirrors the HealthView/FaithView pill pattern
// and binds a `.profile(section:)` chat context so the floating chat can
// reason about the "why" behind what the user is working on.

struct ProfileView: View {
    @State private var section: ProfileSection = .overview

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ProfileSection.allCases) { s in
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
                    case .overview:   OverviewSection()
                    case .traits:     TraitsSection()
                    case .habits:     HabitsSection()
                    case .places:     PlacesSection()
                    case .activities: ActivitiesSection()
                    case .purpose:    PurposeSection()
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)
        }
        .chatContext(.profile(section: section.label))
        .chatContextToolbar()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // TODO: surface profile actions (e.g. correct a tendency,
                    // add a favorite place, share with the agent).
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }
}

private enum ProfileSection: String, CaseIterable, Identifiable {
    case overview, traits, habits, places, activities, purpose
    var id: String { rawValue }
    var label: String {
        switch self {
        case .overview:   return "Overview"
        case .traits:     return "Traits"
        case .habits:     return "Habits"
        case .places:     return "Places"
        case .activities: return "Activities"
        case .purpose:    return "Purpose"
        }
    }
    var icon: String {
        switch self {
        case .overview:   return "person.text.rectangle"
        case .traits:     return "scale.3d"
        case .habits:     return "repeat"
        case .places:     return "mappin.and.ellipse"
        case .activities: return "figure.run"
        case .purpose:    return "target"
        }
    }
}

// MARK: - Overview

private struct OverviewSection: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.18))
                        .frame(width: 56, height: 56)
                    Image(systemName: "person.text.rectangle")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Michael")
                        .font(.title3.weight(.semibold))
                    Text("Builder · Father · Early riser")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            InfoBlock(
                title: "How Intella sees you",
                icon: "sparkles",
                text: "You operate best in the morning on focused, creation-heavy work. You think in systems and prefer long-lived projects over one-off tasks. You push back when advice feels generic — you want Intella to understand context before making suggestions."
            )

            StatRow(items: [
                .init(icon: "flame", label: "Longest streak", value: "47d"),
                .init(icon: "bolt", label: "Peak hours", value: "6–10 AM"),
                .init(icon: "book.closed", label: "Top theme", value: "Craft")
            ])

            InfoBlock(
                title: "Signals still being learned",
                icon: "questionmark.circle",
                text: "Intella is still calibrating your weekend rhythm and how much social time restores vs. drains you. Expect refinement as you log more evenings and Saturdays."
            )
        }
    }
}

private struct InfoBlock: View {
    let title: String
    let icon: String
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct StatRow: View {
    struct Item: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let value: String
    }
    let items: [Item]
    var body: some View {
        HStack(spacing: 10) {
            ForEach(items) { item in
                VStack(spacing: 4) {
                    Image(systemName: item.icon)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(item.value)
                        .font(.subheadline.weight(.semibold))
                    Text(item.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Traits (strengths + weaknesses)

private struct Trait: Identifiable {
    let id = UUID()
    let name: String
    let note: String
    let confidence: Double
}

private let mockStrengths: [Trait] = [
    Trait(name: "Deep focus", note: "Can hold a single hard problem for 3–4 hours uninterrupted.", confidence: 0.92),
    Trait(name: "Systems thinking", note: "Prefers to invest in reusable scaffolding over one-off fixes.", confidence: 0.88),
    Trait(name: "Follow-through on craft work", note: "Finishes long-form building projects at a high rate (~80%).", confidence: 0.81),
    Trait(name: "Written communication", note: "Structures arguments clearly in writing; drafts quickly.", confidence: 0.77)
]

private let mockWeaknesses: [Trait] = [
    Trait(name: "Administrative follow-up", note: "Tends to drop email threads and scheduling tasks mid-week.", confidence: 0.84),
    Trait(name: "Context switching", note: "Loses 20–30 min after each interruption — protect morning blocks.", confidence: 0.79),
    Trait(name: "Rest discipline", note: "Skips breaks when flow feels good, then crashes the next day.", confidence: 0.73),
    Trait(name: "Estimation", note: "Under-estimates 2-week projects by roughly 40%.", confidence: 0.68)
]

private struct TraitsSection: View {
    var body: some View {
        VStack(spacing: 12) {
            TraitGroup(title: "Strengths", icon: "arrow.up.right.circle", tint: .green, traits: mockStrengths)
            TraitGroup(title: "Weaknesses", icon: "arrow.down.right.circle", tint: .orange, traits: mockWeaknesses)
        }
    }
}

private struct TraitGroup: View {
    let title: String
    let icon: String
    let tint: Color
    let traits: [Trait]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            VStack(spacing: 8) {
                ForEach(traits) { trait in
                    TraitRow(trait: trait, tint: tint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct TraitRow: View {
    let trait: Trait
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(trait.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(trait.confidence * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(trait.note)
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: trait.confidence)
                .tint(tint)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Habits / Tendencies

private struct Habit: Identifiable {
    let id = UUID()
    let name: String
    let cadence: String
    let detail: String
    let icon: String
    let positive: Bool
}

private let mockHabits: [Habit] = [
    Habit(name: "Morning planning ritual", cadence: "Daily · ~6:15 AM", detail: "Opens Mission Control, reviews the day, commits to one keystone task.", icon: "sun.max", positive: true),
    Habit(name: "Run before lunch", cadence: "3–4×/week", detail: "Short runs cluster around 11 AM on high-focus days.", icon: "figure.run", positive: true),
    Habit(name: "Kitchen-clean reset", cadence: "Nightly · ~9 PM", detail: "Resets the sink before bed; skipped nights correlate with a rough next morning.", icon: "sparkles", positive: true),
    Habit(name: "Late-night coding", cadence: "2–3×/week", detail: "After 11 PM sessions often cost the following morning's focus window.", icon: "moon.stars", positive: false),
    Habit(name: "Doomscrolling drift", cadence: "Weekends", detail: "Saturday afternoons are the highest-risk window — usually triggered by low-structure mornings.", icon: "iphone", positive: false),
    Habit(name: "Sunday long walk", cadence: "Weekly", detail: "Used as a thinking session for the upcoming week's priorities.", icon: "figure.walk", positive: true)
]

private struct HabitsSection: View {
    var body: some View {
        VStack(spacing: 10) {
            ForEach(mockHabits) { habit in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill((habit.positive ? Color.green : Color.orange).opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: habit.icon)
                            .font(.subheadline)
                            .foregroundStyle(habit.positive ? Color.green : Color.orange)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(habit.name)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(habit.cadence)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(habit.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Favorite Places

private struct FavoritePlace: Identifiable {
    let id = UUID()
    let name: String
    let kind: String
    let icon: String
    let note: String
}

private let mockPlaces: [FavoritePlace] = [
    FavoritePlace(name: "The back patio", kind: "Home", icon: "leaf", note: "Morning coffee + journaling. Clearest-head location, especially in spring."),
    FavoritePlace(name: "Stumptown on Hawthorne", kind: "Café", icon: "cup.and.saucer", note: "Goes here on Wednesdays for longer writing sessions."),
    FavoritePlace(name: "Forest Park, Wildwood trail", kind: "Outdoor", icon: "tree", note: "The thinking-walk route. 90 min round trip from the trailhead."),
    FavoritePlace(name: "The parish chapel", kind: "Spiritual", icon: "cross", note: "Weekday morning Mass; anchors the early schedule."),
    FavoritePlace(name: "Workshop garage", kind: "Home", icon: "wrench.and.screwdriver", note: "Saturday craft work; woodworking + repairs."),
    FavoritePlace(name: "Bellingham, WA", kind: "Travel", icon: "airplane", note: "Family visits; consistently described as restorative.")
]

private struct PlacesSection: View {
    var body: some View {
        VStack(spacing: 10) {
            ForEach(mockPlaces) { place in
                HStack(spacing: 12) {
                    Image(systemName: place.icon)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(place.name)
                                .font(.subheadline.weight(.semibold))
                            Text(place.kind)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                        Text(place.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Favorite Activities

private struct FavoriteActivity: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let icon: String
    let frequency: String
    let note: String
}

private let mockActivities: [FavoriteActivity] = [
    FavoriteActivity(name: "Writing long-form essays", category: "Craft", icon: "pencil.and.scribble", frequency: "Weekly", note: "Primary creative outlet; treats this as non-negotiable."),
    FavoriteActivity(name: "Building side projects", category: "Craft", icon: "hammer", frequency: "Daily", note: "Prefers projects that compound — tools, systems, archives."),
    FavoriteActivity(name: "Trail running", category: "Health", icon: "figure.run", frequency: "3×/week", note: "Used as a reset; mood consistently better on run days."),
    FavoriteActivity(name: "Reading (history + theology)", category: "Learning", icon: "book", frequency: "Nightly", note: "Current rotation: Burke, Newman, Benedict XVI."),
    FavoriteActivity(name: "Cooking for the family", category: "Home", icon: "fork.knife", frequency: "Weekends", note: "Sunday roast is a recurring tradition."),
    FavoriteActivity(name: "Sacred music", category: "Faith", icon: "music.note", frequency: "Daily", note: "Listens to Gregorian chant during deep work.")
]

private struct ActivitiesSection: View {
    var body: some View {
        VStack(spacing: 10) {
            ForEach(mockActivities) { activity in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: activity.icon)
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.name)
                                .font(.subheadline.weight(.semibold))
                            HStack(spacing: 6) {
                                Text(activity.category)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15), in: Capsule())
                                Text(activity.frequency)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    Text(activity.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Purpose (the why behind goals)

private struct PurposeEntry: Identifiable {
    let id = UUID()
    let goal: String
    let emoji: String
    let why: String
    let rootValue: String
}

private let mockPurposes: [PurposeEntry] = [
    PurposeEntry(
        goal: "Ship Intella MVP",
        emoji: "🛰️",
        why: "Wants a tool he actually uses daily — one that reflects how he thinks instead of flattening it into someone else's productivity framework.",
        rootValue: "Craft · Autonomy"
    ),
    PurposeEntry(
        goal: "Run a sub-7:00 mile at 40",
        emoji: "🏃",
        why: "Not about the time — it's a proxy for staying physically capable as a father over the next two decades.",
        rootValue: "Longevity · Family"
    ),
    PurposeEntry(
        goal: "Weekly family dinners",
        emoji: "🍽️",
        why: "Anchor point for the week. The goal is continuity of tradition, not logistics.",
        rootValue: "Family · Tradition"
    ),
    PurposeEntry(
        goal: "Finish the essay collection",
        emoji: "📚",
        why: "An act of working out what he actually believes — writing is how he figures out his own positions.",
        rootValue: "Craft · Clarity"
    ),
    PurposeEntry(
        goal: "Daily Mass attendance",
        emoji: "✝️",
        why: "Structural anchor of the day; the other morning habits hang off of this one.",
        rootValue: "Faith · Rhythm"
    )
]

private struct PurposeSection: View {
    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label("The \"why\" behind the work", systemImage: "target")
                    .font(.subheadline.weight(.semibold))
                Text("Intella uses these root motivations to weigh trade-offs — so suggestions align with the value a goal is actually protecting, not just its surface metric.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            ForEach(mockPurposes) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text(entry.emoji)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.goal)
                                .font(.subheadline.weight(.semibold))
                            Text(entry.rootValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    Divider()
                    Text(entry.why)
                        .font(.body)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
