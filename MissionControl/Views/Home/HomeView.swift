import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var rosaryState = RosaryState()
    @State private var dailyNote = DailyNote()
    @State private var showingNoteEditor = false
    @State private var showingSettings = false
    @State private var selectedBrief: DailyBrief?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        PrayerScriptureCard(mystery: RosaryMystery.forDate(Date()),
                                           state: rosaryState)

                        HealthCard()

                        BriefsRow(selectedBrief: $selectedBrief)

                        DailyNoteCard(note: dailyNote, showEditor: $showingNoteEditor)

                        TodayTasksCard(slots: viewModel.todayTaskSlots)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .chatContext(.home)
            .chatContextToolbar()
            .refreshable { await viewModel.load() }
            .errorAlert(message: $viewModel.error)
            .task { await viewModel.load() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingNoteEditor) {
                DailyNoteEditorView(note: dailyNote)
            }
            .sheet(item: $selectedBrief) { brief in
                BriefDetailView(brief: brief)
            }
        }
    }
}

// MARK: - Prayer & Scripture Card

private struct ScriptureReading {
    let citation: String
    let preview: String
    let fullText: String
    let reflection: String
}

private let placeholderReadings: [ScriptureReading] = [
    ScriptureReading(
        citation: "Genesis 1:1–2:3",
        preview: "In the beginning, God created the heavens and the earth.",
        fullText: "In the beginning, God created the heavens and the earth. The earth was without form and void, and darkness was over the face of the deep. And the Spirit of God was hovering over the face of the waters. And God said, \"Let there be light,\" and there was light. And God saw that the light was good. And God separated the light from the darkness. God called the light Day, and the darkness he called Night.",
        reflection: "God brings order from chaos and light from darkness. In our own lives, we are invited to trust that He is always at work, shaping and forming us toward His good purpose."
    ),
    ScriptureReading(
        citation: "John 1:1–18",
        preview: "In the beginning was the Word, and the Word was with God.",
        fullText: "In the beginning was the Word, and the Word was with God, and the Word was God. He was in the beginning with God. All things were made through him, and without him was not any thing made that was made. In him was life, and the life was the light of men. The light shines in the darkness, and the darkness has not overcome it. And the Word became flesh and dwelt among us, and we have seen his glory, glory as of the only Son from the Father, full of grace and truth.",
        reflection: "The Word became flesh and dwelt among us — God entering our story. This mystery calls us to recognize the divine presence in the ordinary moments of our day."
    ),
    ScriptureReading(
        citation: "Psalm 23",
        preview: "The Lord is my shepherd; I shall not want.",
        fullText: "The Lord is my shepherd; I shall not want. He makes me lie down in green pastures. He leads me beside still waters. He restores my soul. He leads me in paths of righteousness for his name's sake. Even though I walk through the valley of the shadow of death, I will fear no evil, for you are with me; your rod and your staff, they comfort me. You prepare a table before me in the presence of my enemies; you anoint my head with oil; my cup overflows.",
        reflection: "The Good Shepherd knows each sheep by name and leads with gentleness. Today, let yourself be led — release control and follow where He guides."
    ),
]

// MARK: - Mystery mock detail

private struct MysteryDetail {
    let ordinal: String
    let name: String
    let type: String
    let fruit: String
    let scriptureRef: String
    let scriptureText: String
    let meditation: String
}

private func mockDetail(for mystery: RosaryMystery, index: Int, name: String) -> MysteryDetail {
    let ordinals = ["1st", "2nd", "3rd", "4th", "5th"]
    let ordinal = ordinals[max(0, min(index - 1, 4))]

    switch mystery {
    case .joyful:
        switch index {
        case 1: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Humility", scriptureRef: "Luke 1:28", scriptureText: "Hail, full of grace, the Lord is with you. Blessed are you among women.", meditation: "Mary humbly accepts God's call, trusting completely in His plan even without fully understanding it. We are invited to say our own 'yes' to God today.")
        case 2: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Love of Neighbor", scriptureRef: "Luke 1:41", scriptureText: "When Elizabeth heard Mary's greeting, the baby leaped in her womb.", meditation: "Mary hastens to serve her cousin Elizabeth. True love goes out of its way to be present to those in need. Who can I visit or serve with joy today?")
        case 3: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Poverty of Spirit", scriptureRef: "Luke 2:7", scriptureText: "She wrapped him in swaddling cloths and laid him in a manger.", meditation: "God chooses poverty and simplicity to enter the world. Contemplate how little the Eternal Word required — and how much He gave by becoming one of us.")
        case 4: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Obedience", scriptureRef: "Luke 2:22", scriptureText: "They brought him to Jerusalem to present him to the Lord.", meditation: "Mary and Joseph faithfully fulfill every requirement of the Law. Holy obedience is not servile fear but loving trust in a Father who knows best.")
        default: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Piety", scriptureRef: "Luke 2:46", scriptureText: "They found him in the temple, sitting among the teachers, listening and asking questions.", meditation: "Jesus, fully God, sat at the feet of teachers — modeling lifelong learning rooted in the love of the Father. Return to your Father's house in prayer today.")
        }
    case .luminous:
        switch index {
        case 1: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Openness to the Holy Spirit", scriptureRef: "Matthew 3:17", scriptureText: "This is my beloved Son, with whom I am well pleased.", meditation: "At baptism the Trinity is revealed and Jesus is anointed for mission. Our own baptism made us beloved daughters and sons — live from that identity today.")
        case 2: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Fidelity", scriptureRef: "John 2:5", scriptureText: "His mother said to the servants, 'Do whatever he tells you.'", meditation: "Mary's intercession moves Christ to act before His hour had come. Her instruction — 'Do whatever He tells you' — is the whole of the spiritual life in seven words.")
        case 3: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Desire for Holiness", scriptureRef: "Mark 1:15", scriptureText: "The kingdom of God is at hand; repent and believe in the gospel.", meditation: "Jesus proclaims the Kingdom and calls us to conversion. Metanoia is not punishment but invitation — a turning toward the beauty of God.")
        case 4: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Desire for Sanctity", scriptureRef: "Matthew 17:2", scriptureText: "His face shone like the sun, and his clothes became white as light.", meditation: "The disciples glimpse Jesus as He truly is — radiant with the glory of the Trinity. We too are called to transfiguration, from glory to glory, by the Spirit.")
        default: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Eucharistic Adoration", scriptureRef: "Luke 22:19", scriptureText: "This is my body, which is given for you. Do this in remembrance of me.", meditation: "At the Last Supper, Jesus gives Himself entirely — body, blood, soul, and divinity — as our food for the journey. Receive Him with gratitude and awe.")
        }
    case .sorrowful:
        switch index {
        case 1: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Contrition for Sin", scriptureRef: "Luke 22:44", scriptureText: "His sweat became like great drops of blood falling to the ground.", meditation: "In Gethsemane Jesus takes on the full weight of human sin and anguish. He did not flee suffering but embraced it out of love. Bring your anguish to Him.")
        case 2: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Mortification", scriptureRef: "John 19:1", scriptureText: "Pilate took Jesus and had him flogged.", meditation: "Jesus endures unjust punishment without retaliation. His suffering redeems ours. Unite your daily sufferings — however small — with His Passion.")
        case 3: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Moral Courage", scriptureRef: "Matthew 27:29", scriptureText: "They wove a crown of thorns and put it on his head.", meditation: "The King of Kings is mocked with a crown of thorns. Dignity cannot be stripped from one who knows whose they are. Stand firm in your identity as a child of God.")
        case 4: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Patience", scriptureRef: "John 19:17", scriptureText: "He went out, bearing his own cross, to the place called The Place of a Skull.", meditation: "Jesus falls and rises, again and again, always moving forward under the weight of the cross. Persevere in your crosses today — He walks them with you.")
        default: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Salvation", scriptureRef: "John 19:30", scriptureText: "When Jesus had received the sour wine, he said, 'It is finished,' and he bowed his head and gave up his spirit.", meditation: "It is finished — the greatest act of love in human history. The crucifixion is not defeat but total self-gift. Let His love move you to generosity today.")
        }
    case .glorious:
        switch index {
        case 1: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Faith", scriptureRef: "Mark 16:6", scriptureText: "He has risen; he is not here. See the place where they laid him.", meditation: "The tomb is empty — death has been conquered. Faith is not wishful thinking but trust in the living God who keeps His promises. He is risen indeed.")
        case 2: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Hope", scriptureRef: "Acts 1:9", scriptureText: "As they were looking on, he was lifted up, and a cloud took him out of their sight.", meditation: "Jesus ascends to prepare a place for us. Our destiny is to be with God forever. Let this hope anchor you in every difficulty you face today.")
        case 3: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Wisdom", scriptureRef: "Acts 2:4", scriptureText: "They were all filled with the Holy Spirit and began to speak in other tongues.", meditation: "The Spirit transforms frightened disciples into bold witnesses. That same Spirit dwells in you. Ask Him for wisdom, courage, and the words you need today.")
        case 4: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Grace of a Holy Death", scriptureRef: "Revelation 12:1", scriptureText: "A woman clothed with the sun, with the moon under her feet, and on her head a crown of twelve stars.", meditation: "Mary's body and soul are taken into heaven — a foretaste of our own resurrection. She who walked the earth as we do now intercedes for us from glory.")
        default: return MysteryDetail(ordinal: ordinal, name: name, type: mystery.rawValue, fruit: "Trust in Mary's Intercession", scriptureRef: "Revelation 12:10", scriptureText: "Now the salvation and the power and the kingdom of our God and the authority of his Christ have come.", meditation: "Our Lady is crowned Queen of Heaven and Earth. As a good queen she intercedes for her children. Bring your needs to her today with confidence.")
        }
    }
}

private struct PrayerScriptureCard: View {
    let mystery: RosaryMystery
    @Bindable var state: RosaryState
    @State private var isExpanded = false
    @State private var selectedMystery: MysteryDetail?
    @State private var selectedScripture: ScriptureReading?

    var allChecked: Bool {
        mystery.mysteries.allSatisfy { state.checkedMysteries.contains($0.index) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Collapsible header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Label("Prayer & Scripture", systemImage: "cross")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider()

                    // Rosary mysteries
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Rosary: \(mystery.rawValue) Mysteries")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            if allChecked {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.subheadline)
                            }
                        }

                        ForEach(mystery.mysteries, id: \.index) { item in
                            let isChecked = state.checkedMysteries.contains(item.index)
                            HStack(spacing: 10) {
                                Button {
                                    state.toggle(index: item.index)
                                } label: {
                                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isChecked ? .green : .secondary)
                                        .frame(width: 20)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    selectedMystery = mockDetail(for: mystery, index: item.index, name: item.name)
                                } label: {
                                    Text("\(item.index). \(item.name)")
                                        .font(.subheadline)
                                        .foregroundStyle(isChecked ? .secondary : .primary)
                                        .strikethrough(isChecked, color: .secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()

                    // Scripture readings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Scripture")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        ForEach(placeholderReadings, id: \.citation) { reading in
                            let isChecked = state.checkedScriptures.contains(reading.citation)
                            HStack(alignment: .top, spacing: 10) {
                                Button {
                                    state.toggleScripture(citation: reading.citation)
                                } label: {
                                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isChecked ? .green : .secondary)
                                        .frame(width: 20)
                                        .padding(.top, 2)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    selectedScripture = reading
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(reading.citation)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(isChecked ? .secondary : .primary)
                                            .strikethrough(isChecked, color: .secondary)
                                        Text(reading.preview)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.bottom, 14)
                }
                .padding(.horizontal, 14)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .sheet(item: $selectedMystery) { detail in
            MysteryDetailView(detail: detail)
        }
        .sheet(item: $selectedScripture) { reading in
            ScriptureDetailView(reading: reading)
        }
    }
}

// MARK: - Mystery Detail Sheet

extension MysteryDetail: Identifiable {
    var id: String { "\(type)-\(ordinal)" }
}

private struct MysteryDetailView: View {
    let detail: MysteryDetail
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(detail.ordinal) \(detail.type) Mystery")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(detail.name)
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Fruit of the Mystery", systemImage: "leaf")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(detail.fruit)
                            .font(.body)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label(detail.scriptureRef, systemImage: "book.closed")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(detail.scriptureText)
                            .font(.body)
                            .italic()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Meditation", systemImage: "heart")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(detail.meditation)
                            .font(.body)
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Scripture Detail Sheet

extension ScriptureReading: Identifiable {
    var id: String { citation }
}

private struct ScriptureDetailView: View {
    let reading: ScriptureReading
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Scripture")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(reading.citation)
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Scripture", systemImage: "book.closed")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(reading.fullText)
                            .font(.body)
                            .italic()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Reflection", systemImage: "heart")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(reading.reflection)
                            .font(.body)
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Daily Note Card

private struct DailyNoteCard: View {
    let note: DailyNote
    @Binding var showEditor: Bool

    var body: some View {
        Button { showEditor = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                Label("Daily Note", systemImage: "note.text")
                    .font(.headline)
                    .foregroundStyle(.primary)

                if note.text.isEmpty {
                    Text("Tap to write today's note…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(note.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Today Tasks Card

private struct TodayTasksCard: View {
    let slots: [ScheduleSlot]
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Label("Today's Tasks", systemImage: "checklist")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()

                    if slots.isEmpty {
                        Text("No tasks scheduled today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 16)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(slots) { slot in
                                NavigationLink(value: slot) {
                                    SlotCard(slot: slot, showBreadcrumb: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                    }
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .navigationDestination(for: ScheduleSlot.self) { slot in
            if let taskId = slot.taskId {
                TaskDetailView(taskId: taskId)
            }
        }
    }
}

// MARK: - Daily Note Editor

struct DailyNoteEditorView: View {
    let note: DailyNote
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: Binding(
                get: { note.text },
                set: { note.text = $0 }
            ))
            .font(.body)
            .padding(12)
            .navigationTitle(note.date)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Health Card

private struct HealthCardMeal {
    let type: String
    let name: String
    let calories: Int
    let icon: String
}

private struct HealthCardWorkout {
    let name: String
    let duration: String
    let icon: String
}

private struct HealthCardGame {
    let title: String
    let time: String
    let icon: String
}

private let mockHealthMeals: [HealthCardMeal] = [
    HealthCardMeal(type: "Breakfast", name: "Overnight Oats & Eggs", calories: 520, icon: "sunrise"),
    HealthCardMeal(type: "Lunch", name: "Grilled Chicken Bowl", calories: 680, icon: "sun.max"),
    HealthCardMeal(type: "Snack", name: "Greek Yogurt & Almonds", calories: 210, icon: "leaf"),
    HealthCardMeal(type: "Dinner", name: "Salmon & Vegetables", calories: 590, icon: "moon"),
]

private let mockHealthWorkouts: [HealthCardWorkout] = [
    HealthCardWorkout(name: "Upper Body Strength", duration: "50 min", icon: "dumbbell"),
    HealthCardWorkout(name: "Zone 2 Walk", duration: "30 min", icon: "figure.walk"),
]

private let mockHealthGames: [HealthCardGame] = [
    HealthCardGame(title: "Celtics vs. Knicks", time: "7:30 PM", icon: "basketball"),
    HealthCardGame(title: "Red Sox vs. Yankees", time: "9:05 PM", icon: "baseball"),
]

private struct HealthCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Label("Health", systemImage: "heart")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider()

                    // Meals
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Meals Planned", systemImage: "fork.knife")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        ForEach(mockHealthMeals, id: \.type) { meal in
                            HStack(spacing: 10) {
                                Image(systemName: meal.icon)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(meal.type)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(meal.name)
                                        .font(.subheadline)
                                }
                                Spacer()
                                Text("\(meal.calories) kcal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Divider()

                    // Workouts
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Workouts Planned", systemImage: "figure.run")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        ForEach(mockHealthWorkouts, id: \.name) { workout in
                            HStack(spacing: 10) {
                                Image(systemName: workout.icon)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text(workout.name)
                                    .font(.subheadline)
                                Spacer()
                                Label(workout.duration, systemImage: "clock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Divider()

                    // Games today
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Games Today", systemImage: "sportscourt")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        ForEach(mockHealthGames, id: \.title) { game in
                            HStack(spacing: 10) {
                                Image(systemName: game.icon)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text(game.title)
                                    .font(.subheadline)
                                Spacer()
                                Text(game.time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.bottom, 14)
                }
                .padding(.horizontal, 14)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Briefs

enum DailyBrief: String, Identifiable, CaseIterable {
    case morning, afternoon, evening

    var id: String { rawValue }
    var label: String {
        switch self {
        case .morning:   return "Morning Brief"
        case .afternoon: return "Afternoon Brief"
        case .evening:   return "Evening Brief"
        }
    }
    var shortLabel: String {
        switch self {
        case .morning:   return "Morning"
        case .afternoon: return "Afternoon"
        case .evening:   return "Evening"
        }
    }
    var icon: String {
        switch self {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "moon.stars.fill"
        }
    }
    var color: Color {
        switch self {
        case .morning:   return .orange
        case .afternoon: return .yellow
        case .evening:   return .indigo
        }
    }
    var summary: String {
        switch self {
        case .morning:
            return "Good morning. You have 4 tasks scheduled, a 50-minute upper-body workout, and two games tonight. Weather is 62° and clear — good day for the zone 2 walk after lunch."
        case .afternoon:
            return "Halfway through the day. You've logged 2 of 4 meals and taken 3 of 5 supplements. Two tasks remaining before the 5pm deep-work block. Hydration is on track at 48 oz."
        case .evening:
            return "Day wrapping up. You completed 3 of 4 tasks, hit your workout, and logged all meals. One task rolled forward to tomorrow. Wind-down suggestion: finish by 10:15 for 7.5+ hours of sleep."
        }
    }
    var highlights: [String] {
        switch self {
        case .morning:
            return [
                "4 tasks scheduled, 2 deep-work blocks",
                "Upper Body Strength — 50 min (planned)",
                "Celtics vs. Knicks at 7:30 PM",
                "Rosary: Glorious Mysteries",
            ]
        case .afternoon:
            return [
                "Tasks: 2 done, 2 remaining",
                "Meals logged: Breakfast, Lunch",
                "Hydration: 6 of 8 cups",
                "Deep-work block begins at 5:00 PM",
            ]
        case .evening:
            return [
                "Completed 3 of 4 tasks today",
                "Workout: done (52 min logged)",
                "Notes captured: 1 daily note",
                "Tomorrow: lower body strength + 3 meetings",
            ]
        }
    }
}

private struct BriefsRow: View {
    @Binding var selectedBrief: DailyBrief?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(DailyBrief.allCases) { brief in
                Button {
                    selectedBrief = brief
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: brief.icon)
                            .font(.title3)
                            .foregroundStyle(brief.color)
                        Text(brief.shortLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Text("Brief")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct BriefDetailView: View {
    let brief: DailyBrief
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: brief.icon)
                                .font(.title)
                                .foregroundStyle(brief.color)
                            Text(brief.label)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Summary", systemImage: "text.alignleft")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(brief.summary)
                            .font(.body)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Highlights", systemImage: "sparkles")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(brief.highlights, id: \.self) { item in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(brief.color.opacity(0.6))
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 7)
                                    Text(item)
                                        .font(.body)
                                }
                            }
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
