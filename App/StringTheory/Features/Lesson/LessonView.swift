import SwiftUI
import StringTheoryCore

/// Plays through a stage's lessons one at a time. Each lesson fits the screen
/// (no scrolling); finishing one shows a Completed state with Next / Back to
/// Main, and completing a stage's lessons advances the path. A settings gear is
/// in the top-right so tempo and setup are reachable from inside a lesson.
struct StageLessonsView: View {
    let stage: LearningStage

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var showSettings = false
    @State private var showDetail = false

    private var lesson: Lesson { stage.lessons[min(index, stage.lessons.count - 1)] }
    private var isLastLesson: Bool { index >= stage.lessons.count - 1 }
    private var lessonComplete: Bool { model.isLessonComplete(stageID: stage.id, lessonID: lesson.id) }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                ScrollView {
                    content
                        .frame(maxWidth: .infinity, alignment: .top)
                }
                footer
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .tint(Theme.Palette.phosphor)
                .accessibilityLabel("Setup")
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear {
            let allDone = stage.lessons.allSatisfy { model.isLessonComplete(stageID: stage.id, lessonID: $0.id) }
            index = allDone
                ? 0
                : (stage.lessons.firstIndex { !model.isLessonComplete(stageID: stage.id, lessonID: $0.id) } ?? 0)
        }
        .onChange(of: lesson.id) {
            showDetail = false
            model.stopRiff()
            model.stopBacking()
        }
        .onChange(of: model.riffGoalReached) { _, reached in
            if reached, !lessonComplete {
                model.markLessonComplete(stageID: stage.id, lessonID: lesson.id)
                model.stopRiff()
            }
        }
        .onDisappear {
            model.stopRiff()
            model.stopBacking()
        }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if index > 0 {
                    Button { back() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.Palette.phosphor)
                    .accessibilityLabel("Previous lesson")
                }
                Text("STAGE \(stage.number)").sectionLabel()
                Spacer()
                if stage.lessons.count > 1 {
                    LessonDots(count: stage.lessons.count, index: index) { target in
                        model.stopRiff(); model.stopBacking()
                        index = target
                    }
                }
            }

            Text(lesson.title)
                .font(Typography.display(24))
                .foregroundStyle(Theme.Palette.text)

            Text(lesson.subtitle)
                .font(Typography.body(13))
                .foregroundStyle(Theme.Palette.textDim)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            switch lesson.kind {
            case .tab(let riff):
                TabLessonView(riff: riff)
            case .explore(let exercise):
                ExploreLessonView(exercise: exercise)
            case .scale(let key, let type, let showDegrees):
                ScaleLessonView(key: key, type: type, showDegrees: showDegrees)
            case .backing(let key, let type):
                BackingLessonView(key: key, type: type)
            case .chords(let ids):
                ChordsLessonView(chordIDs: ids)
                    .id(lesson.id)
            case .arpeggio(let root, let isMinor):
                ArpeggioLessonView(root: root, isMinor: isMinor)
            case .technique(let technique):
                TechniqueLessonView(lesson: technique)
            case .reading(let body):
                Text(body)
                    .font(Typography.body(15))
                    .foregroundStyle(Theme.Palette.text)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            if let detail = lesson.detail {
                DisclosureGroup(isExpanded: $showDetail) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(detail.paragraphs, id: \.self) { paragraph in
                            Text(paragraph)
                                .font(Typography.body(13))
                                .foregroundStyle(Theme.Palette.text)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(detail.bullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 9) {
                                Circle().fill(Theme.Palette.signalCyan)
                                    .frame(width: 5, height: 5).padding(.top, 6)
                                Text(bullet)
                                    .font(Typography.body(13))
                                    .foregroundStyle(Theme.Palette.textDim)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text(detail.heading)
                        .font(Typography.display(14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.phosphor)
                }
                .tint(Theme.Palette.phosphor)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: Footer

    @ViewBuilder private var footer: some View {
        switch lesson.kind {
        case .tab:
            bottomBar {
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text(model.riffStep.map { String(format: "%02d", $0 + 1) } ?? "--")
                            .font(Typography.mono(20, weight: .bold))
                            .foregroundStyle(Theme.Palette.phosphor)
                            .glow(Theme.Palette.phosphor, radius: 10)
                            .contentTransition(.numericText())
                        Text("STEP")
                            .font(Typography.mono(9)).tracking(1.0)
                            .foregroundStyle(Theme.Palette.textDim)
                    }
                    .frame(minWidth: 40)

                    Button { model.toggleRiff(currentRiff) } label: {
                        Text(model.isPlayingRiff ? "■  Stop" : "▶  Play")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityLabel(model.isPlayingRiff ? "Stop riff" : "Play riff")

                    Spacer(minLength: 0)

                    forwardButton
                }
            }
        case .backing:
            bottomBar {
                HStack(spacing: 16) {
                    Button { model.toggleBacking() } label: {
                        Text(model.isPlayingBacking ? "■  Stop" : "▶  Play backing")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityLabel(model.isPlayingBacking ? "Stop backing track" : "Play backing track")

                    Spacer(minLength: 0)

                    forwardButton
                }
            }
        case .reading, .explore, .scale, .chords, .arpeggio, .technique:
            bottomBar { forwardButton }
        }
    }

    /// The primary forward control. Hands off to a tool tab when the lesson sets
    /// `handoff`, otherwise advances (or finishes) the stage.
    @ViewBuilder private var forwardButton: some View {
        if let tab = lesson.handoff {
            Button(handoffLabel(tab)) { handoff(to: tab) }
                .buttonStyle(PrimaryButtonStyle())
        } else {
            Button(isLastLesson ? "Finish" : "Next") { advance() }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    /// The riff for the current lesson, when it is a tab lesson.
    private var currentRiff: Riff {
        if case .tab(let riff) = lesson.kind { return riff }
        return .drift
    }

    private func bottomBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
            .background(
                Theme.Palette.panelDeep
                    .overlay(Rectangle().frame(height: 1).foregroundStyle(Theme.Palette.hairline), alignment: .top)
            )
    }

    private func advance() {
        model.markLessonComplete(stageID: stage.id, lessonID: lesson.id)
        model.stopRiff()
        model.stopBacking()
        if isLastLesson { dismiss() } else { index += 1 }
    }

    private func back() {
        guard index > 0 else { return }
        model.stopRiff()
        model.stopBacking()
        index -= 1
    }

    /// Marks the lesson complete, stops audio, pops back to the path, and
    /// switches to the tool tab. For a `.scale` lesson it pre-selects the scale
    /// just taught so the explorer opens on it.
    private func handoff(to tab: MainTab) {
        model.markLessonComplete(stageID: stage.id, lessonID: lesson.id)
        model.stopRiff()
        model.stopBacking()
        if case .scale(let key, let type, _) = lesson.kind {
            model.scaleKey = key
            model.scaleType = type
        }
        if case .backing(let key, let type) = lesson.kind {
            model.setSoloKey(key)
            model.setSoloScale(type)
        }
        dismiss()
        model.selectedTab = tab
    }

    private func handoffLabel(_ tab: MainTab) -> String {
        switch tab {
        case .scales: "Open the Scale Explorer"
        case .chords: "Open the Chord Library"
        case .solo:   "Open Solo Practice"
        case .path:   "Back to Path"
        }
    }
}

// MARK: - Tab lesson content (fretboard + tab)

/// The interactive fretboard locked to a tab staff for one riff. As the riff
/// plays, the current note lights up on the neck and the matching tab column
/// highlights. Renders on the learner's own instrument and is tap-to-hear.
private struct TabLessonView: View {
    let riff: Riff

    @Environment(AppModel.self) private var model

    private var openNotes: [Note] { model.openNotes }
    private var stringCount: Int { model.stringCount }

    private var lessonMarkers: [Marker] {
        let activeStep = model.riffStep
        var seen: [String: Marker] = [:]
        for (i, step) in riff.steps.enumerated() {
            let key = "\(step.string):\(step.fret)"
            if i == activeStep {
                seen[key] = Marker(string: step.string, fret: step.fret, kind: .active)
            } else if seen[key] == nil {
                seen[key] = Marker(string: step.string, fret: step.fret, kind: .safe)
            }
        }
        return Array(seen.values)
    }

    private var tabRows: [TabRow] {
        let activeStep = model.riffStep
        return stride(from: stringCount - 1, through: 0, by: -1).map { sIdx in
            let note = openNotes.indices.contains(sIdx) ? openNotes[sIdx].name : ""
            let cells = riff.steps.enumerated().map { i, step -> TabCell in
                let has = step.string == sIdx
                return TabCell(fret: has ? step.fret : nil, isActive: has && i == activeStep)
            }
            return TabRow(stringIndex: sIdx, noteName: note, cells: cells)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FretboardView(
                geometry: FretboardGeometry(stringCount: stringCount, fretCount: 5, startFret: 0, isLeftHanded: model.isLeftHanded),
                openNotes: openNotes,
                markers: lessonMarkers,
                onTapPosition: { string, fret in model.playNote(string: string, fret: fret) }
            )
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            .panel()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("TABLATURE · \(riff.name)").sectionLabel()
                    Spacer()
                    Text("♩ = \(model.tempo)").font(Typography.mono(10)).foregroundStyle(Theme.Palette.textDim)
                }
                VStack(spacing: 0) {
                    ForEach(Array(tabRows.enumerated()), id: \.offset) { _, row in
                        TabRowView(row: row).frame(height: 24)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.Palette.panel, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.Palette.hairline, lineWidth: 1))
            }
        }
    }
}

// MARK: - Tab data models

private struct TabRow {
    let stringIndex: Int
    let noteName: String
    let cells: [TabCell]
}

private struct TabCell {
    let fret: Int?
    let isActive: Bool
}

private struct TabRowView: View {
    let row: TabRow

    var body: some View {
        HStack(spacing: 10) {
            Text(row.noteName)
                .font(Typography.mono(11, weight: .semibold))
                .foregroundStyle(Color(oklchL: 0.6, c: 0.04, h: 160).opacity(0.8))
                .frame(width: 14, alignment: .center)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(oklchL: 0.5, c: 0.03, h: 160).opacity(0.22))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                    HStack(spacing: 0) {
                        ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                            ZStack {
                                if let fret = cell.fret {
                                    Text("\(fret)")
                                        .font(Typography.mono(13, weight: .bold))
                                        .foregroundStyle(cell.isActive ? Color(oklchL: 0.16, c: 0.03, h: 150) : Color(oklchL: 0.88, c: 0.02, h: 220))
                                        .frame(minWidth: 22, alignment: .center)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(cell.isActive ? Theme.Palette.phosphor : Color(oklchL: 0.17, c: 0.016, h: 250))
                                        )
                                        .glow(cell.isActive ? Theme.Palette.phosphor : .clear, radius: cell.isActive ? 10 : 0)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Explore lesson content (guided, tap-to-hear fretboard)

/// A guided fretboard for the Fretboard Basics lessons. Shows a small set of
/// dots, open strings, a run of fret numbers, or every place one note lives, on
/// the learner's own instrument, and plays the pitch when a dot is tapped.
private struct ExploreLessonView: View {
    let exercise: ExploreLesson

    @Environment(AppModel.self) private var model

    private var markers: [Marker] {
        switch exercise {
        case .openStrings:
            return (0..<model.stringCount).map { s in
                Marker(string: s, fret: 0, kind: .open, label: model.openNotes[s].name)
            }
        case .fretNumbers:
            return (1...5).map { f in
                Marker(string: 0, fret: f, kind: .safe, label: "\(f)")
            }
        case .findNote(let target):
            var found: [Marker] = []
            for s in 0..<model.stringCount {
                for f in 0...5 where noteAt(open: model.openNotes[s], fret: f) == target {
                    found.append(Marker(string: s, fret: f, kind: .root, label: target.name))
                }
            }
            return found
        }
    }

    var body: some View {
        FretboardView(
            geometry: FretboardGeometry(stringCount: model.stringCount, fretCount: 5,
                                        startFret: 0, isLeftHanded: model.isLeftHanded),
            openNotes: model.openNotes,
            markers: markers,
            onTapPosition: { string, fret in model.playNote(string: string, fret: fret) }
        )
        .frame(height: 230)
        .panel()
    }
}

// MARK: - Scale lesson content (degrees on the neck, tap-to-hear)

/// A scale on the learner's own neck: the core's `scaleMarkers` light the root
/// in cyan and label every tone with its degree. `showDegrees` keeps or strips
/// those labels, so an intro lesson can show the bare shape (root color only)
/// before a later lesson names the degrees. Tapping a note plays it.
private struct ScaleLessonView: View {
    let key: Note
    let type: ScaleType
    let showDegrees: Bool

    @Environment(AppModel.self) private var model

    /// The scale tones. `scaleMarkers` always labels each with its degree; with
    /// `showDegrees` off we drop the labels so only the cyan root stands out.
    private var markers: [Marker] {
        let base = scaleMarkers(instrument: model.instrument, key: key, scale: type, frets: 12)
        guard !showDegrees else { return base }
        return base.map { var marker = $0; marker.label = nil; return marker }
    }

    var body: some View {
        FretboardView(
            geometry: FretboardGeometry(stringCount: model.stringCount, fretCount: 12,
                                        startFret: 0, isLeftHanded: model.isLeftHanded),
            openNotes: model.openNotes,
            markers: markers,
            onTapPosition: { string, fret in model.playNote(string: string, fret: fret) }
        )
        .frame(height: 290)
        .panel()
    }
}

// MARK: - Backing lesson content (solo over the loop, tap-to-hear)

/// The Solo screen's neck inside a lesson: `scaleMarkers` lights every safe note,
/// and while the backing loop plays the current chord's root pulses (`.active`).
/// A compact chord row shows the loop. Tapping a note plays it. Appearing sets the
/// model's solo key/scale so the shared backing engine drives this lesson's key,
/// which also means the final Solo Practice handoff opens on the same key.
private struct BackingLessonView: View {
    let key: Note
    let type: ScaleType

    @Environment(AppModel.self) private var model

    /// Safe notes for the key; the active chord's root pulses as the loop plays.
    private var markers: [Marker] {
        let activeRoot = model.activeBackingRoot
        return scaleMarkers(instrument: model.instrument, key: key, scale: type, frets: 12)
            .map { marker in
                if let activeRoot, marker.note == activeRoot {
                    return Marker(string: marker.string, fret: marker.fret, kind: .active, note: marker.note, label: marker.label)
                }
                return marker
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FretboardView(
                geometry: FretboardGeometry(stringCount: model.stringCount, fretCount: 12,
                                            startFret: 0, isLeftHanded: model.isLeftHanded),
                openNotes: model.openNotes,
                markers: markers,
                onTapPosition: { string, fret in model.playNote(string: string, fret: fret) }
            )
            .frame(height: 290)
            .panel()

            backingLoop
        }
        .onAppear {
            model.setSoloKey(key)
            model.setSoloScale(type)
        }
    }

    private var backingLoop: some View {
        let chords = backingProgression(key: key, scale: type)
        return VStack(alignment: .leading, spacing: 8) {
            Text("BACKING LOOP").sectionLabel()
            HStack(spacing: 7) {
                ForEach(Array(chords.enumerated()), id: \.offset) { index, chord in
                    let isActive = model.backingChordIndex == index
                    Text(chord.name)
                        .font(Typography.display(15, weight: .semibold))
                        .foregroundStyle(isActive ? Color(oklchL: 0.16, c: 0.03, h: 150) : Theme.Palette.text)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(RoundedRectangle(cornerRadius: 9).fill(isActive ? Theme.Palette.phosphor : Color(oklchL: 0.2, c: 0.018, h: 250)))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(isActive ? Theme.Palette.phosphor : Theme.Palette.hairline, lineWidth: 1))
                        .glow(isActive ? Theme.Palette.phosphor : .clear, radius: isActive ? 12 : 0)
                        .animation(.easeOut(duration: 0.12), value: isActive)
                        .accessibilityLabel("Chord \(chord.name)")
                }
            }
        }
    }
}

// MARK: - Chords lesson content (guitar diagrams, tap-to-hear)

/// One or more guitar chord diagrams drawn with the core `chordMarkers` (rings
/// for open strings, x for muted, note-labelled dots). When the lesson lists more
/// than one chord, a row of name buttons steps between them. Tapping a dot plays
/// its note. The shown chord is mirrored into `model.chordID`, so the stage's
/// final handoff opens the Chord Library on it. Always a 6-string guitar voicing,
/// matching the Chord Library and the prototype.
private struct ChordsLessonView: View {
    let chordIDs: [String]

    @Environment(AppModel.self) private var model
    @State private var index = 0

    private var chord: Chord {
        Chord.named(chordIDs[min(index, chordIDs.count - 1)]) ?? Chord.library[0]
    }

    private var soundedNotes: [Note] {
        var seen = Set<Note>()
        return chordMarkers(chord)
            .filter { $0.kind != .muted }
            .compactMap(\.note)
            .filter { seen.insert($0).inserted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if chordIDs.count > 1 {
                HStack(spacing: 8) {
                    ForEach(Array(chordIDs.enumerated()), id: \.offset) { i, id in
                        let isActive = i == index
                        let name = Chord.named(id)?.name ?? id
                        Button {
                            index = i
                            model.chordID = id
                        } label: {
                            Text(name)
                                .font(Typography.display(15, weight: .semibold))
                                .foregroundStyle(isActive ? Theme.Palette.phosphor : Theme.Palette.textDim)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(RoundedRectangle(cornerRadius: 9).fill(isActive ? Theme.Palette.phosphor.opacity(0.16) : Color(oklchL: 0.2, c: 0.018, h: 250)))
                                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(isActive ? Theme.Palette.phosphor : Theme.Palette.hairline, lineWidth: 1))
                                .glow(isActive ? Theme.Palette.phosphor.opacity(0.5) : .clear, radius: isActive ? 8 : 0)
                        }
                        .animation(.easeInOut(duration: 0.14), value: isActive)
                        .accessibilityLabel("Show \(name)")
                        .accessibilityAddTraits(isActive ? [.isSelected] : [])
                    }
                }
            }

            FretboardView(
                geometry: FretboardGeometry(stringCount: 6, fretCount: 5, startFret: 0, isLeftHanded: model.isLeftHanded),
                openNotes: Tuning.guitar.strings.map(\.note),
                markers: chordMarkers(chord),
                onTapPosition: { string, fret in model.playNote(string: string, fret: fret) }
            )
            .frame(height: 230)
            .panel()

            HStack(spacing: 12) {
                Button { model.playChord(chord) } label: {
                    Text("▶  Play chord")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel("Play the \(chord.name) chord")

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("NOTES").sectionLabel()
                    Text(soundedNotes.map(\.name).joined(separator: " · "))
                        .font(Typography.mono(13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.signalCyan)
                }
            }
        }
        .onAppear {
            assert(model.instrument == .guitar, ".chords lessons are guitar only")
            model.chordID = chordIDs.first ?? "C"
        }
    }
}

// MARK: - Arpeggio lesson content (bass chord tones, tap-to-hear)

/// A chord's root, third, and fifth across the bass neck, from the core
/// `arpeggioMarkers`: the root glows cyan and is labelled R, the third and fifth
/// are labelled 3 and 5. Tapping a note plays it. Used by the bass Chords track.
private struct ArpeggioLessonView: View {
    let root: Note
    let isMinor: Bool

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FretboardView(
                geometry: FretboardGeometry(stringCount: model.stringCount, fretCount: 12,
                                            startFret: 0, isLeftHanded: model.isLeftHanded),
                openNotes: model.openNotes,
                markers: arpeggioMarkers(instrument: model.instrument, root: root, isMinor: isMinor, frets: 12),
                onTapPosition: { string, fret in model.playNote(string: string, fret: fret) }
            )
            .frame(maxWidth: .infinity)
            .frame(height: 290)
            .panel()

            Button { model.arpeggiate(root: root, isMinor: isMinor) } label: {
                Text("▶  Play root · 3 · 5")
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel("Play the arpeggio")
        }
    }
}

// MARK: - Lesson stepper

/// A tappable row of dots for jumping between a stage's lessons. The current
/// lesson glows; any lesson can be revisited.
private struct LessonDots: View {
    let count: Int
    let index: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Button { onSelect(i) } label: {
                    Circle()
                        .fill(i == index ? Theme.Palette.phosphor : Theme.Palette.textDim.opacity(0.4))
                        .frame(width: 7, height: 7)
                        .glow(i == index ? Theme.Palette.phosphor : .clear, radius: i == index ? 5 : 0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Go to lesson \(i + 1)")
                .accessibilityAddTraits(i == index ? [.isSelected] : [])
            }
        }
    }
}

// MARK: - Technique lesson content (drawn diagrams, Fretboard Basics)

/// A beginner technique screen: a drawn diagram plus a short list of cues. No
/// fretboard and no audio. `.holding` adapts for guitar versus bass.
private struct TechniqueLessonView: View {
    let lesson: TechniqueLesson
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Group {
                switch lesson {
                case .holding:  HoldingDiagram(instrument: model.instrument)
                case .fretting: FrettingDiagram()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .panel()

            VStack(alignment: .leading, spacing: 9) {
                ForEach(cues, id: \.self) { cue in
                    HStack(alignment: .top, spacing: 9) {
                        Circle().fill(Theme.Palette.phosphor)
                            .frame(width: 5, height: 5).padding(.top, 6)
                        Text(cue)
                            .font(Typography.body(13))
                            .foregroundStyle(Theme.Palette.textDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var cues: [String] {
        switch lesson {
        case .holding:
            return model.instrument == .bass
                ? ["Sit with the bass against your stomach, its waist on your strong-side leg.",
                   "Let the neck point up and out, not flat across your body.",
                   "Thumb rests behind the neck, roughly opposite your fingers; keep the hand loose.",
                   "Your plucking hand floats over the strings near the pickups."]
                : ["Sit with the guitar against your stomach, its waist on your strong-side leg.",
                   "Angle the neck slightly up so your fretting wrist stays straight, not bent.",
                   "Thumb rests behind the neck, roughly opposite your fingers.",
                   "Your strumming hand floats over the sound hole or pickups."]
        case .fretting:
            return ["Press with the very tip of the finger, not the flat pad.",
                    "Land just behind the fret, never on top of it.",
                    "Keep the knuckle bent so the tip comes straight down.",
                    "Press only until the note rings clean. No buzz is enough; white knuckles is too hard.",
                    "Short nails let the fingertip stand up on the string."]
        }
    }
}

/// A schematic of the instrument at a playing angle, with the two hand zones
/// marked. Tuned for clarity, not realism.
private struct HoldingDiagram: View {
    let instrument: Instrument

    var body: some View {
        Canvas { ctx, size in
            let dim = GraphicsContext.Shading.color(Theme.Palette.textDim.opacity(0.55))
            let phosphor = GraphicsContext.Shading.color(Theme.Palette.phosphor)
            let cyan = GraphicsContext.Shading.color(Theme.Palette.signalCyan)
            let w = size.width, h = size.height

            // Body blob, lower-left.
            let bodyCenter = CGPoint(x: w * 0.34, y: h * 0.66)
            let bodyW = w * 0.30, bodyH = h * 0.40
            let body = Path(ellipseIn: CGRect(x: bodyCenter.x - bodyW / 2, y: bodyCenter.y - bodyH / 2,
                                              width: bodyW, height: bodyH))
            ctx.stroke(body, with: dim, lineWidth: 2)

            // Neck up to the upper-right.
            let neckLength = (instrument == .bass ? 0.60 : 0.50) * w
            let neckWidth: CGFloat = instrument == .bass ? 13 : 17
            let start = CGPoint(x: bodyCenter.x + bodyW * 0.18, y: bodyCenter.y - bodyH * 0.18)
            let angle = -0.5
            let end = CGPoint(x: start.x + CoreGraphics.cos(angle) * neckLength,
                              y: start.y + CoreGraphics.sin(angle) * neckLength)
            var neck = Path(); neck.move(to: start); neck.addLine(to: end)
            ctx.stroke(neck, with: phosphor, lineWidth: neckWidth)

            // Hand zones: fretting near the neck end, plucking over the body.
            func dot(_ p: CGPoint) { ctx.fill(Path(ellipseIn: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16)), with: cyan) }
            let fretHand = CGPoint(x: start.x + CoreGraphics.cos(angle) * neckLength * 0.78,
                                   y: start.y + CoreGraphics.sin(angle) * neckLength * 0.78 + 14)
            let pluckHand = CGPoint(x: bodyCenter.x + bodyW * 0.05, y: bodyCenter.y)
            dot(fretHand); dot(pluckHand)

            ctx.draw(Text("neck up + out").font(Typography.mono(10)).foregroundColor(Theme.Palette.textDim),
                     at: CGPoint(x: end.x - 4, y: end.y - 18))
            ctx.draw(Text("fretting hand").font(Typography.mono(10)).foregroundColor(Theme.Palette.signalCyan),
                     at: CGPoint(x: fretHand.x, y: fretHand.y + 18))
            ctx.draw(Text("plucking hand").font(Typography.mono(10)).foregroundColor(Theme.Palette.signalCyan),
                     at: CGPoint(x: pluckHand.x, y: pluckHand.y + 26))
        }
    }
}

/// A zoomed cross-section: a string over a fret, with a bent fingertip pressing
/// just behind the fret. The cyan dot is the contact point.
private struct FrettingDiagram: View {
    var body: some View {
        Canvas { ctx, size in
            let dim = GraphicsContext.Shading.color(Theme.Palette.textDim.opacity(0.6))
            let phosphor = GraphicsContext.Shading.color(Theme.Palette.phosphor)
            let cyan = GraphicsContext.Shading.color(Theme.Palette.signalCyan)
            let w = size.width, h = size.height
            let stringY = h * 0.62

            // The string.
            var stringPath = Path()
            stringPath.move(to: CGPoint(x: w * 0.08, y: stringY))
            stringPath.addLine(to: CGPoint(x: w * 0.92, y: stringY))
            ctx.stroke(stringPath, with: dim, lineWidth: 2)

            // Two frets (vertical ticks); the target fret is brighter.
            func fret(_ x: CGFloat, bright: Bool) {
                var p = Path(); p.move(to: CGPoint(x: x, y: stringY - 18)); p.addLine(to: CGPoint(x: x, y: stringY + 18))
                ctx.stroke(p, with: bright ? phosphor : dim, lineWidth: bright ? 3 : 2)
            }
            let targetFretX = w * 0.58
            fret(w * 0.30, bright: false)
            fret(targetFretX, bright: true)

            // The finger: a bent shape coming down just behind the target fret.
            let contact = CGPoint(x: targetFretX - w * 0.07, y: stringY)
            var finger = Path()
            finger.move(to: CGPoint(x: contact.x - 36, y: stringY - 96))
            finger.addQuadCurve(to: CGPoint(x: contact.x - 6, y: stringY - 30),
                                control: CGPoint(x: contact.x - 34, y: stringY - 48))
            finger.addQuadCurve(to: contact, control: CGPoint(x: contact.x - 2, y: stringY - 12))
            ctx.stroke(finger, with: GraphicsContext.Shading.color(Theme.Palette.text), lineWidth: 14)

            // Contact dot.
            ctx.fill(Path(ellipseIn: CGRect(x: contact.x - 7, y: contact.y - 7, width: 14, height: 14)), with: cyan)

            ctx.draw(Text("just behind the fret").font(Typography.mono(10)).foregroundColor(Theme.Palette.signalCyan),
                     at: CGPoint(x: contact.x + 6, y: stringY + 26))
            ctx.draw(Text("fret").font(Typography.mono(10)).foregroundColor(Theme.Palette.phosphor),
                     at: CGPoint(x: targetFretX, y: stringY - 30))
        }
    }
}
