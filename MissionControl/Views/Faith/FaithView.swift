import SwiftUI

// MARK: - Faith Tab Root

struct FaithView: View {
    @State private var section: FaithSection = .calendar

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Section", selection: $section) {
                    ForEach(FaithSection.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 4)

                Group {
                    switch section {
                    case .calendar: LiturgicalCalendarView()
                    case .prayers:  PrayersView()
                    case .bible:    BibleView()
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .chatContext(.faith(section: section.label))
        .chatContextToolbar()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // TODO: surface faith actions (e.g. change translation, subscribe to readings).
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }
}

private enum FaithSection: String, CaseIterable, Identifiable {
    case calendar, prayers, bible
    var id: String { rawValue }
    var label: String {
        switch self {
        case .calendar: return "Calendar"
        case .prayers:  return "Prayers"
        case .bible:    return "Bible"
        }
    }
}

// MARK: - Liturgical Calendar

private struct LiturgicalDay {
    let season: String
    let seasonColor: Color
    let weekInSeason: Int
    let dayName: String
    let feastName: String?
    let feastRank: String?
    let massIntroit: String
    let collect: String
    let epistle: Citation
    let gradual: String
    let gospel: Citation
    let secretaPrayer: String
    let postcommunion: String
}

private struct Citation {
    let ref: String
    let text: String
}

private let mockLiturgicalDay = LiturgicalDay(
    season: "Eastertide",
    seasonColor: Color.white,
    weekInSeason: 4,
    dayName: "Saturday after the Fourth Sunday after Easter",
    feastName: "Our Lady of Good Counsel",
    feastRank: "Double",
    massIntroit: "Cantate Domino canticum novum, alleluia: quia mirabilia fecit Dominus, alleluia.",
    collect: "O God, who dost gladden us by the annual solemnity of the Blessed Virgin Mary, Queen of heaven: grant, we beseech Thee, that we who now venerate her as our Mother and Queen may merit to have her as our intercessor before Thee. Through our Lord Jesus Christ, Thy Son, who liveth and reigneth with Thee in the unity of the Holy Ghost, God, world without end.",
    epistle: Citation(
        ref: "Acts 13:26–33",
        text: "Men, brethren, children of the stock of Abraham, and whosoever among you fear God, to you the word of this salvation is sent. For they that dwelt in Jerusalem, and the rulers thereof, not knowing him, nor the voices of the prophets which are read every sabbath, have fulfilled them in condemning him."
    ),
    gradual: "Haec dies quam fecit Dominus: exsultemus, et laetemur in ea. Alleluia, alleluia.",
    gospel: Citation(
        ref: "John 16:5–14",
        text: "But now I go to him that sent me; and none of you asketh me, Whither goest thou? But because I have said these things to you, sorrow hath filled your heart. But I tell you the truth: it is expedient to you that I go: for if I go not, the Paraclete will not come to you; but if I go, I will send him to you."
    ),
    secretaPrayer: "Receive, O Lord, the sacrifice offered for the honor of the Blessed Virgin Mary; and grant that it may obtain for us the grace of Thy mercy. Through our Lord Jesus Christ.",
    postcommunion: "Having received the sacred mysteries, we beseech Thee, O Lord our God, that we who rejoice in honoring the memory of the Blessed Virgin Mary may, by her intercession, be delivered from all dangers. Through our Lord Jesus Christ."
)

private struct LiturgicalCalendarView: View {
    @State private var expandedSection: String? = "readings"
    let day = mockLiturgicalDay

    var body: some View {
        VStack(spacing: 12) {
            // Season banner
            HStack(spacing: 12) {
                Circle()
                    .fill(day.seasonColor.opacity(0.85))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.season.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    Text(day.dayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            // Feast
            if let feast = day.feastName {
                HStack {
                    Label(feast, systemImage: "star.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    if let rank = day.feastRank {
                        Text(rank)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            // Mass Propers
            MassProperSection(title: "Introit", icon: "music.note", text: day.massIntroit, key: "introit", expanded: $expandedSection)
            MassProperSection(title: "Collect", icon: "hands.sparkles", text: day.collect, key: "collect", expanded: $expandedSection)
            CitationSection(title: "Epistle", icon: "book.closed", citation: day.epistle, key: "epistle", expanded: $expandedSection)
            MassProperSection(title: "Gradual & Alleluia", icon: "music.quarternote.3", text: day.gradual, key: "gradual", expanded: $expandedSection)
            CitationSection(title: "Gospel", icon: "book", citation: day.gospel, key: "gospel", expanded: $expandedSection)
            MassProperSection(title: "Secret", icon: "envelope", text: day.secretaPrayer, key: "secret", expanded: $expandedSection)
            MassProperSection(title: "Postcommunion", icon: "heart", text: day.postcommunion, key: "postcommunion", expanded: $expandedSection)
        }
    }
}

private struct MassProperSection: View {
    let title: String
    let icon: String
    let text: String
    let key: String
    @Binding var expanded: String?

    var isExpanded: Bool { expanded == key }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expanded = isExpanded ? nil : key
                }
            } label: {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.subheadline)
                        .fontWeight(.semibold)
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
                Divider().padding(.horizontal, 14)
                Text(text)
                    .font(.body)
                    .italic()
                    .padding(14)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct CitationSection: View {
    let title: String
    let icon: String
    let citation: Citation
    let key: String
    @Binding var expanded: String?

    var isExpanded: Bool { expanded == key }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expanded = isExpanded ? nil : key
                }
            } label: {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(citation.ref)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal, 14)
                VStack(alignment: .leading, spacing: 8) {
                    Text(citation.ref)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(citation.text)
                        .font(.body)
                        .italic()
                }
                .padding(14)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Prayers

private struct Prayer {
    let id: String
    let name: String
    let category: String
    let icon: String
    let latin: String?
    let english: String
    let notes: String?
}

private let mockPrayers: [Prayer] = [
    Prayer(
        id: "angelus",
        name: "The Angelus",
        category: "Marian",
        icon: "bell",
        latin: "Angelus Domini nuntiavit Mariæ, et concepit de Spiritu Sancto.",
        english: "The Angel of the Lord declared unto Mary, and she conceived of the Holy Ghost.\n\nHail Mary...\n\nBehold the handmaid of the Lord; be it done unto me according to Thy word.\n\nHail Mary...\n\nAnd the Word was made Flesh, and dwelt among us.\n\nHail Mary...\n\nPray for us, O Holy Mother of God, that we may be made worthy of the promises of Christ.\n\nLet us pray. Pour forth, we beseech Thee, O Lord, Thy grace into our hearts; that we, to whom the Incarnation of Christ, Thy Son, was made known by the message of an angel, may by His Passion and Cross be brought to the glory of His Resurrection, through the same Christ Our Lord. Amen.",
        notes: "Prayed at 6 AM, noon, and 6 PM."
    ),
    Prayer(
        id: "act-contrition",
        name: "Act of Contrition",
        category: "Penitential",
        icon: "heart.slash",
        latin: "O mi Deus, ex toto corde me pænitet omnium meorum peccatorum...",
        english: "O my God, I am heartily sorry for having offended Thee, and I detest all my sins because of Thy just punishments, but most of all because they offend Thee, my God, who art all good and deserving of all my love. I firmly resolve with the help of Thy grace to sin no more and to avoid the near occasion of sin. Amen.",
        notes: nil
    ),
    Prayer(
        id: "morning-offering",
        name: "Morning Offering",
        category: "Daily",
        icon: "sunrise",
        latin: nil,
        english: "O Jesus, through the Immaculate Heart of Mary, I offer You my prayers, works, joys, and sufferings of this day for all the intentions of Your Sacred Heart, in union with the Holy Sacrifice of the Mass throughout the world, in reparation for my sins, for the intentions of all my associates, and in particular for the intentions of the Holy Father. Amen.",
        notes: nil
    ),
    Prayer(
        id: "divine-mercy",
        name: "Divine Mercy Chaplet",
        category: "Chaplet",
        icon: "cross.circle",
        latin: nil,
        english: "Begin with Our Father, Hail Mary, and the Apostles' Creed.\n\nOn the large beads say:\nEternal Father, I offer You the Body and Blood, Soul and Divinity of Your dearly beloved Son, Our Lord Jesus Christ, in atonement for our sins and those of the whole world.\n\nOn the small beads say:\nFor the sake of His sorrowful Passion, have mercy on us and on the whole world.\n\nConcluding doxology (×3):\nHoly God, Holy Mighty One, Holy Immortal One, have mercy on us and on the whole world.",
        notes: "Prayed at 3 PM, the Hour of Mercy."
    ),
    Prayer(
        id: "memorare",
        name: "The Memorare",
        category: "Marian",
        icon: "person.fill",
        latin: "Memorare, o piissima Virgo Maria, non esse auditum a sæculo, quemquam ad tua currentem præsidia...",
        english: "Remember, O most gracious Virgin Mary, that never was it known that anyone who fled to thy protection, implored thy help, or sought thy intercession was left unaided. Inspired by this confidence, I fly to thee, O Virgin of virgins, my Mother. To thee do I come; before thee I stand, sinful and sorrowful. O Mother of the Word Incarnate, despise not my petitions, but in thy mercy hear and answer me. Amen.",
        notes: nil
    ),
    Prayer(
        id: "sub-tuum",
        name: "Sub Tuum Præsidium",
        category: "Marian",
        icon: "shield",
        latin: "Sub tuum præsidium confugimus, Sancta Dei Genitrix; nostras deprecationes ne despicias in necessitatibus nostris, sed a periculis cunctis libera nos semper, Virgo gloriosa et benedicta.",
        english: "We fly to thy patronage, O holy Mother of God; despise not our petitions in our necessities, but deliver us always from all dangers, O glorious and blessed Virgin.",
        notes: "The oldest known Marian antiphon, c. 250 AD."
    ),
    Prayer(
        id: "come-holy-spirit",
        name: "Come, Holy Spirit",
        category: "Daily",
        icon: "flame",
        latin: "Veni, Sancte Spiritus, reple tuorum corda fidelium...",
        english: "Come, Holy Spirit, fill the hearts of Thy faithful and kindle in them the fire of Thy love. Send forth Thy Spirit and they shall be created, and Thou shalt renew the face of the earth.\n\nLet us pray. O God, who by the light of the Holy Spirit didst instruct the hearts of the faithful, grant that by the same Holy Spirit we may be truly wise and ever rejoice in His consolation. Through Christ Our Lord. Amen.",
        notes: nil
    ),
    Prayer(
        id: "rosary",
        name: "The Holy Rosary",
        category: "Rosary",
        icon: "circle.grid.3x3",
        latin: nil,
        english: "Begin with the Apostles' Creed, then pray one Our Father, three Hail Marys for faith, hope, and charity, and one Glory Be.\n\nFor each mystery: announce the mystery, pray one Our Father, ten Hail Marys while meditating on the mystery, and one Glory Be. The Fatima Prayer may be added.\n\nAfter all five decades, pray the Hail Holy Queen.",
        notes: "Today's mysteries: \(RosaryMystery.forDate(Date()).rawValue)"
    ),
]

private struct PrayersView: View {
    @State private var selectedPrayer: Prayer?
    @State private var selectedCategory: String = "All"

    private var categories: [String] {
        ["All"] + Array(Set(mockPrayers.map(\.category))).sorted()
    }

    private var filtered: [Prayer] {
        selectedCategory == "All" ? mockPrayers : mockPrayers.filter { $0.category == selectedCategory }
    }

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            Text(cat)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    selectedCategory == cat
                                        ? Color.accentColor
                                        : Color.secondary.opacity(0.15),
                                    in: Capsule()
                                )
                                .foregroundStyle(selectedCategory == cat ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ForEach(filtered, id: \.id) { prayer in
                Button {
                    selectedPrayer = prayer
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: prayer.icon)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(prayer.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text(prayer.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(item: $selectedPrayer) { prayer in
            PrayerDetailView(prayer: prayer)
        }
    }
}

extension Prayer: Identifiable {}

private struct PrayerDetailView: View {
    let prayer: Prayer
    @Environment(\.dismiss) private var dismiss
    @State private var showLatin = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(prayer.category)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(prayer.name)
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    if let notes = prayer.notes {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                                .padding(.top, 2)
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if prayer.latin != nil {
                        Toggle(isOn: $showLatin) {
                            Label("Show Latin", systemImage: "character.book.closed")
                                .font(.subheadline)
                        }
                        .tint(.accentColor)
                    }

                    if showLatin, let latin = prayer.latin {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Latin", systemImage: "character.book.closed")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(latin)
                                .font(.body)
                                .italic()
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label("English", systemImage: "book.closed")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(prayer.english)
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

// MARK: - Bible

private struct BibleBook {
    let name: String
    let testament: String
    let chapters: Int
    let previewVerse: String
    let previewRef: String
}

private let mockBibleBooks: [BibleBook] = [
    BibleBook(name: "Genesis", testament: "Old", chapters: 50, previewVerse: "In the beginning, God created the heavens and the earth.", previewRef: "Gen 1:1"),
    BibleBook(name: "Psalms", testament: "Old", chapters: 150, previewVerse: "The Lord is my shepherd; I shall not want.", previewRef: "Ps 23:1"),
    BibleBook(name: "Proverbs", testament: "Old", chapters: 31, previewVerse: "Trust in the Lord with all your heart, and do not lean on your own understanding.", previewRef: "Prov 3:5"),
    BibleBook(name: "Isaiah", testament: "Old", chapters: 66, previewVerse: "They who wait for the Lord shall renew their strength.", previewRef: "Is 40:31"),
    BibleBook(name: "Matthew", testament: "New", chapters: 28, previewVerse: "Blessed are the poor in spirit, for theirs is the kingdom of heaven.", previewRef: "Mt 5:3"),
    BibleBook(name: "Luke", testament: "New", chapters: 24, previewVerse: "Hail, full of grace, the Lord is with you.", previewRef: "Lk 1:28"),
    BibleBook(name: "John", testament: "New", chapters: 21, previewVerse: "In the beginning was the Word, and the Word was with God.", previewRef: "Jn 1:1"),
    BibleBook(name: "Romans", testament: "New", chapters: 16, previewVerse: "For I am not ashamed of the gospel, for it is the power of God for salvation.", previewRef: "Rom 1:16"),
]

private struct BiblePassage {
    let book: String
    let chapter: Int
    let verses: [(Int, String)]
}

private let mockGenesis1 = BiblePassage(
    book: "Genesis", chapter: 1,
    verses: [
        (1, "In the beginning, God created the heavens and the earth."),
        (2, "The earth was without form and void, and darkness was over the face of the deep. And the Spirit of God was hovering over the face of the waters."),
        (3, "And God said, \"Let there be light,\" and there was light."),
        (4, "And God saw that the light was good. And God separated the light from the darkness."),
        (5, "God called the light Day, and the darkness he called Night. And there was evening and there was morning, the first day."),
        (6, "And God said, \"Let there be an expanse in the midst of the waters, and let it separate the waters from the waters.\""),
        (7, "And God made the expanse and separated the waters that were under the expanse from the waters that were above the expanse. And it was so."),
        (8, "And God called the expanse Heaven. And there was evening and there was morning, the second day."),
        (9, "And God said, \"Let the waters under the heavens be gathered together into one place, and let the dry land appear.\" And it was so."),
        (10, "God called the dry land Earth, and the waters that were gathered together he called Seas. And God saw that it was good."),
    ]
)

private struct BibleView: View {
    @State private var selectedBook: BibleBook?
    @State private var testament: String = "All"

    private let testaments = ["All", "Old", "New"]

    private var filtered: [BibleBook] {
        testament == "All" ? mockBibleBooks : mockBibleBooks.filter { $0.testament == testament }
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("Testament", selection: $testament) {
                ForEach(testaments, id: \.self) { t in Text(t).tag(t) }
            }
            .pickerStyle(.segmented)

            ForEach(filtered, id: \.name) { book in
                Button {
                    selectedBook = book
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(book.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Text("\(book.chapters) chs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("\"\(book.previewVerse)\"")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .italic()
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(item: $selectedBook) { book in
            BibleBookView(book: book)
        }
    }
}

extension BibleBook: Identifiable {
    var id: String { name }
}

private struct BibleBookView: View {
    let book: BibleBook
    @Environment(\.dismiss) private var dismiss
    let passage = mockGenesis1

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.testament + " Testament")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(book.name)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        Text("Chapter 1")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(passage.verses, id: \.0) { num, text in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(num)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .trailing)
                                    .padding(.top, 3)
                                Text(text)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    Text("(Additional chapters and verses will be available when local data sources are added.)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)

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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
