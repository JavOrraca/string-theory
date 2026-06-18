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

    private var lesson: Lesson { stage.lessons[min(index, stage.lessons.count - 1)] }
    private var isLastLesson: Bool { index >= stage.lessons.count - 1 }
    private var lessonComplete: Bool { model.isLessonComplete(stageID: stage.id, lessonID: lesson.id) }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            index = stage.lessons.firstIndex { !model.isLessonComplete(stageID: stage.id, lessonID: $0.id) } ?? 0
        }
        .onChange(of: lesson.id) {
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
            HStack {
                Text("STAGE \(stage.number)").sectionLabel()
                Spacer()
                if stage.lessons.count > 1 {
                    Text("LESSON \(index + 1) / \(stage.lessons.count)")
                        .font(Typography.mono(10, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(Theme.Palette.textDim)
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
            case .reading(let body):
                Text(body)
                    .font(Typography.body(15))
                    .foregroundStyle(Theme.Palette.text)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
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
        case .reading, .explore, .scale, .chords, .arpeggio:
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .panel()

            HStack(spacing: 8) {
                Text("NOTES").sectionLabel()
                Text(soundedNotes.map(\.name).joined(separator: " · "))
                    .font(Typography.mono(13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.signalCyan)
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
        FretboardView(
            geometry: FretboardGeometry(stringCount: model.stringCount, fretCount: 12,
                                        startFret: 0, isLeftHanded: model.isLeftHanded),
            openNotes: model.openNotes,
            markers: arpeggioMarkers(instrument: model.instrument, root: root, isMinor: isMinor, frets: 12),
            onTapPosition: { string, fret in model.playNote(string: string, fret: fret) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .panel()
    }
}
