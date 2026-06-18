# Stage 3 Chords Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stage 3 (Chords) stub with a real, instrument-divergent five-lesson curriculum: guitar gets chord-diagram lessons that hand off to the Chord Library, bass gets a root-and-arpeggio track.

**Architecture:** Two new `LessonKind` cases. `.chords([String])` renders one or more guitar chord diagrams with the existing core `chordMarkers` (rings/x/note-labels), steps between them with a name-button row, is tap-to-hear, and mirrors the shown chord into `model.chordID` so the handoff opens the Chord Library on it. `.arpeggio(root:isMinor:)` renders a chord's root/third/fifth across the bass neck from a new core `arpeggioMarkers` (root cyan, tones labelled R/3/5), tap-to-hear. The Chords stage becomes instrument-aware like Tabs: `chords(for: instrument)`. One core helper, `chordTones(root:isMinor:)`, is factored out of `SynthAudioEngine.playBacking` and feeds both the bass arpeggio markers and the backing voices.

**Tech Stack:** Swift 6, SwiftUI (iOS 17, Observation `@Bindable`), StringTheoryCore (Swift Testing), app tests (XCTest/XCUITest). Build/test via the xclaude `xcode_build` / `xcode_test` MCP tools, falling back to raw `xcodebuild`; core via `swift test`.

**Delivery context:** Final increment (4 of 4) from `docs/superpowers/specs/2026-06-17-stages-2-5-content-design.md` (Tabs, Scales, Improvisation shipped). After this, all five stages are real content. The spec calls Chords the heaviest increment: guitar diagrams, the chord-tone factor-out, the Chord Library handoff, and a separate bass arpeggio track.

**Conventions (from CLAUDE.md):**
- New app source files require editing the committed `StringTheory.xcodeproj`. All new app types go in EXISTING files (`AppModel.swift`, `LessonView.swift`). New core files are fine (the package globs sources), but this plan adds core code to the existing `Chord.swift` to keep chord code together. Do NOT run `xcodegen generate`.
- The Chord Library is always guitar voicings, even on bass (locked decision). The guitar `.chords` lessons render a 6-string guitar neck for the same reason; the bass track uses `.arpeggio` instead, so `.chords` never renders on a bass tuning.
- Prose/comments: no em dashes, plain wording, no AI-slop filler.
- Run the app, do not just build it (the audio-thread trap is runtime-only).
- Commit messages end with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Editor SourceKit diagnostics ("No such module 'StringTheoryCore'", "cannot find type", "'main' attribute...") are cross-file index lag; trust `xcode_build` / `xcode_test` / `swift test`, not the editor.

**Build/test commands (allow Bash timeout 600000 for raw xcodebuild):**
- Prefer MCP: `xcode_test` / `xcode_build` with `scheme: StringTheory`, `project_path: /Users/javierorraca/Documents/GitHub/string-theory/StringTheory.xcodeproj`, `destination: platform=iOS Simulator,name=iPhone 17 Pro`, `only_testing` as an array.
- Core tests (fast, run from repo root): `swift test --package-path StringTheoryCore` (one suite: `--filter ChordTests`).
- Raw fallback app tests: `xcodebuild test -project StringTheory.xcodeproj -scheme StringTheory -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:<...>`

**Note on line numbers:** taken from the post-Improvisation `main` (HEAD `11093ab`). They may drift as earlier tasks edit the same files. Match by the code content shown, not the line number.

---

## File structure

- `StringTheoryCore/Sources/StringTheoryCore/Music/Chord.swift` (modify): add `chordTones(root:isMinor:) -> [Note]` and `arpeggioMarkers(instrument:root:isMinor:frets:startFret:) -> [Marker]`.
- `StringTheoryCore/Tests/StringTheoryCoreTests/ChordTests.swift` (modify, or create if absent): tests for both.
- `App/StringTheory/Audio/SynthAudioEngine.swift` (modify): use `chordTones` in `playBacking` instead of inline root/third/fifth math.
- `App/StringTheory/AppModel.swift` (modify): add `.chords([String])` and `.arpeggio(root:isMinor:)` to `LessonKind`; replace the `chords` stub with `chords(for: instrument)` and call it in `stages(for:)`.
- `App/StringTheory/Features/Lesson/LessonView.swift` (modify): content switch gains `.chords` and `.arpeggio`; footer routes them through the forward-button-only bar; add `ChordsLessonView` and `ArpeggioLessonView`.
- `App/StringTheory/StringTheoryApp.swift` (modify): add `-uitest-unlock-chords` (pre-completes stages 1-2) to the unlock seam.
- `App/StringTheoryTests/AppModelTests.swift` (modify): guitar and bass stage-3 curriculum shape and handoff.
- `App/StringTheoryUITests/OnboardingUITests.swift` (modify): a guitar Chords stage flow test ending in the Chord Library handoff.
- `CLAUDE.md` (modify): describe `.chords`, `.arpeggio`, the instrument-divergent stage 3, and the new core functions.

---

## Task 1: Core `chordTones` and `arpeggioMarkers` (TDD), and the playBacking factor-out

**Files:**
- Modify: `StringTheoryCore/Sources/StringTheoryCore/Music/Chord.swift`
- Test: `StringTheoryCore/Tests/StringTheoryCoreTests/ChordTests.swift`
- Modify: `App/StringTheory/Audio/SynthAudioEngine.swift`

- [ ] **Step 1: Write the failing tests**

Open `StringTheoryCore/Tests/StringTheoryCoreTests/ChordTests.swift` (it already tests `chordMarkers`). Match its existing Swift Testing structure (`@Suite` / `@Test` / `#expect`). Add:

```swift
    @Test func chordTonesMajorAndMinor() {
        #expect(chordTones(root: .c, isMinor: false) == [.c, .e, .g])
        #expect(chordTones(root: .a, isMinor: true) == [.a, .c, .e])
        #expect(chordTones(root: .g, isMinor: false) == [.g, .b, .d])
    }

    @Test func arpeggioMarkersLabelRootThirdFifth() {
        let markers = arpeggioMarkers(instrument: .bass, root: .c, isMinor: false, frets: 12)
        #expect(!markers.isEmpty)
        // Every marker sounds one of the three chord tones.
        let tones: Set<Note> = [.c, .e, .g]
        #expect(markers.allSatisfy { ($0.note.map(tones.contains)) ?? false })
        // Roots glow (kind .root), are the C, and are labelled "R".
        let roots = markers.filter { $0.kind == .root }
        #expect(!roots.isEmpty)
        #expect(roots.allSatisfy { $0.note == .c && $0.label == "R" })
        // The C on the bass A string (string index 1, fret 3) is a labelled root.
        #expect(markers.contains { $0.string == 1 && $0.fret == 3 && $0.kind == .root && $0.label == "R" })
        // Third and fifth are present and labelled.
        #expect(markers.contains { $0.note == .e && $0.kind == .safe && $0.label == "3" })
        #expect(markers.contains { $0.note == .g && $0.kind == .safe && $0.label == "5" })
    }
```

(If `ChordTests.swift` does not exist, create it with the standard header used by the other core test files: `import Testing`, `@testable import StringTheoryCore`, and a `@Suite struct ChordTests { ... }` wrapping the two tests.)

- [ ] **Step 2: Run and confirm failure**

Run: `swift test --package-path StringTheoryCore --filter ChordTests`
Expected: compile failure ("cannot find 'chordTones'" / "cannot find 'arpeggioMarkers' in scope").

- [ ] **Step 3: Implement both functions**

In `Chord.swift`, after `chordSpan(_:)` (the end of the file), add:

```swift
// MARK: - Chord tones and arpeggio markers

/// The root, third, and fifth of a triad. The third is minor (3 semitones above
/// the root) or major (4); the fifth is perfect (7). This is the chord-tone math
/// the backing voices and the bass arpeggio lessons share.
public func chordTones(root: Note, isMinor: Bool) -> [Note] {
    [root, noteAt(open: root, fret: isMinor ? 3 : 4), noteAt(open: root, fret: 7)]
}

/// Markers for the root, third, and fifth of a triad across
/// `startFret ... startFret + frets` on `instrument`. The root is `.root` and
/// labelled "R"; the third and fifth are `.safe`, labelled "3" and "5". Mirrors
/// the shape of `scaleMarkers`.
public func arpeggioMarkers(
    instrument: Instrument,
    root: Note,
    isMinor: Bool,
    frets: Int = 12,
    startFret: Int = 0
) -> [Marker] {
    let tuning = Tuning.standard(for: instrument)
    let tones = chordTones(root: root, isMinor: isMinor)   // [root, third, fifth]
    let labels = ["R", "3", "5"]
    var out: [Marker] = []
    for (stringIndex, openString) in tuning.strings.enumerated() {
        for fret in startFret...(startFret + frets) {
            let note = noteAt(open: openString.note, fret: fret)
            guard let toneIndex = tones.firstIndex(of: note) else { continue }
            out.append(Marker(
                string: stringIndex,
                fret: fret,
                kind: toneIndex == 0 ? .root : .safe,
                note: note,
                label: labels[toneIndex]
            ))
        }
    }
    return out
}
```

- [ ] **Step 4: Run the core tests and confirm green**

Run: `swift test --package-path StringTheoryCore --filter ChordTests` -> PASS.
Then `swift test --package-path StringTheoryCore` -> all pass (nothing else affected).

- [ ] **Step 5: Use `chordTones` in the audio engine**

In `App/StringTheory/Audio/SynthAudioEngine.swift`, inside `playBacking`, replace:

```swift
                let thirdSemis = chord.isMinor ? 3 : 4
                let root = chord.root.frequency(octave: 3)
                let third = noteAt(open: chord.root, fret: thirdSemis).frequency(octave: 3)
                let fifth = noteAt(open: chord.root, fret: 7).frequency(octave: 3)
```
with:
```swift
                let tones = chordTones(root: chord.root, isMinor: chord.isMinor)
                let root = tones[0].frequency(octave: 3)
                let third = tones[1].frequency(octave: 3)
                let fifth = tones[2].frequency(octave: 3)
```
(Same values, now shared with the lessons. `chordTones` is in `StringTheoryCore`, already imported here.)

- [ ] **Step 6: Build the app to confirm the refactor compiles**

Run: `xcode_build` (scheme StringTheory) -> Build succeeded. (The backing loop's audio is unchanged; the Improvisation UI test exercises it later in the full suite.)

- [ ] **Step 7: Commit**

```bash
git add StringTheoryCore/Sources/StringTheoryCore/Music/Chord.swift StringTheoryCore/Tests/StringTheoryCoreTests/ChordTests.swift App/StringTheory/Audio/SynthAudioEngine.swift
git commit -m "$(cat <<'EOF'
feat: core chordTones and arpeggioMarkers

Factors the root/third/fifth math out of SynthAudioEngine.playBacking into
a core chordTones(root:isMinor:), and adds arpeggioMarkers that places a
chord's tones across the neck (root cyan, labelled R/3/5) for the bass
arpeggio lessons.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add the `.chords` and `.arpeggio` lesson kinds and their renderers

Capability only; no new lessons yet (stage 3 content lands in Task 3). Both `switch lesson.kind` statements must stay exhaustive, so the cases and the renderers go in together. Verification is a green build plus the existing suite.

**Files:**
- Modify: `App/StringTheory/AppModel.swift` (`LessonKind`)
- Modify: `App/StringTheory/Features/Lesson/LessonView.swift` (content switch, footer, two new renderers)

- [ ] **Step 1: Add the two cases to `LessonKind`**

In `AppModel.swift`, change:

```swift
/// What a lesson presents. `tab` plays any riff on the learner's own tuning;
/// `reading` is a short text lesson (used as real per-stage content lands);
/// `scale` shows a scale on the neck, tap-to-hear, with `showDegrees` choosing
/// whether each tone is labelled with its degree or left as a plain dot;
/// `backing` is the Solo screen's neck driven by the backing loop, tap-to-hear.
enum LessonKind: Hashable {
    case tab(Riff)
    case reading(String)
    case explore(ExploreLesson)
    case scale(key: Note, type: ScaleType, showDegrees: Bool)
    case backing(key: Note, type: ScaleType)
}
```
to:
```swift
/// What a lesson presents. `tab` plays any riff on the learner's own tuning;
/// `reading` is a short text lesson (used as real per-stage content lands);
/// `scale` shows a scale on the neck, tap-to-hear, with `showDegrees` choosing
/// whether each tone is labelled with its degree or left as a plain dot;
/// `backing` is the Solo screen's neck driven by the backing loop, tap-to-hear;
/// `chords` shows one or more guitar chord diagrams (stepped) tap-to-hear;
/// `arpeggio` shows a chord's root/third/fifth across the neck, tap-to-hear.
enum LessonKind: Hashable {
    case tab(Riff)
    case reading(String)
    case explore(ExploreLesson)
    case scale(key: Note, type: ScaleType, showDegrees: Bool)
    case backing(key: Note, type: ScaleType)
    case chords([String])
    case arpeggio(root: Note, isMinor: Bool)
}
```

- [ ] **Step 2: Add the content-switch cases**

In `LessonView.swift`, the content switch currently reads:

```swift
            switch lesson.kind {
            case .tab(let riff):
                TabLessonView(riff: riff)
            case .explore(let exercise):
                ExploreLessonView(exercise: exercise)
            case .scale(let key, let type, let showDegrees):
                ScaleLessonView(key: key, type: type, showDegrees: showDegrees)
            case .backing(let key, let type):
                BackingLessonView(key: key, type: type)
            case .reading(let body):
                Text(body)
                    .font(Typography.body(15))
                    .foregroundStyle(Theme.Palette.text)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
```
Add the two cases (before `.reading`):
```swift
            case .chords(let ids):
                ChordsLessonView(chordIDs: ids)
            case .arpeggio(let root, let isMinor):
                ArpeggioLessonView(root: root, isMinor: isMinor)
```

- [ ] **Step 3: Route the footer**

In `LessonView.swift`, the footer switch ends with:

```swift
        case .reading, .explore, .scale:
            bottomBar { forwardButton }
        }
    }
```
Both new kinds are tap-to-hear with no transport, so add them to that case:
```swift
        case .reading, .explore, .scale, .chords, .arpeggio:
            bottomBar { forwardButton }
        }
    }
```

- [ ] **Step 4: Add `ChordsLessonView`**

In `LessonView.swift`, at the end of the file, add:

```swift
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
                        Button {
                            index = i
                            model.chordID = id
                        } label: {
                            Text(Chord.named(id)?.name ?? id)
                                .font(Typography.display(15, weight: .semibold))
                                .foregroundStyle(isActive ? Theme.Palette.phosphor : Theme.Palette.textDim)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(RoundedRectangle(cornerRadius: 9).fill(isActive ? Theme.Palette.phosphor.opacity(0.16) : Color(oklchL: 0.2, c: 0.018, h: 250)))
                                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(isActive ? Theme.Palette.phosphor : Theme.Palette.hairline, lineWidth: 1))
                        }
                        .accessibilityLabel("Show \(Chord.named(id)?.name ?? id)")
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
        .onAppear { model.chordID = chordIDs[0] }
    }
}
```

Note on tap-to-hear: `model.playNote(string:fret:)` sounds on the current instrument's tuning. `.chords` lessons exist only on the guitar track, so the instrument is guitar and the played pitch matches the rendered guitar voicing.

- [ ] **Step 5: Add `ArpeggioLessonView`**

In `LessonView.swift`, after `ChordsLessonView`, add:

```swift
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
```

- [ ] **Step 6: Build and confirm the suite stays green**

- `xcode_build` (scheme StringTheory) -> Build succeeded.
- `xcode_test` `only_testing: ["StringTheoryTests/AppModelTests"]` -> PASS.
- `xcode_test` `only_testing: ["StringTheoryUITests/OnboardingUITests/testScalesStageFlow"]` -> PASS (the footer change must not break other lessons).

- [ ] **Step 7: Commit**

```bash
git add App/StringTheory/AppModel.swift App/StringTheory/Features/Lesson/LessonView.swift
git commit -m "$(cat <<'EOF'
feat: add .chords and .arpeggio lesson kinds

A .chords lesson steps through guitar chord diagrams (core chordMarkers,
tap-to-hear) and mirrors the shown chord into model.chordID for the Chord
Library handoff. A .arpeggio lesson shows a chord's root/third/fifth on
the bass neck via arpeggioMarkers, tap-to-hear.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Author the stage 3 Chords curriculum (instrument-divergent)

**Files:**
- Modify: `App/StringTheory/AppModel.swift` (replace the `chords` stub with `chords(for:)`, update `stages(for:)`)
- Test: `App/StringTheoryTests/AppModelTests.swift`

- [ ] **Step 1: Write the failing tests**

In `AppModelTests.swift`, add inside the class:

```swift
    func testStageThreeGuitarHasFiveChordLessons() {
        let stage = LearningPath.stages(for: .guitar)[2]
        XCTAssertEqual(stage.id, 3)
        XCTAssertEqual(stage.lessons.count, 5)
        for lesson in stage.lessons {
            if case .chords = lesson.kind { } else {
                XCTFail("guitar stage 3 lesson \(lesson.id) should be a .chords lesson")
            }
        }
    }

    func testStageThreeGuitarLastLessonHandsOffToChordLibrary() {
        let last = LearningPath.stages(for: .guitar)[2].lessons[4]
        XCTAssertEqual(last.handoff, .chords)
    }

    func testStageThreeBassHasFiveArpeggioLessonsWithNoHandoff() {
        let stage = LearningPath.stages(for: .bass)[2]
        XCTAssertEqual(stage.id, 3)
        XCTAssertEqual(stage.lessons.count, 5)
        for lesson in stage.lessons {
            if case .arpeggio = lesson.kind { } else {
                XCTFail("bass stage 3 lesson \(lesson.id) should be a .arpeggio lesson")
            }
            XCTAssertNil(lesson.handoff, "bass has no Chord Library, so no handoff")
        }
    }
```

- [ ] **Step 2: Run and confirm failure**

Run: `xcode_test` `only_testing: ["StringTheoryTests/AppModelTests/testStageThreeGuitarHasFiveChordLessons"]`
Expected: FAIL (the stub has one `.tab(.drift)` lesson).

- [ ] **Step 3: Make the Chords stage instrument-aware**

In `AppModel.swift`, change `stages(for:)`:

```swift
    static func stages(for instrument: Instrument) -> [LearningStage] {
        [fretboardBasics, tabs(for: instrument), chords, scalesAndKeys, improvisation]
    }
```
to:
```swift
    static func stages(for instrument: Instrument) -> [LearningStage] {
        [fretboardBasics, tabs(for: instrument), chords(for: instrument), scalesAndKeys, improvisation]
    }
```

Then replace the `chords` stub:

```swift
    private static let chords = LearningStage(
        id: 3, number: "03", title: "Chords",
        subtitle: "Shapes & diagrams tied back to the notes you know",
        lessons: [Lesson(id: 1, title: "Chords",
                         subtitle: "Watch the neck as the riff plays.", kind: .tab(.drift))])
```
with:
```swift
    private static func chords(for instrument: Instrument) -> LearningStage {
        let lessons: [Lesson]
        switch instrument {
        case .guitar:
            lessons = [
                Lesson(id: 1, title: "Reading a chord diagram",
                       subtitle: "A chord diagram is the neck seen head on. A ring is an open string, an x is a string you do not play, and a dot is a finger. This is E major. Tap a dot to hear its note.",
                       kind: .chords(["E"])),
                Lesson(id: 2, title: "E and Em",
                       subtitle: "Lift one finger off E and it becomes E minor. Step between them and listen to the third drop.",
                       kind: .chords(["E", "Em"])),
                Lesson(id: 3, title: "A and Am",
                       subtitle: "The A shape, major and minor. The lowered third is again what turns major into minor.",
                       kind: .chords(["A", "Am"])),
                Lesson(id: 4, title: "D and Dm",
                       subtitle: "The D shape. Three strings carry the chord and the low two stay muted.",
                       kind: .chords(["D", "Dm"])),
                Lesson(id: 5, title: "G and C",
                       subtitle: "Two open staples. When you are ready, open the Chord Library to explore every shape, including F and Bm.",
                       kind: .chords(["G", "C"]),
                       handoff: .chords),
            ]
        case .bass:
            lessons = [
                Lesson(id: 1, title: "Play the root",
                       subtitle: "On bass you anchor a chord by playing its root. This is C, lit cyan everywhere it sits on the neck. Tap a cyan note to hear the root.",
                       kind: .arpeggio(root: .c, isMinor: false)),
                Lesson(id: 2, title: "Find every root",
                       subtitle: "Move to G. The same root repeats up the neck and across strings. Find each cyan G and tap it.",
                       kind: .arpeggio(root: .g, isMinor: false)),
                Lesson(id: 3, title: "Root and fifth",
                       subtitle: "Root to fifth is the classic bass move. Play the cyan root, then the note marked 5, and back.",
                       kind: .arpeggio(root: .c, isMinor: false)),
                Lesson(id: 4, title: "Add the third",
                       subtitle: "The third spells the rest of the chord. This is A minor, and the note marked 3 is the flattened third that makes it minor. Walk root, 3, 5.",
                       kind: .arpeggio(root: .a, isMinor: true)),
                Lesson(id: 5, title: "Walk a I-IV-V",
                       subtitle: "In C the I, IV, and V roots are C, F, and G. Move between those roots to outline a progression. There is no Chord Library on bass, so this is your sandbox.",
                       kind: .arpeggio(root: .c, isMinor: false)),
            ]
        }
        return LearningStage(
            id: 3, number: "03", title: "Chords",
            subtitle: "Chord shapes on guitar, root and arpeggio moves on bass",
            lessons: lessons)
    }
```

- [ ] **Step 4: Run the suite and confirm green**

Run: `xcode_test` `only_testing: ["StringTheoryTests/AppModelTests"]` -> PASS (the three new tests plus the rest, including `testCompletingStagesOneAndTwoUnlocksThree`, which still holds: completing stages 1-2 leaves the now-five-lesson stage 3 active, and `testCompletingEveryStageReachesFullProgress`, which already runs both instruments).

- [ ] **Step 5: Commit**

```bash
git add App/StringTheory/AppModel.swift App/StringTheoryTests/AppModelTests.swift
git commit -m "$(cat <<'EOF'
feat: real stage 3 Chords curriculum, instrument-divergent

Guitar gets five chord-diagram lessons (reading a diagram, E/Em, A/Am,
D/Dm, G/C) ending in a handoff to the Chord Library. Bass gets five
root-and-arpeggio lessons (root, find roots, root-fifth, the third,
walk a I-IV-V) and ends in place, since the Chord Library is guitar only.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Test seam plus a guitar Chords stage UI flow test

Reaching stage 3 in the UI means completing stages 1-2 first. Add a `-uitest-unlock-chords` seam (pre-completes stages 1-2 so stage 3 is active), then a UI test that walks the guitar Chords lessons and confirms the handoff opens the Chord Library.

**Files:**
- Modify: `App/StringTheory/StringTheoryApp.swift`
- Modify: `App/StringTheoryUITests/OnboardingUITests.swift`

- [ ] **Step 1: Extend the unlock seam**

In `StringTheoryApp.swift`, the `unlockBelow` ladder currently reads:

```swift
            // Pre-complete earlier stages so a test can land on a later one:
            // -uitest-unlock-scales reaches stage 4, -uitest-unlock-improv reaches stage 5.
            // If both flags are present, the higher unlock (improv) wins.
            let unlockBelow = args.contains("-uitest-unlock-improv") ? 5
                            : args.contains("-uitest-unlock-scales") ? 4
                            : 0
```
Change it to add the chords rung:
```swift
            // Pre-complete earlier stages so a test can land on a later one:
            // -uitest-unlock-chords reaches stage 3, -uitest-unlock-scales reaches
            // stage 4, -uitest-unlock-improv reaches stage 5. If more than one is
            // present, the higher unlock wins.
            let unlockBelow = args.contains("-uitest-unlock-improv") ? 5
                            : args.contains("-uitest-unlock-scales") ? 4
                            : args.contains("-uitest-unlock-chords") ? 3
                            : 0
```

- [ ] **Step 2: Write the UI test**

In `OnboardingUITests.swift`, add inside the class. Note: the Chords stage card title is "Chords", which also labels the Chords tab-bar button, so this test taps the stage card by its accessibility label (a `NavigationLink` labelled "Stage 03: Chords. ...") via a `BEGINSWITH` predicate, rather than `staticTexts["Chords"]`.

```swift
    /// With stages 1-2 pre-completed, walks the five guitar Chords lessons,
    /// steps a chord diagram, and confirms the final handoff opens the Chord
    /// Library tab. Exercises ChordsLessonView at runtime.
    @MainActor
    func testChordsStageFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-unlock-chords"]
        app.launch()

        // Onboarding (default instrument is guitar).
        XCTAssertTrue(app.staticTexts["Pick your instrument"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Which hand frets?"].waitForExistence(timeout: 3))
        app.buttons["Enter the path"].tap()

        // Stage 3 is active because 1-2 are pre-completed. The card title "Chords"
        // collides with the tab button, so tap the stage card by its a11y label.
        XCTAssertTrue(app.staticTexts["Your Path"].waitForExistence(timeout: 3))
        let chordsStage = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Stage 03: Chords")).firstMatch
        XCTAssertTrue(chordsStage.waitForExistence(timeout: 3))
        chordsStage.tap()

        // Walk the five lessons.
        XCTAssertTrue(app.staticTexts["Reading a chord diagram"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["E and Em"].waitForExistence(timeout: 3))
        // Step the diagram from E to Em.
        app.buttons["Show Em"].tap()
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["A and Am"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["D and Dm"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()

        // Last lesson hands off to the Chord Library.
        XCTAssertTrue(app.staticTexts["G and C"].waitForExistence(timeout: 3))
        app.buttons["Open the Chord Library"].tap()

        // The handoff dismissed the lesson and switched to the Chords tab.
        let chordsTab = app.tabBars.buttons["Chords"]
        XCTAssertTrue(chordsTab.waitForExistence(timeout: 3))
        XCTAssertTrue(chordsTab.isSelected)
    }
```

- [ ] **Step 3: Run the test**

Run: `xcode_test` `only_testing: ["StringTheoryUITests/OnboardingUITests/testChordsStageFlow"]`
Expected: PASS.

If the stage-card predicate does not resolve (for example the accessibility label wording differs from "Stage 03: Chords ..."), inspect `HomeView.StageRow` to confirm the active card's `accessibilityLabel`, and adjust the predicate string to match. Do NOT change app source to make the test pass; if the seam or the handoff has a real bug, STOP and report BLOCKED with the failure. Only adjust the element query for a genuine selector issue, and report what you changed.

- [ ] **Step 4: Commit**

```bash
git add App/StringTheory/StringTheoryApp.swift App/StringTheoryUITests/OnboardingUITests.swift
git commit -m "$(cat <<'EOF'
test: UI flow through the guitar Chords stage and Library handoff

Adds a -uitest-unlock-chords seam (pre-completes stages 1-2) and a test
that walks the five guitar Chords lessons, steps a diagram, and confirms
the final handoff opens the Chord Library tab.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Update CLAUDE.md and run the app

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update the learning-path bullet**

In `CLAUDE.md`, READ the bullet that begins "**Learning path is data-driven.**". Make these plain edits:
1. Add `.chords([String])` and `.arpeggio(root:isMinor:)` to the list of `LessonKind` variants: `.chords` shows one or more guitar chord diagrams (rings/x/note-labels via the core `chordMarkers`), steps between them, tap-to-hear, and mirrors the shown chord into `AppModel.chordID` for the Chord Library handoff; `.arpeggio` shows a chord's root/third/fifth across the bass neck via the core `arpeggioMarkers`, tap-to-hear.
2. Update the stage-status sentence: stage 3 (Chords) is now a real five-lesson curriculum that, like stage 2 (Tabs), differs by instrument: guitar gets chord-diagram lessons handing off to the Chord Library, bass gets a root-and-arpeggio track that ends in place. All five stages are now real content; there are no remaining `.tab(.drift)` stubs.
3. In the Architecture section's core description, note the new core helpers if natural: `chordTones(root:isMinor:)` (shared by the backing voices and the arpeggio lessons) and `arpeggioMarkers(...)`.

Keep it to a few plain sentences, no em dashes. Also confirm the "stage 2 (and later stage 3) differ for guitar and bass" phrasing reads correctly now that stage 3 is done (drop "and later" so it states both differ).

- [ ] **Step 2: Commit the doc**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs: describe .chords and .arpeggio lessons in CLAUDE.md

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Build, launch, and exercise the app**

Build and launch on the simulator. Then:
1. Guitar: complete stages 1-2 (or use the seam), open Chords. Confirm lesson 1 shows the E diagram with rings/x/labelled dots, and tapping a dot plays a note. Step to "E and Em" and confirm the diagram switches when you tap the chord-name buttons and the third changes.
2. On the last guitar lesson, press "Open the Chord Library" and confirm the app switches to the Chords tab showing the chord you last viewed.
3. Bass: switch to Bass in Settings (or onboard as bass), open Chords. Confirm the bass neck shows the root in cyan with 3 and 5 labelled, and tapping plays a note. Step through the five arpeggio lessons; confirm lesson 4 (A minor) shows the flat third, and the last lesson does not show a Chord Library handoff button (it shows Finish).

Expected: no crashes, audio plays, the guitar handoff switches tabs, and the bass arpeggio renders on four strings. (Per the project rule, this catches runtime-only issues that builds do not surface.)

- [ ] **Step 4: Run the full suites once more**

Run `xcode_test` (whole `StringTheory` scheme, no filter) and `swift test --package-path StringTheoryCore`.
Expected: all pass.

---

## Self-review notes

- **Spec coverage (Chords increment):** guitar `.chords` lessons matching the spec table (reading a diagram, E/Em, A/Am, D/Dm, G/C with the Chord Library handoff) and bass `.arpeggio` lessons (root, find roots, root-fifth, the third for major/minor, walk a I-IV-V, ending in place) (Task 3). The `chordTones` factor-out and `arpeggioMarkers`, both in core with tests (Task 1). The Chord Library handoff reuses the `selectedTab` machinery; `handoffLabel(.chords)` already returns "Open the Chord Library". F and Bm are not taught as lessons; they remain in the Chord Library, as the spec requires.
- **chordMarkers already existed** in core (the spec anticipated factoring it out, but the port already had it), so this increment only adds `chordTones` and `arpeggioMarkers`.
- **Instrument divergence** mirrors the Tabs stage: `chords(for: instrument)` with separate tracks, one stage id (3), one title. The Chord Library stays guitar-only on bass (locked decision); the bass track therefore ends in place with no handoff.
- **Handoff state:** `ChordsLessonView` owns `model.chordID` (sets it on appear and on each step), so the Chord Library opens on the chord last viewed; `handoff(to:)` needs no `.chords` branch. This matches how `BackingLessonView` seeds `soloKey`/`soloScale`.
- **Switch exhaustiveness:** both `switch lesson.kind` statements gain `.chords` and `.arpeggio` (Task 2); the footer groups them with the other tap-to-hear kinds. No `default:` escape hatch, so a future kind fails to compile until handled.
- **Type consistency:** `LessonKind.chords([String])`, `LessonKind.arpeggio(root:isMinor:)`, `ChordsLessonView(chordIDs:)`, `ArpeggioLessonView(root:isMinor:)`, `chordTones(root:isMinor:)`, `arpeggioMarkers(instrument:root:isMinor:frets:startFret:)`, `Chord.named(_:)`, `chordMarkers(_:)`, and `model.chordID` are used with the same names and signatures across tasks and match the existing core and `ChordLibraryView` definitions. Lesson titles in the UI test ("Reading a chord diagram", "E and Em", "A and Am", "D and Dm", "G and C") and the picker button label ("Show Em") match Task 2 and Task 3 exactly.
- **UI test robustness:** the Chords stage card is tapped by its `BEGINSWITH "Stage 03: Chords"` accessibility label (a `NavigationLink` button), avoiding the collision with the "Chords" tab-bar button; the end state asserts `tabBars.buttons["Chords"].isSelected`, the robust signal used by the other stage-flow tests. The bass arpeggio renderer is exercised by the live run in Task 5 (a bass UI flow would require selecting bass in onboarding; the bass track shape is pinned by `AppModelTests` instead).
