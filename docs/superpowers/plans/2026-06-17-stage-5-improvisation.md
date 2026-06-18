# Stage 5 Improvisation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stage 5 (Improvisation) stub with a real five-lesson, instrument-aware curriculum that teaches soloing over the backing loop and hands off to Solo Practice.

**Architecture:** Add one `LessonKind` case, `.backing(key:type:)`, rendered by a `BackingLessonView` that reuses the single `FretboardView` with the same safe-note markers the Solo screen draws (`scaleMarkers`, with the active chord's root pulsing as the backing loop plays), is tap-to-hear, and carries a Play/Stop backing transport. Lesson 1 reuses the existing `.scale` kind (a static safe-note neck). The backing engine (`AppModel.toggleBacking`, `backingChordIndex`, `activeBackingRoot`), the `backingProgression` core function, and the `selectedTab` tool-handoff are all already built; this increment wires them into lessons.

**Tech Stack:** Swift 6, SwiftUI (iOS 17, Observation `@Bindable`), StringTheoryCore (Swift Testing), app tests (XCTest/XCUITest). Build/test via the xclaude `xcode_build` / `xcode_test` MCP tools, falling back to raw `xcodebuild`.

**Delivery context:** Increment 3 of 4 from `docs/superpowers/specs/2026-06-17-stages-2-5-content-design.md` (Tabs and Scales shipped; this is Improvisation; then Chords). After this plan, stage 3 (Chords) is still the single `.tab(.drift)` stub. No core code changes: `backingProgression`, `scaleMarkers`, and the backing audio engine already exist.

**Conventions (from CLAUDE.md):**
- New app source files require editing the committed `StringTheory.xcodeproj`. All new app types go in EXISTING files (`AppModel.swift`, `LessonView.swift`). No new files are needed.
- Do NOT run `xcodegen generate`.
- Prose and comments: no em dashes, plain wording, no AI-slop filler.
- Run the app, do not just build it (the audio-thread trap is runtime-only).
- Commit messages end with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Editor SourceKit "No such module 'StringTheoryCore'" / "cannot find type" / "'main' attribute" diagnostics are cross-file index lag; trust `xcode_build` / `xcode_test` (or `xcodebuild` / `swift test`), not the editor.

**Build/test commands (allow Bash timeout 600000 for raw xcodebuild):**
- Prefer MCP: `xcode_test` / `xcode_build` with `scheme: StringTheory`, `project_path: StringTheory.xcodeproj`, `destination: platform=iOS Simulator,name=iPhone 17 Pro`, and `only_testing` as noted per step.
- Raw fallback app tests: `xcodebuild test -project StringTheory.xcodeproj -scheme StringTheory -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:<...>`
- Raw fallback app build: `xcodebuild build -project StringTheory.xcodeproj -scheme StringTheory -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Core tests (no change expected, run once at the end): `swift test --package-path StringTheoryCore`

**Note on line numbers:** line numbers below were taken from the post-Scales state of `main` (HEAD `6818325`). They may drift a few lines as earlier tasks in THIS plan edit the same files. Match by the code content shown, not the line number.

---

## File structure

- `App/StringTheory/AppModel.swift` (modify): add `.backing(key:type:)` to `LessonKind`; change `private func stopBacking()` to internal `func stopBacking()` so a lesson can stop the loop on exit; replace the `improvisation` stub with five lessons.
- `App/StringTheory/Features/Lesson/LessonView.swift` (modify): content switch gets a `.backing` case; footer gets a `.backing` transport (Play/Stop backing + forward button); the lesson lifecycle stops the backing loop alongside the riff; `handoff(to:)` pre-selects the solo key/scale for a `.backing` lesson; add `BackingLessonView`.
- `App/StringTheory/StringTheoryApp.swift` (modify): generalize the UI-test unlock seam so `-uitest-unlock-improv` pre-completes stages 1-4 (keeping `-uitest-unlock-scales` working).
- `App/StringTheoryTests/AppModelTests.swift` (modify): stage 5 curriculum shape, the Solo handoff, and full-path completion.
- `App/StringTheoryUITests/OnboardingUITests.swift` (modify): an Improvisation stage flow test that plays the backing loop and ends by handing off to the Solo tab.
- `CLAUDE.md` (modify): note `.backing`, stage 5 being real, and the Solo handoff.

---

## Task 1: Add the `.backing` lesson kind, its renderer, transport, and lifecycle

This lands the capability with no new lessons yet. Both `switch lesson.kind` statements must stay exhaustive, so the case and the renderer go in together. Verification is a green build plus the existing suite, since no lesson uses `.backing` yet and nothing else changes behavior.

**Files:**
- Modify: `App/StringTheory/AppModel.swift` (`LessonKind`, the `stopBacking` visibility)
- Modify: `App/StringTheory/Features/Lesson/LessonView.swift` (content switch, footer, lifecycle, `handoff`, new `BackingLessonView`)

- [ ] **Step 1: Add the `.backing` case to `LessonKind`**

In `AppModel.swift`, change:

```swift
/// What a lesson presents. `tab` plays any riff on the learner's own tuning;
/// `reading` is a short text lesson (used as real per-stage content lands);
/// `scale` shows a scale on the neck, tap-to-hear, with `showDegrees` choosing
/// whether each tone is labelled with its degree or left as a plain dot.
enum LessonKind: Hashable {
    case tab(Riff)
    case reading(String)
    case explore(ExploreLesson)
    case scale(key: Note, type: ScaleType, showDegrees: Bool)
}
```
to:
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

- [ ] **Step 2: Make `stopBacking()` callable from the lesson**

In `AppModel.swift`, find:

```swift
    private func stopBacking() {
        audio.stopBacking()
        isPlayingBacking = false
        backingChordIndex = nil
    }
```
and remove `private` so the lesson view can stop the loop when it leaves:
```swift
    /// Stops the backing loop. Public so a `.backing` lesson can stop it when the
    /// learner advances or leaves the stage, the way `stopRiff` works for tabs.
    func stopBacking() {
        audio.stopBacking()
        isPlayingBacking = false
        backingChordIndex = nil
    }
```

(`toggleBacking`, `setSoloKey`, and `setSoloScale` already call `stopBacking`; widening visibility does not change their behavior.)

- [ ] **Step 3: Add the `.backing` case to the content switch**

In `LessonView.swift`, the content switch currently reads:

```swift
            switch lesson.kind {
            case .tab(let riff):
                TabLessonView(riff: riff)
            case .explore(let exercise):
                ExploreLessonView(exercise: exercise)
            case .scale(let key, let type, let showDegrees):
                ScaleLessonView(key: key, type: type, showDegrees: showDegrees)
            case .reading(let body):
                Text(body)
                    .font(Typography.body(15))
                    .foregroundStyle(Theme.Palette.text)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
```
Add a `.backing` case:
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

- [ ] **Step 4: Add the `.backing` transport to the footer**

In `LessonView.swift`, the `footer` computed property switches on `lesson.kind`. It currently has a `.tab` case and a `case .reading, .explore, .scale:` case. Add a `.backing` case between them so the switch stays exhaustive. Change:

```swift
        case .reading, .explore, .scale:
            bottomBar { forwardButton }
        }
    }
```
to:
```swift
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
        case .reading, .explore, .scale:
            bottomBar { forwardButton }
        }
    }
```

- [ ] **Step 5: Stop the backing loop across the lesson lifecycle**

In `LessonView.swift`, the lesson player stops the riff in four places. Add a backing stop at each so a `.backing` lesson never keeps playing after the learner moves on.

5a. The `onChange` / `onDisappear` block currently reads:

```swift
        .onChange(of: lesson.id) { model.stopRiff() }
        .onChange(of: model.riffGoalReached) { _, reached in
            if reached, !lessonComplete {
                model.markLessonComplete(stageID: stage.id, lessonID: lesson.id)
                model.stopRiff()
            }
        }
        .onDisappear { model.stopRiff() }
```
Change the first and last lines to also stop backing:
```swift
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
```

5b. `advance()` currently reads:

```swift
    private func advance() {
        model.markLessonComplete(stageID: stage.id, lessonID: lesson.id)
        model.stopRiff()
        if isLastLesson { dismiss() } else { index += 1 }
    }
```
Change to:
```swift
    private func advance() {
        model.markLessonComplete(stageID: stage.id, lessonID: lesson.id)
        model.stopRiff()
        model.stopBacking()
        if isLastLesson { dismiss() } else { index += 1 }
    }
```

- [ ] **Step 6: Pre-select the solo key/scale on the Solo handoff**

In `LessonView.swift`, `handoff(to:)` currently reads:

```swift
    private func handoff(to tab: MainTab) {
        model.markLessonComplete(stageID: stage.id, lessonID: lesson.id)
        model.stopRiff()
        if case .scale(let key, let type, _) = lesson.kind {
            model.scaleKey = key
            model.scaleType = type
        }
        dismiss()
        model.selectedTab = tab
    }
```
Change to also stop backing and, for a `.backing` lesson, open Solo Practice on the key just practiced:
```swift
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
```

- [ ] **Step 7: Add `BackingLessonView`**

In `LessonView.swift`, at the end of the file (after `ScaleLessonView`), add the renderer. It mirrors the Solo screen: `scaleMarkers` for the safe notes, the active chord's root overlaid as `.active` while the loop plays, plus a compact backing-loop chord row. It sets the solo key/scale on appear so the shared backing engine and `activeBackingRoot` use this lesson's key, and it is tap-to-hear.

```swift
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
```

- [ ] **Step 8: Build and confirm the suite stays green**

Run (MCP `xcode_build`, or raw):
- Build: `xcodebuild build ...` -> Build succeeded.
- `xcode_test` `only_testing: ["StringTheoryTests/AppModelTests"]` -> PASS.
- `xcode_test` `only_testing: ["StringTheoryUITests/OnboardingUITests/testScalesStageFlow"]` -> PASS (confirms the footer and lifecycle changes did not break the existing handoff path).

- [ ] **Step 9: Commit**

```bash
git add App/StringTheory/AppModel.swift App/StringTheory/Features/Lesson/LessonView.swift
git commit -m "$(cat <<'EOF'
feat: add .backing lessons that solo over the loop

A .backing lesson renders the Solo screen's neck (safe notes, the active
chord root pulsing) with tap-to-hear and a Play/Stop backing transport.
The lesson lifecycle now stops the backing loop alongside the riff, and a
Solo handoff opens Solo Practice on the key just practiced.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Author the stage 5 Improvisation curriculum

**Files:**
- Modify: `App/StringTheory/AppModel.swift` (the `improvisation` definition)
- Test: `App/StringTheoryTests/AppModelTests.swift`

- [ ] **Step 1: Write the failing tests**

In `AppModelTests.swift`, add inside the class:

```swift
    func testStageFiveImprovCurriculum() {
        let stage = LearningPath.stages(for: .guitar)[4]
        XCTAssertEqual(stage.id, 5)
        XCTAssertEqual(stage.lessons.count, 5)
        // Lesson 1 reuses the static scale neck (safe notes); 2-5 drive the loop.
        if case .scale = stage.lessons[0].kind { } else {
            XCTFail("stage 5 lesson 1 should be a .scale lesson")
        }
        for lesson in stage.lessons.dropFirst() {
            if case .backing = lesson.kind { } else {
                XCTFail("stage 5 lesson \(lesson.id) should be a .backing lesson")
            }
        }
    }

    func testStageFiveLastLessonHandsOffToSolo() {
        let last = LearningPath.stages(for: .guitar)[4].lessons[4]
        XCTAssertEqual(last.handoff, .solo)
    }

    func testCompletingEveryStageReachesFullProgress() {
        let model = freshModel()
        for stage in model.stages {
            for lesson in stage.lessons {
                model.markLessonComplete(stageID: stage.id, lessonID: lesson.id)
            }
        }
        XCTAssertEqual(model.overallPercent, 100)
        XCTAssertEqual(model.status(for: model.stages[4]), .done)
    }
```

- [ ] **Step 2: Run and confirm failure**

Run: `xcode_test` `only_testing: ["StringTheoryTests/AppModelTests/testStageFiveImprovCurriculum"]`
Expected: FAIL (the stub has one `.tab(.drift)` lesson, so the count is 1 and lesson 1 is not `.scale`).

- [ ] **Step 3: Replace the `improvisation` stub**

In `AppModel.swift`, replace:

```swift
    private static let improvisation = LearningStage(
        id: 5, number: "05", title: "Improvisation",
        subtitle: "Solo over a backing track using only safe notes",
        lessons: [Lesson(id: 1, title: "Improvisation",
                         subtitle: "Watch the neck as the riff plays.", kind: .tab(.drift))])
```
with:
```swift
    private static let improvisation = LearningStage(
        id: 5, number: "05", title: "Improvisation",
        subtitle: "Solo over a backing track using only safe notes",
        lessons: [
            Lesson(id: 1, title: "Safe notes",
                   subtitle: "Stage 4's scale is now your safety net. Every lit note in A minor pentatonic fits this backing track. Tap any one to hear it.",
                   kind: .scale(key: .a, type: .minorPentatonic, showDegrees: true)),
            Lesson(id: 2, title: "Hear the backing",
                   subtitle: "Press Play backing. Four chords loop, the one playing now lights up, and its root pulses on the neck.",
                   kind: .backing(key: .a, type: .minorPentatonic)),
            Lesson(id: 3, title: "Target the root",
                   subtitle: "As each chord comes around, find its pulsing root and tap it. Landing on the root always sounds resolved.",
                   kind: .backing(key: .a, type: .minorPentatonic)),
            Lesson(id: 4, title: "Short phrases",
                   subtitle: "Play three or four safe notes, then leave space. Short phrases with rests say more than a long scramble.",
                   kind: .backing(key: .a, type: .minorPentatonic)),
            Lesson(id: 5, title: "Take a solo",
                   subtitle: "Press Play backing and improvise over a full loop using only safe notes. When you are ready, open Solo Practice to keep going.",
                   kind: .backing(key: .a, type: .minorPentatonic),
                   handoff: .solo),
        ])
```

- [ ] **Step 4: Run the suite and confirm green**

Run: `xcode_test` `only_testing: ["StringTheoryTests/AppModelTests"]` -> PASS (the three new tests plus the rest, including the existing `testCompletingStagesThroughFourUnlocksFive`, which still holds because completing stages 1-4 leaves the now-five-lesson stage 5 at 0% and therefore active).

- [ ] **Step 5: Commit**

```bash
git add App/StringTheory/AppModel.swift App/StringTheoryTests/AppModelTests.swift
git commit -m "$(cat <<'EOF'
feat: real stage 5 Improvisation curriculum

Five lessons: safe notes (static), hear the backing, target the root,
short phrases, and take a solo with a handoff into Solo Practice. Lessons
2-5 drive the backing loop on A minor pentatonic.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Test seam plus an Improvisation stage UI flow test

Reaching stage 5 in the UI means completing stages 1-4 first. Generalize the existing unlock seam, then add a UI test that walks the five Improvisation lessons, exercises the backing transport, and confirms the handoff lands on the Solo tab.

**Files:**
- Modify: `App/StringTheory/StringTheoryApp.swift`
- Modify: `App/StringTheoryUITests/OnboardingUITests.swift`

- [ ] **Step 1: Generalize the unlock seam**

In `StringTheoryApp.swift`, the `init()` currently reads:

```swift
    init() {
        let args = ProcessInfo.processInfo.arguments
        // UI tests pass -uitest-reset to start from a clean, not-yet-onboarded state.
        if args.contains("-uitest-reset") {
            let defaults = UserDefaults(suiteName: "uitest")!
            defaults.removePersistentDomain(forName: "uitest")
            let model = AppModel(defaults: defaults)
            // -uitest-unlock-scales pre-completes stages 1-3 so a test can reach stage 4.
            if args.contains("-uitest-unlock-scales") {
                for stage in LearningPath.stages(for: model.instrument) where stage.id < 4 {
                    for lesson in stage.lessons {
                        model.markLessonComplete(stageID: stage.id, lessonID: lesson.id)
                    }
                }
            }
            _model = State(initialValue: model)
        } else {
            _model = State(initialValue: AppModel())
        }
    }
```
Replace it with a version that also understands `-uitest-unlock-improv`:
```swift
    init() {
        let args = ProcessInfo.processInfo.arguments
        // UI tests pass -uitest-reset to start from a clean, not-yet-onboarded state.
        if args.contains("-uitest-reset") {
            let defaults = UserDefaults(suiteName: "uitest")!
            defaults.removePersistentDomain(forName: "uitest")
            let model = AppModel(defaults: defaults)
            // Pre-complete earlier stages so a test can land on a later one:
            // -uitest-unlock-scales reaches stage 4, -uitest-unlock-improv reaches stage 5.
            let unlockBelow = args.contains("-uitest-unlock-improv") ? 5
                            : args.contains("-uitest-unlock-scales") ? 4
                            : 0
            for stage in LearningPath.stages(for: model.instrument) where stage.id < unlockBelow {
                for lesson in stage.lessons {
                    model.markLessonComplete(stageID: stage.id, lessonID: lesson.id)
                }
            }
            _model = State(initialValue: model)
        } else {
            _model = State(initialValue: AppModel())
        }
    }
```

(The existing `testScalesStageFlow` keeps using `-uitest-unlock-scales`, which still maps to `unlockBelow = 4`.)

- [ ] **Step 2: Write the UI test**

In `OnboardingUITests.swift`, add inside the class:

```swift
    /// With stages 1-4 pre-completed, walks the five Improvisation lessons,
    /// plays the backing loop on lesson 2, and confirms the final handoff opens
    /// the Solo Practice tab. Exercises BackingLessonView and the backing
    /// transport at runtime.
    @MainActor
    func testImprovStageFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-unlock-improv"]
        app.launch()

        // Onboarding (a fresh suite still needs it).
        XCTAssertTrue(app.staticTexts["Pick your instrument"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Which hand frets?"].waitForExistence(timeout: 3))
        app.buttons["Enter the path"].tap()

        // Stage 5 is active because 1-4 are pre-completed.
        XCTAssertTrue(app.staticTexts["Your Path"].waitForExistence(timeout: 3))
        app.staticTexts["Improvisation"].tap()

        // Lesson 1 is the static safe-notes neck.
        XCTAssertTrue(app.staticTexts["Safe notes"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()

        // Lesson 2 plays the backing loop: Play toggles to Stop and back.
        XCTAssertTrue(app.staticTexts["Hear the backing"].waitForExistence(timeout: 3))
        app.buttons["Play backing track"].tap()
        XCTAssertTrue(app.buttons["Stop backing track"].waitForExistence(timeout: 3))
        app.buttons["Stop backing track"].tap()
        XCTAssertTrue(app.buttons["Play backing track"].waitForExistence(timeout: 3))

        // Step through to the last lesson.
        app.buttons["Next"].tap()   // 3
        XCTAssertTrue(app.staticTexts["Target the root"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()   // 4
        XCTAssertTrue(app.staticTexts["Short phrases"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()   // 5

        // Last lesson hands off to the Solo tab.
        XCTAssertTrue(app.staticTexts["Take a solo"].waitForExistence(timeout: 3))
        app.buttons["Open Solo Practice"].tap()

        // The handoff dismissed the lesson and switched to the Solo tab.
        // The tab bar is always on screen, so its selection is the robust signal.
        let soloTab = app.tabBars.buttons["Solo"]
        XCTAssertTrue(soloTab.waitForExistence(timeout: 3))
        XCTAssertTrue(soloTab.isSelected)
    }
```

- [ ] **Step 3: Run the test**

Run: `xcode_test` `only_testing: ["StringTheoryUITests/OnboardingUITests/testImprovStageFlow"]`
Expected: PASS.

If `app.staticTexts["Improvisation"].tap()` does not navigate, the stage row may still be locked: confirm the unlock seam ran (the Improvisation card should not read "Locked"). Do NOT modify app source to make the test pass; if the seam, the transport, or the handoff has a real bug, STOP and report BLOCKED with the failure. Only adjust test element queries for genuine selector issues, and report what you changed.

- [ ] **Step 4: Commit**

```bash
git add App/StringTheory/StringTheoryApp.swift App/StringTheoryUITests/OnboardingUITests.swift
git commit -m "$(cat <<'EOF'
test: UI flow through the Improvisation stage and Solo handoff

Generalizes the unlock seam with -uitest-unlock-improv (pre-completes
stages 1-4) and adds a test that walks the five Improvisation lessons,
plays and stops the backing loop, and confirms the final handoff opens
Solo Practice.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Update CLAUDE.md and run the app

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update the learning-path bullet**

In `CLAUDE.md`, the "Learning path is data-driven" bullet lists the lesson kinds and the increment status. Update it to:
- Add `.backing(key:type:)` to the list of `LessonKind` variants: the Solo screen's neck inside a lesson, safe notes lit with the active chord's root pulsing as the backing loop plays, tap-to-hear, with a Play/Stop backing transport.
- Note that stage 5 (Improvisation) is now a real five-lesson curriculum ending in a handoff to Solo Practice, so only stage 3 (Chords) remains a `.tab(.drift)` stub.

Keep it to a few plain sentences, no em dashes, matching the surrounding style.

- [ ] **Step 2: Commit the doc**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs: describe .backing lessons and the Solo handoff in CLAUDE.md

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Build, launch, and exercise the app**

Build and launch on the simulator (MCP `xcode_build` then `simulator_launch_app`, or run from Xcode). Then:
1. Reach stage 5 (fresh install completing stages 1-4, or via the unlock seam) and open Improvisation.
2. Lesson 1 "Safe notes": confirm the neck shows A minor pentatonic with the cyan root and degree labels, and tapping a dot plays a note.
3. Next to lesson 2 "Hear the backing": press Play backing. Confirm the four chord chips loop with the active one highlighted, the active chord's root pulses on the neck, and audio plays. Press Stop.
4. Step through lessons 3 and 4; confirm tap-to-hear still works and the transport toggles cleanly. Confirm advancing a lesson stops any playing loop (no audio bleeds into the next screen).
5. Lesson 5 "Take a solo": press "Open Solo Practice" and confirm the app switches to the Solo tab showing A minor pentatonic (the key just practiced), stopped.
6. Open Settings, switch to Bass, re-open an Improvisation backing lesson; confirm the neck shows four strings and the loop still plays.

Expected: no crashes, audio plays and stops correctly, the handoff switches tabs and pre-selects the key, and the bass variant renders four strings. (Per the project rule, this catches runtime-only issues that builds do not surface, like the audio-thread isolation trap.)

- [ ] **Step 4: Run the full suites once more**

Run `xcode_test` (whole `StringTheory` scheme, no `only_testing`) and `swift test --package-path StringTheoryCore`.
Expected: all pass.

---

## Self-review notes

- **Spec coverage (Improvisation increment):** five instrument-aware lessons matching the spec table (Task 2): lesson 1 the static safe-note neck via the existing `.scale` kind, lessons 2-5 the `.backing` loop (hear the backing, target the root, short phrases, take a solo), with the last handing off to Solo Practice. Safe-note markers with the pulsing active root reuse the Solo screen's exact `scaleMarkers` + `activeBackingRoot` logic (Task 1 `BackingLessonView`). Tap-to-hear throughout. Tests and a live run (Tasks 2, 3, 4).
- **No core changes (correct):** the spec assigns `chordTones`/`chordMarkers` factor-outs to the Chords increment, not this one. `backingProgression`, `scaleMarkers`, and the backing audio engine already exist, so this increment is app-only.
- **Reused infrastructure:** the `selectedTab` handoff, `MainTab.solo`, `handoffLabel(.solo) == "Open Solo Practice"`, and the Next/Finish forward button all shipped with the Scales increment and are reused unchanged except for the `.backing` branch in `handoff(to:)`.
- **Lifecycle safety:** `.backing` lessons start the shared backing engine via `toggleBacking()`, so the lesson player must stop it on lesson change, disappear, advance, and handoff (Task 1, Step 5-6). `stopBacking()` is widened from private to internal for this; its three existing callers are unaffected.
- **Type consistency:** `LessonKind.backing(key:type:)`, `BackingLessonView(key:type:)`, `model.toggleBacking()`, `model.stopBacking()`, `model.isPlayingBacking`, `model.backingChordIndex`, `model.activeBackingRoot`, `model.setSoloKey(_:)`, `model.setSoloScale(_:)`, and `backingProgression(key:scale:)` are used with the same names and signatures across tasks and match the existing `SoloPracticeView` and `AppModel` definitions. Lesson titles in the UI test ("Safe notes", "Hear the backing", "Target the root", "Short phrases", "Take a solo") match the curriculum in Task 2 exactly, and the transport accessibility labels ("Play backing track" / "Stop backing track") match Task 1's footer.
- **Handoff order:** `handoff(to:)` marks complete, stops the riff and the backing loop, pre-selects the solo key/scale, dismisses the lesson, then sets `selectedTab`. The UI test (Task 3) verifies the end state (the Solo tab is selected), which would catch an ordering problem.
