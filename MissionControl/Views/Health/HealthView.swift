import SwiftUI

// MARK: - Health Tab Root

struct HealthView: View {
    @State private var section: HealthSection = .meals

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(HealthSection.allCases) { s in
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
                        case .meals:     MealsView()
                        case .workouts:  WorkoutsView()
                        case .water:     WaterView()
                        case .sleep:     SleepView()
                        case .meds:      MedicationsView()
                        case .symptoms:  SymptomsView()
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .chatContext(.health(section: section.label))
            .chatContextToolbar()
        }
    }
}

private enum HealthSection: String, CaseIterable, Identifiable {
    case meals, workouts, water, sleep, meds, symptoms
    var id: String { rawValue }
    var label: String {
        switch self {
        case .meals:    return "Meals"
        case .workouts: return "Workouts"
        case .water:    return "Water"
        case .sleep:    return "Sleep"
        case .meds:     return "Meds"
        case .symptoms: return "Symptoms"
        }
    }
    var icon: String {
        switch self {
        case .meals:    return "fork.knife"
        case .workouts: return "figure.run"
        case .water:    return "drop"
        case .sleep:    return "moon.zzz"
        case .meds:     return "pills"
        case .symptoms: return "stethoscope"
        }
    }
}

// MARK: - Meals

private struct Meal {
    let id: String
    let type: String
    let icon: String
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let items: [String]
}

private let mockMeals: [Meal] = [
    Meal(id: "breakfast", type: "Breakfast", icon: "sunrise", name: "Overnight Oats & Eggs",
         calories: 520, protein: 34, carbs: 58, fat: 14,
         items: ["Rolled oats with almond milk and chia seeds", "2 soft-boiled eggs", "Mixed berries", "Black coffee"]),
    Meal(id: "lunch", type: "Lunch", icon: "sun.max", name: "Grilled Chicken Bowl",
         calories: 680, protein: 52, carbs: 62, fat: 18,
         items: ["6 oz grilled chicken breast", "Brown rice", "Roasted broccoli and bell peppers", "Olive oil & lemon dressing"]),
    Meal(id: "snack", type: "Snack", icon: "leaf", name: "Afternoon Snack",
         calories: 210, protein: 12, carbs: 22, fat: 8,
         items: ["Greek yogurt (plain, full-fat)", "Handful of almonds", "Apple slices"]),
    Meal(id: "dinner", type: "Dinner", icon: "moon", name: "Salmon & Vegetables",
         calories: 590, protein: 44, carbs: 38, fat: 22,
         items: ["5 oz baked Atlantic salmon", "Steamed asparagus", "Sweet potato", "Side salad with olive oil"]),
]

private struct MealsView: View {
    @State private var expandedMeal: String? = nil

    private var totals: (cal: Int, protein: Int, carbs: Int, fat: Int) {
        let cal = mockMeals.reduce(0) { $0 + $1.calories }
        let p = mockMeals.reduce(0) { $0 + $1.protein }
        let c = mockMeals.reduce(0) { $0 + $1.carbs }
        let f = mockMeals.reduce(0) { $0 + $1.fat }
        return (cal, p, c, f)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Daily summary
            HStack(spacing: 0) {
                MacroCell(label: "Calories", value: "\(totals.cal)", unit: "kcal", color: .orange)
                Divider().frame(height: 36)
                MacroCell(label: "Protein", value: "\(totals.protein)", unit: "g", color: .blue)
                Divider().frame(height: 36)
                MacroCell(label: "Carbs", value: "\(totals.carbs)", unit: "g", color: .green)
                Divider().frame(height: 36)
                MacroCell(label: "Fat", value: "\(totals.fat)", unit: "g", color: .yellow)
            }
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            ForEach(mockMeals, id: \.id) { meal in
                MealCard(meal: meal, expandedMeal: $expandedMeal)
            }
        }
    }
}

private struct MacroCell: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MealCard: View {
    let meal: Meal
    @Binding var expandedMeal: String?
    var isExpanded: Bool { expandedMeal == meal.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expandedMeal = isExpanded ? nil : meal.id
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: meal.icon)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.type)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(meal.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Text("\(meal.calories) kcal")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal, 14)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(meal.items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.secondary.opacity(0.4))
                                .frame(width: 5, height: 5)
                                .padding(.top, 6)
                            Text(item)
                                .font(.body)
                        }
                    }
                    HStack(spacing: 12) {
                        MacroBadge(label: "P", value: "\(meal.protein)g", color: .blue)
                        MacroBadge(label: "C", value: "\(meal.carbs)g", color: .green)
                        MacroBadge(label: "F", value: "\(meal.fat)g", color: .yellow)
                    }
                    .padding(.top, 4)
                }
                .padding(14)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MacroBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Workouts

private struct WorkoutExercise {
    let name: String
    let sets: Int
    let reps: String
    let rest: String
}

private struct WorkoutSession {
    let id: String
    let date: String
    let type: String
    let icon: String
    let duration: Int
    let exercises: [WorkoutExercise]
    let isToday: Bool
}

private let mockWorkouts: [WorkoutSession] = [
    WorkoutSession(
        id: "today",
        date: "Today",
        type: "Upper Body Strength",
        icon: "dumbbell",
        duration: 50,
        exercises: [
            WorkoutExercise(name: "Bench Press", sets: 4, reps: "6–8", rest: "90s"),
            WorkoutExercise(name: "Pull-Ups", sets: 4, reps: "8–10", rest: "90s"),
            WorkoutExercise(name: "Overhead Press", sets: 3, reps: "8–10", rest: "75s"),
            WorkoutExercise(name: "Dumbbell Row", sets: 3, reps: "10–12", rest: "60s"),
            WorkoutExercise(name: "Face Pulls", sets: 3, reps: "15", rest: "45s"),
        ],
        isToday: true
    ),
    WorkoutSession(
        id: "yesterday",
        date: "Yesterday",
        type: "30 min Steady-State Run",
        icon: "figure.run",
        duration: 32,
        exercises: [],
        isToday: false
    ),
    WorkoutSession(
        id: "2d-ago",
        date: "2 days ago",
        type: "Lower Body Strength",
        icon: "figure.strengthtraining.traditional",
        duration: 55,
        exercises: [
            WorkoutExercise(name: "Back Squat", sets: 4, reps: "6–8", rest: "120s"),
            WorkoutExercise(name: "Romanian Deadlift", sets: 3, reps: "10", rest: "90s"),
            WorkoutExercise(name: "Bulgarian Split Squat", sets: 3, reps: "10 each", rest: "75s"),
            WorkoutExercise(name: "Calf Raises", sets: 4, reps: "15", rest: "45s"),
        ],
        isToday: false
    ),
]

private struct WorkoutsView: View {
    @State private var expandedWorkout: String? = "today"

    var body: some View {
        VStack(spacing: 12) {
            ForEach(mockWorkouts, id: \.id) { session in
                WorkoutCard(session: session, expanded: $expandedWorkout)
            }
        }
    }
}

private struct WorkoutCard: View {
    let session: WorkoutSession
    @Binding var expanded: String?
    var isExpanded: Bool { expanded == session.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expanded = isExpanded ? nil : session.id
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: session.icon)
                        .font(.title3)
                        .foregroundStyle(session.isToday ? Color.accentColor : .secondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(session.date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if session.isToday {
                                Text("TODAY")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                            }
                        }
                        Text(session.type)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Label("\(session.duration)m", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded && !session.exercises.isEmpty {
                Divider().padding(.horizontal, 14)
                VStack(spacing: 0) {
                    HStack {
                        Text("Exercise")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Sets × Reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Rest")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                    ForEach(session.exercises, id: \.name) { ex in
                        HStack {
                            Text(ex.name)
                                .font(.body)
                            Spacer()
                            Text("\(ex.sets) × \(ex.reps)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(ex.rest)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .frame(width: 44, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Water

private struct WaterView: View {
    @State private var cups: Int = 5
    private let goal: Int = 8
    private let cupOz: Int = 8

    private var progress: Double { min(Double(cups) / Double(goal), 1.0) }
    private var ozConsumed: Int { cups * cupOz }
    private var ozGoal: Int { goal * cupOz }

    var body: some View {
        VStack(spacing: 12) {
            // Progress card
            VStack(spacing: 16) {
                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(ozConsumed)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("oz")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Goal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(ozGoal) oz")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 10)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * progress, height: 10)
                            .animation(.easeInOut(duration: 0.3), value: cups)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("\(cups) of \(goal) cups")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(progress >= 1 ? "Goal reached!" : "\(goal - cups) cups to go")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(progress >= 1 ? Color.green : .secondary)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            // Controls
            HStack(spacing: 16) {
                Button {
                    if cups > 0 { cups -= 1 }
                } label: {
                    Label("Remove", systemImage: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(cups > 0 ? Color.secondary : Color.secondary.opacity(0.3))
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .disabled(cups == 0)

                Text("Log a cup (\(cupOz) oz)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Button {
                    cups += 1
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            // Cup grid
            VStack(alignment: .leading, spacing: 10) {
                Label("Today's intake", systemImage: "drop")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8), spacing: 10) {
                    ForEach(0..<goal, id: \.self) { i in
                        Image(systemName: i < cups ? "drop.fill" : "drop")
                            .font(.title3)
                            .foregroundStyle(i < cups ? Color.accentColor : Color.secondary.opacity(0.3))
                            .animation(.easeInOut(duration: 0.2).delay(Double(i) * 0.03), value: cups)
                    }
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Sleep

private struct SleepEntry: Identifiable {
    let id: String
    let day: String
    let bedtime: String
    let wakeTime: String
    let duration: Double
    let quality: SleepQuality
    let notes: String?
}

private enum SleepQuality: String {
    case poor, fair, good, great
    var label: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .poor:  return .red
        case .fair:  return .orange
        case .good:  return .blue
        case .great: return .green
        }
    }
    var icon: String {
        switch self {
        case .poor:  return "moon.zzz"
        case .fair:  return "moon"
        case .good:  return "moon.stars"
        case .great: return "sparkles"
        }
    }
}

private let mockSleepLog: [SleepEntry] = [
    SleepEntry(id: "s1", day: "Last night", bedtime: "10:45 PM", wakeTime: "6:30 AM", duration: 7.75, quality: .great, notes: "No interruptions, felt rested."),
    SleepEntry(id: "s2", day: "Fri Apr 18", bedtime: "11:30 PM", wakeTime: "7:00 AM", duration: 7.5, quality: .good, notes: nil),
    SleepEntry(id: "s3", day: "Thu Apr 17", bedtime: "12:15 AM", wakeTime: "6:45 AM", duration: 6.5, quality: .fair, notes: "Woke up once around 3 AM."),
    SleepEntry(id: "s4", day: "Wed Apr 16", bedtime: "10:30 PM", wakeTime: "6:15 AM", duration: 7.75, quality: .great, notes: nil),
    SleepEntry(id: "s5", day: "Tue Apr 15", bedtime: "1:00 AM", wakeTime: "7:30 AM", duration: 6.5, quality: .poor, notes: "Stayed up too late. Felt groggy."),
    SleepEntry(id: "s6", day: "Mon Apr 14", bedtime: "10:50 PM", wakeTime: "6:30 AM", duration: 7.67, quality: .good, notes: nil),
    SleepEntry(id: "s7", day: "Sun Apr 13", bedtime: "11:00 PM", wakeTime: "7:30 AM", duration: 8.5, quality: .great, notes: "Weekend — no alarm."),
]

private struct SleepView: View {
    @State private var selectedEntry: SleepEntry?

    private var avgDuration: Double {
        mockSleepLog.reduce(0.0) { $0 + $1.duration } / Double(mockSleepLog.count)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Summary
            HStack(spacing: 0) {
                SleepStatCell(label: "Avg Duration", value: String(format: "%.1fh", avgDuration), icon: "clock", color: .blue)
                Divider().frame(height: 36)
                SleepStatCell(label: "Last Night", value: String(format: "%.1fh", mockSleepLog[0].duration), icon: "moon.stars.fill", color: .purple)
                Divider().frame(height: 36)
                SleepStatCell(label: "7-Day Best", value: "8.5h", icon: "sparkles", color: .green)
            }
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            ForEach(mockSleepLog) { entry in
                Button {
                    selectedEntry = entry
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: entry.quality.icon)
                            .font(.title3)
                            .foregroundStyle(entry.quality.color)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.day)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                Text("\(entry.bedtime) → \(entry.wakeTime)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.1fh", entry.duration))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                            Text(entry.quality.label)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(entry.quality.color)
                        }
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
        .sheet(item: $selectedEntry) { entry in
            SleepDetailView(entry: entry)
        }
    }
}

private struct SleepStatCell: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SleepDetailView: View {
    let entry: SleepEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.day)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(entry.bedtime) → \(entry.wakeTime)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Duration", systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.2f hours", entry.duration))
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Label("Quality", systemImage: entry.quality.icon)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(entry.quality.label)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(entry.quality.color)
                        }
                    }

                    if let notes = entry.notes {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Notes", systemImage: "note.text")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(notes)
                                .font(.body)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}


// MARK: - Medications

private struct Medication: Identifiable {
    let id: String
    let name: String
    let dosage: String
    let frequency: String
    let icon: String
    let scheduledTimes: [String]
}

private let mockMedications: [Medication] = [
    Medication(id: "vit-d", name: "Vitamin D3", dosage: "5,000 IU", frequency: "Daily", icon: "sun.max", scheduledTimes: ["8:00 AM"]),
    Medication(id: "mag", name: "Magnesium Glycinate", dosage: "400 mg", frequency: "Daily", icon: "leaf", scheduledTimes: ["9:00 PM"]),
    Medication(id: "omega3", name: "Omega-3 Fish Oil", dosage: "2 g", frequency: "Daily", icon: "drop.fill", scheduledTimes: ["8:00 AM"]),
    Medication(id: "zinc", name: "Zinc", dosage: "25 mg", frequency: "Daily", icon: "bolt", scheduledTimes: ["8:00 AM"]),
    Medication(id: "creatine", name: "Creatine Monohydrate", dosage: "5 g", frequency: "Daily", icon: "figure.strengthtraining.traditional", scheduledTimes: ["Post-workout"]),
]

private struct MedicationsView: View {
    @State private var takenIds: Set<String> = ["vit-d", "omega3", "zinc"]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("\(takenIds.count) of \(mockMedications.count) taken today", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(takenIds.count == mockMedications.count ? Color.green : .secondary)
                Spacer()
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            ForEach(mockMedications) { med in
                MedicationRow(med: med, isTaken: takenIds.contains(med.id)) {
                    if takenIds.contains(med.id) {
                        takenIds.remove(med.id)
                    } else {
                        takenIds.insert(med.id)
                    }
                }
            }
        }
    }
}

private struct MedicationRow: View {
    let med: Medication
    let isTaken: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isTaken ? Color.green : Color.secondary.opacity(0.4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(med.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(isTaken ? .secondary : .primary)
                        .strikethrough(isTaken, color: .secondary)
                    Text("\(med.dosage) · \(med.scheduledTimes.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(med.frequency)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }
            .contentShape(Rectangle())
            .padding(14)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.18), value: isTaken)
    }
}

// MARK: - Symptoms

private struct SymptomEntry: Identifiable {
    let id: String
    let date: String
    let time: String
    let symptom: String
    let severity: Int
    let notes: String?
    let icon: String
}

private let mockSymptoms: [SymptomEntry] = [
    SymptomEntry(id: "sym1", date: "Today", time: "7:30 AM", symptom: "Mild headache", severity: 2, notes: "Went away after coffee and water.", icon: "brain"),
    SymptomEntry(id: "sym2", date: "Yesterday", time: "2:00 PM", symptom: "Fatigue", severity: 3, notes: "Didn't sleep well the night before.", icon: "battery.25"),
    SymptomEntry(id: "sym3", date: "Apr 17", time: "6:00 PM", symptom: "Sore muscles", severity: 2, notes: "Legs after squat day.", icon: "figure.walk"),
    SymptomEntry(id: "sym4", date: "Apr 15", time: "11:00 AM", symptom: "Bloating", severity: 2, notes: nil, icon: "stomach"),
    SymptomEntry(id: "sym5", date: "Apr 14", time: "8:30 AM", symptom: "Brain fog", severity: 3, notes: "Improved after workout.", icon: "cloud"),
]

private struct SymptomsView: View {
    @State private var selectedSymptom: SymptomEntry?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Recent symptoms", systemImage: "list.clipboard")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(mockSymptoms.count) logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            ForEach(mockSymptoms) { entry in
                Button {
                    selectedSymptom = entry
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: entry.icon)
                            .font(.title3)
                            .foregroundStyle(severityColor(entry.severity))
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(entry.date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("·")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text(entry.time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.symptom)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        SeverityDots(severity: entry.severity)
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
        .sheet(item: $selectedSymptom) { entry in
            SymptomDetailView(entry: entry)
        }
    }

    private func severityColor(_ level: Int) -> Color {
        switch level {
        case 1: return .green
        case 2: return .orange
        case 3: return .red
        default: return .secondary
        }
    }
}

private struct SeverityDots: View {
    let severity: Int
    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= severity ? severityColor(severity) : Color.secondary.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func severityColor(_ level: Int) -> Color {
        switch level {
        case 1: return .green
        case 2: return .orange
        case 3: return .red
        default: return .secondary
        }
    }
}

private struct SymptomDetailView: View {
    let entry: SymptomEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(entry.date)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("·")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                            Text(entry.time)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.symptom)
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Severity", systemImage: "waveform.path.ecg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                SeverityDots(severity: entry.severity)
                                Text("\(entry.severity) / 5")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let notes = entry.notes {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Notes", systemImage: "note.text")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(notes)
                                .font(.body)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
