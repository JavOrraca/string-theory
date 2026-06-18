# Stage 4 Scales & Keys Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stage 4 (Scales & Keys) stub with a real five-lesson, instrument-aware curriculum, and land the tool-handoff machinery (a `selectedTab` on `AppModel` bound to the tab bar, plus a per-lesson handoff) that lets a lesson send the learner into the matching tool tab.

**Architecture:** Add a `.scale(key:type:)` `LessonKind` rendered by a `ScaleLessonView` that reuses the one `FretboardView` with the core's `scaleMarkers` (root cyan, degree labels) and is tap-to-hear. Add a `MainTab` enum and `AppModel.selectedTab` bound to `MainTabView`'s `TabView`, and an optional `Lesson.handoff: MainTab?` whose forward button switches tabs (pre-selecting the scale just taught) instead of just dismissing.

**Tech Stack:** Swift 6, SwiftUI (iOS 17, Observation `@Bindable`), StringTheoryCore (Swift Testing), app tests (XCTest/XCUITest), raw `xcodebuild` for app build/test.

**Delivery context:** Increment 2 of 4 from `docs/superpowers/specs/2026-06-17-stages-2-5-content-design.md` (Tabs shipped; this is Scales; then Improvisation, then Chords). After this plan, stages 3 and 5 are still single `.tab(.drift)` stubs. The spec assigns the `selectedTab` handoff infrastructure to this increment.

**Conventions (from CLAUDE.md):**
- New app source files require editing the committed `.xcodeproj`. All new app types go in EXISTING files (`AppModel.swift`, `LessonView.swift`). New core files are fine but none are needed here.
- Prose/comments: no em dashes, plain wording.
- Run the app, do not just build it.
- Commit messages end with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Editor SourceKit "No such module 'StringTheoryCore'" / "cannot find type" diagnostics are index lag; trust `xcodebuild` / `swift test`.

**Build/test commands (allow Bash timeout 600000):**
- App tests: `xcodebuild test -project StringTheory.xcodeproj -scheme StringTheory -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:<...>`
- App build: `xcodebuild build -project StringTheory.xcodeproj -scheme StringTheory -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Core tests: `swift test --package-path StringTheoryCore`

**Note on line numbers:** the line numbers below were taken from the post-Tabs state of `main`. They may drift by a few lines as earlier tasks in THIS plan edit the same files. Match by the code content shown, not the line number.

---

## File structure

- `App/StringTheory/AppModel.swift` (modify): add `enum MainTab`; add `var selectedTab: MainTab = .path`; add `.scale(key:type:)` to `LessonKind`; add `handoff: MainTab? = nil` to `Lesson`; replace the `scalesAndKeys` stub with five lessons.
- `App/StringTheory/RootView.swift` (modify): bind `MainTabView`'s `TabView` to `model.selectedTab` with `.tag(...)`.
- `App/StringTheory/Features/Lesson/LessonView.swift` (modify): content switch gets a `.scale` case; footer routes `.scale` through a shared forward button that honors `handoff`; add `ScaleLessonView`.
- `App/StringTheory/StringTheoryApp.swift` (modify): add a `-uitest-unlock-scales` launch-arg seam that pre-completes stages 1-3 so the UI test can reach stage 4.
- `App/StringTheoryTests/AppModelTests.swift` (modify): selectedTab default, stage 4 curriculum, handoff field, multi-stage unlock.
- `App/StringTheoryUITests/OnboardingUITests.swift` (modify): a Scales stage flow test that ends by handing off to the Scales tab.
- `CLAUDE.md` (modify): note `.scale`, `selectedTab`/handoff, and stage 4 being real.

---

## Task 1: Add `MainTab` and bind the tab bar to `selectedTab`

This is the reusable handoff seam. No lesson behavior changes yet.

**Files:**
- Modify: `App/StringTheory/AppModel.swift` (session-only state block near the top; and add the `MainTab` enum)
- Modify: `App/StringTheory/RootView.swift` (`MainTabView`, lines 21-38)
- Test: `App/StringTheoryTests/AppModelTests.swift`

- [ ] **Step 1: Write the failing test**

In `AppModelTests.swift`, add inside the class:

```swift
    func testSelectedTabDefaultsToPath() {
        XCTAssertEqual(freshModel().selectedTab, .path)
    }

    func testSelectedTabIsSettable() {
        let model = freshModel()
        model.selectedTab = .scales
        XCTAssertEqual(model.selectedTab, .scales)
    }
```

- [ ] **Step 2: Run and confirm it fails to compile**

Run: `xcodebuild test ... -only-testing:StringTheoryTests/AppModelTests/testSelectedTabDefaultsToPath`
Expected: FAIL to compile ("value of type 'AppModel' has no member 'selectedTab'", "cannot infer ... '.path'").

- [ ] **Step 3: Add the `MainTab` enum and the `selectedTab` property**

In `AppModel.swift`, find the session-only state (the block with `var scaleKey: Note = .e` etc., around line 22). Add the property there:

```swift
    /// Which tab is showing. Session-only. A lesson handoff sets this to send the
    /// learner into the matching tool tab.
    var selectedTab: MainTab = .path
```

Then add the enum near the other learning-path types (next to `enum StageStatus` / `enum LessonKind`, around line 215):

```swift
/// The four tabs in the main shell. Drives `TabView` selection so a lesson can
/// hand off to a tool tab.
enum MainTab: Hashable {
    case path, chords, scales, solo
}
```

- [ ] **Step 4: Bind the tab bar**

In `RootView.swift`, replace the whole `struct MainTabView` (lines 21-38) with:

```swift
struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            HomeView()
                .tag(MainTab.path)
                .tabItem { Label("Path", systemImage: "chart.line.uptrend.xyaxis") }
            ChordLibraryView()
                .settingsGear()
                .tag(MainTab.chords)
                .tabItem { Label("Chords", systemImage: "circle.grid.2x2.fill") }
            ScaleExplorerView()
                .settingsGear()
                .tag(MainTab.scales)
                .tabItem { Label("Scales", systemImage: "chart.bar.fill") }
            SoloPracticeView()
                .settingsGear()
                .tag(MainTab.solo)
                .tabItem { Label("Solo", systemImage: "play.fill") }
        }
        .tint(Theme.Palette.phosphor)
    }
}
```

- [ ] **Step 5: Run the tests and build**

Run: `xcodebuild test ... -only-testing:StringTheoryTests/AppModelTests` -> PASS (including the two new tests).
The tab binding itself is exercised by the UI test in Task 4; here, confirm the app still builds and the suite is green.

- [ ] **Step 6: Commit**

```bash
git add App/StringTheory/AppModel.swift App/StringTheory/RootView.swift App/StringTheoryTests/AppModelTests.swift
git commit -m "$(cat <<'EOF'
feat: bind the tab bar to AppModel.selectedTab

Adds a MainTab enum and a session-only selectedTab, bound to the main
TabView. This is the seam a lesson handoff uses to switch tabs.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add the `.scale` lesson kind, its renderer, and the lesson handoff

**Files:**
- Modify: `App/StringTheory/AppModel.swift` (`LessonKind`, `Lesson` struct)
- Modify: `App/StringTheory/Features/Lesson/LessonView.swift` (content switch, footer, new `ScaleLessonView`)

No new lessons yet (stage 4 content lands in Task 3); this adds the capability. Verification is build plus the existing suite staying green, since the switches must remain exhaustive.

- [ ] **Step 1: Extend `LessonKind` and `Lesson`**

In `AppModel.swift`, change `LessonKind` from:

```swift
enum LessonKind: Hashable {
    case tab(Riff)
    case reading(String)
    case explore(ExploreLesson)
}
```
to:
```swift
enum LessonKind: Hashable {
    case tab(Riff)
    case reading(String)
    case explore(ExploreLesson)
    case scale(key: Note, type: ScaleType)
}
```

Then add the optional handoff to the `Lesson` struct. Change:
```swift
struct Lesson: Identifiable, Hashable {
    let id: Int            // unique within its stage
    let title: String
    let subtitle: String
    let kind: LessonKind
}
```
to:
```swift
struct Lesson: Identifiable, Hashable {
    let id: Int            // unique within its stage
    let title: String
    let subtitle: String
    let kind: LessonKind
    /// When set, this lesson's forward button opens the named tool tab instead
    /// of just advancing or dismissing.
    var handoff: MainTab? = nil
}
```
(The default keeps every existing `Lesson(id:title:subtitle:kind:)` call valid.)

- [ ] **Step 2: Add the `.scale` case to the content switch**

In `LessonView.swift`, the content switch currently reads:

```swift
            switch lesson.kind {
            case .tab(let riff):
                TabLessonView(riff: riff)
            case .explore(let exercise):
                ExploreLessonView(exercise: exercise)
            case .reading(let body):
                Text(body)
                    .font(Typography.body(15))
                    .foregroundStyle(Theme.Palette.text)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
```
Add a `.scale` case:
```swift
            switch lesson.kind {
            case .tab(let riff):
                TabLessonView(riff: riff)
            case .explore(let exercise):
                ExploreLessonView(exercise: exercise)
            case .scale(let key, let type):
                ScaleLessonView(key: key, type: type)
            case .reading(let body):
                Text(body)
                    .font(Typography.body(15))
                    .foregroundStyle(Theme.Palette.text)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
```

- [ ] **Step 3: Route the footer through a shared, handoff-aware forward button**

In `LessonView.swift`, replace the `footer` computed property (the `@ViewBuilder private var footer: some View { switch lesson.kind { ... } }` block) with:

```swift
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
        case .reading, .explore, .scale:
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
```

- [ ] **Step 4: Add the handoff helpers**

In `LessonView.swift`, immediately after the existing `advance()` method, add:

```swift
    /// Marks the lesson complete, stops audio, pops back to the path, and
    /// switches to the tool tab. For a `.scale` lesson it pre-selects the scale
    /// just taught so the explorer opens on it.
    private func handoff(to tab: MainTab) {
        model.markLessonComplete(stageID: stage.id, lessonID: lesson.id)
        model.stopRiff()
        if case .scale(let key, let type) = lesson.kind {
            model.scaleKey = key
            model.scaleType = type
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
```

- [ ] **Step 5: Add `ScaleLessonView`**

In `LessonView.swift`, at the end of the file (after `ExploreLessonView`), add:

```swift
// MARK: - Scale lesson content (degrees on the neck, tap-to-hear)

/// A scale on the learner's own neck: the core's `scaleMarkers` light the root
/// in cyan and label every tone with its degree. Tapping a note plays it.
private struct ScaleLessonView: View {
    let key: Note
    let type: ScaleType

    @Environment(AppModel.self) private var model

    var body: some View {
        FretboardView(
            geometry: FretboardGeometry(stringCount: model.stringCount, fretCount: 12,
                                        startFret: 0, isLeftHanded: model.isLeftHanded),
            openNotes: model.openNotes,
            markers: scaleMarkers(instrument: model.instrument, key: key, scale: type, frets: 12),
            onTapPosition: { string, fret in model.playNote(string: string, fret: fret) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .panel()
    }
}
```

- [ ] **Step 6: Build and confirm the suite stays green**

Run:
- `xcodebuild build ...` -> Build succeeded.
- `xcodebuild test ... -only-testing:StringTheoryTests/AppModelTests` -> PASS.
- `xcodebuild test ... -only-testing:StringTheoryUITests/OnboardingUITests/testFretboardBasicsLessonFlow` -> PASS (confirms the footer change did not break non-tab lessons).

- [ ] **Step 7: Commit**

```bash
git add App/StringTheory/AppModel.swift App/StringTheory/Features/Lesson/LessonView.swift
git commit -m "$(cat <<'EOF'
feat: add .scale lessons and the tool handoff

A .scale lesson renders degrees on the neck (root cyan) and is
tap-to-hear. Lessons can set a handoff so their forward button opens the
matching tool tab, pre-selecting what was taught.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Author the stage 4 Scales & Keys curriculum

**Files:**
- Modify: `App/StringTheory/AppModel.swift` (the `scalesAndKeys` definition)
- Test: `App/StringTheoryTests/AppModelTests.swift`

- [ ] **Step 1: Write the failing tests**

In `AppModelTests.swift`, add inside the class:

```swift
    func testStageFourHasFiveScaleLessons() {
        let stage = LearningPath.stages(for: .guitar)[3]
        XCTAssertEqual(stage.id, 4)
        XCTAssertEqual(stage.lessons.count, 5)
        for lesson in stage.lessons {
            if case .scale = lesson.kind { } else {
                XCTFail("stage 4 lesson \(lesson.id) is not a .scale lesson")
            }
        }
    }

    func testStageFourLastLessonHandsOffToScales() {
        let last = LearningPath.stages(for: .guitar)[3].lessons[4]
        XCTAssertEqual(last.handoff, .scales)
    }

    func testCompletingStagesThroughFourUnlocksFive() {
        let model = freshModel()
        for stage in model.stages where stage.id <= 4 {
            for lesson in stage.lessons {
                model.markLessonComplete(stageID: stage.id, lessonID: lesson.id)
            }
        }
        XCTAssertEqual(model.status(for: model.stages[3]), .done)
        XCTAssertEqual(model.status(for: model.stages[4]), .active)
    }
```

- [ ] **Step 2: Run and confirm failure**

Run: `xcodebuild test ... -only-testing:StringTheoryTests/AppModelTests/testStageFourHasFiveScaleLessons`
Expected: FAIL (count is 1, and the single lesson is `.tab`, not `.scale`).

- [ ] **Step 3: Replace the `scalesAndKeys` stub**

In `AppModel.swift`, replace:

```swift
    private static let scalesAndKeys = LearningStage(
        id: 4, number: "04", title: "Scales & Keys",
        subtitle: "Major & pentatonic patterns across the neck",
        lessons: [Lesson(id: 1, title: "Scales & Keys",
                         subtitle: "Watch the neck as the riff plays.", kind: .tab(.drift))])
```
with:
```swift
    private static let scalesAndKeys = LearningStage(
        id: 4, number: "04", title: "Scales & Keys",
        subtitle: "Major & pentatonic patterns across the neck",
        lessons: [
            Lesson(id: 1, title: "What a scale is",
                   subtitle: "A scale is the set of notes that fit a key. This is E minor pentatonic. The cyan note is the root. Tap any note to hear it.",
                   kind: .scale(key: .e, type: .minorPentatonic)),
            Lesson(id: 2, title: "The root and the degrees",
                   subtitle: "Every note shows its scale degree, and the root is 1. Tap up from the root to hear the degrees climb.",
                   kind: .scale(key: .e, type: .minorPentatonic)),
            Lesson(id: 3, title: "Minor vs major pentatonic",
                   subtitle: "Same key, brighter sound. This is E major pentatonic. Compare it to the minor shape you just saw.",
                   kind: .scale(key: .e, type: .majorPentatonic)),
            Lesson(id: 4, title: "Same shape, new key",
                   subtitle: "Move the whole pattern up and the key changes with it. This is A minor pentatonic: same shape, new root.",
                   kind: .scale(key: .a, type: .minorPentatonic)),
            Lesson(id: 5, title: "Explore on your own",
                   subtitle: "Now pick any key and scale yourself and watch the whole neck redraw.",
                   kind: .scale(key: .a, type: .minorPentatonic),
                   handoff: .scales),
        ])
```

- [ ] **Step 4: Run the suite and confirm green**

Run: `xcodebuild test ... -only-testing:StringTheoryTests/AppModelTests` -> PASS (all three new tests plus the rest).

- [ ] **Step 5: Commit**

```bash
git add App/StringTheory/AppModel.swift App/StringTheoryTests/AppModelTests.swift
git commit -m "$(cat <<'EOF'
feat: real stage 4 Scales & Keys curriculum

Five tap-to-hear scale lessons: what a scale is, the root and degrees,
minor vs major pentatonic, the same shape in a new key, and a handoff
into the Scale Explorer.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Test seam plus a Scales stage UI flow test

Reaching stage 4 in the UI means completing stages 1-3 first. Add a launch-arg seam that pre-completes them, then a UI test that walks the five Scales lessons and confirms the handoff lands on the Scales tab.

**Files:**
- Modify: `App/StringTheory/StringTheoryApp.swift`
- Modify: `App/StringTheoryUITests/OnboardingUITests.swift`

- [ ] **Step 1: Add the unlock seam**

In `StringTheoryApp.swift`, replace the `init()`:

```swift
    init() {
        // UI tests pass -uitest-reset to start from a clean, not-yet-onboarded state.
        if ProcessInfo.processInfo.arguments.contains("-uitest-reset") {
            let defaults = UserDefaults(suiteName: "uitest")!
            defaults.removePersistentDomain(forName: "uitest")
            _model = State(initialValue: AppModel(defaults: defaults))
        } else {
            _model = State(initialValue: AppModel())
        }
    }
```
with:
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

(`App.init()` is main-actor isolated, so calling `markLessonComplete` here is fine; the existing code already builds the `@MainActor AppModel` in `init`.)

- [ ] **Step 2: Write the UI test**

In `OnboardingUITests.swift`, add inside the class:

```swift
    /// With stages 1-3 pre-completed, walks the five Scales & Keys lessons and
    /// confirms the final handoff opens the Scale Explorer tab.
    @MainActor
    func testScalesStageFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-unlock-scales"]
        app.launch()

        // Onboarding (a fresh suite still needs it).
        XCTAssertTrue(app.staticTexts["Pick your instrument"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Which hand frets?"].waitForExistence(timeout: 3))
        app.buttons["Enter the path"].tap()

        // Stage 4 is active because 1-3 are pre-completed.
        XCTAssertTrue(app.staticTexts["Your Path"].waitForExistence(timeout: 3))
        app.staticTexts["Scales & Keys"].tap()

        // Walk the five scale lessons.
        XCTAssertTrue(app.staticTexts["What a scale is"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["The root and the degrees"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Minor vs major pentatonic"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Same shape, new key"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()

        // Last lesson hands off to the Scales tab.
        XCTAssertTrue(app.staticTexts["Explore on your own"].waitForExistence(timeout: 3))
        app.buttons["Open the Scale Explorer"].tap()

        // The handoff dismissed the lesson and switched to the Scale Explorer tab.
        // The tab bar is always on screen, so its selection is the robust signal.
        let scalesTab = app.tabBars.buttons["Scales"]
        XCTAssertTrue(scalesTab.waitForExistence(timeout: 3))
        XCTAssertTrue(scalesTab.isSelected)
    }
```

- [ ] **Step 3: Run the test**

Run: `xcodebuild test ... -only-testing:StringTheoryUITests/OnboardingUITests/testScalesStageFlow`
Expected: PASS.

If `app.staticTexts["Scales & Keys"].tap()` does not navigate, the stage row may not be active. Confirm the unlock seam ran (the Scales stage card should not read "Locked"). Do NOT modify app source to make the test pass; if the seam or handoff has a real bug, STOP and report BLOCKED with the failure. Only adjust test element queries for genuine selector issues, and report what you changed.

- [ ] **Step 4: Commit**

```bash
git add App/StringTheory/StringTheoryApp.swift App/StringTheoryUITests/OnboardingUITests.swift
git commit -m "$(cat <<'EOF'
test: UI flow through the Scales stage and tool handoff

Adds a -uitest-unlock-scales launch seam that pre-completes stages 1-3,
and a test that walks the five Scales lessons and confirms the final
handoff opens the Scale Explorer tab.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Update CLAUDE.md and run the app

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update the learning-path bullet**

In `CLAUDE.md`, the "Learning path is data-driven" bullet currently lists the lesson kinds as `.explore`, `.tab(Riff)`, and `.reading`, and says stage 2 (Tabs) is real while stages 3-5 are `.tab(.drift)` stubs. Update it to also describe:
- `.scale(key:type:)` as a lesson kind (a tap-to-hear scale on the neck, root cyan, degree labels).
- `AppModel.selectedTab` (a `MainTab`) bound to the tab bar, and that a lesson with `handoff` set sends the learner into a tool tab (used by the last Scales lesson to open the Scale Explorer).
- Stage 4 (Scales & Keys) is now a real five-lesson curriculum; stages 3 and 5 remain `.tab(.drift)` stubs pending their increments.

Keep it to a few plain sentences, no em dashes.

- [ ] **Step 2: Commit the doc**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs: describe .scale lessons and the tab handoff in CLAUDE.md

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Build, launch, and exercise the app**

Build and launch on the simulator. Then:
1. With a fresh install (or after completing stages 1-3), open Scales & Keys.
2. Confirm lesson 1 shows the neck with cyan root and degree labels, and tapping a dot plays a note.
3. Press Next through the five lessons. On lesson 3 confirm the shape brightens (major pentatonic); on lesson 4 confirm the pattern shifts up (A minor pentatonic).
4. On the last lesson press "Open the Scale Explorer" and confirm the app switches to the Scales tab showing A minor pentatonic (the key just taught).
5. Open Settings, switch to Bass, and re-open a Scales lesson; confirm the neck shows four strings and the scale still renders.

Expected: no crashes, audio plays, the handoff switches tabs and pre-selects the scale, and the bass variant renders four strings. (Per the project rule, this catches runtime-only issues that builds do not surface.)

- [ ] **Step 4: Run the full suites once more**

Run `xcodebuild test ...` (whole `StringTheory` scheme) and `swift test --package-path StringTheoryCore`.
Expected: all pass.

---

## Self-review notes

- **Spec coverage (Scales increment):** five instrument-aware `.scale` lessons matching the spec table (Tasks 2-3); root highlighted with degree labels via `scaleMarkers`, tap-to-hear (Task 2 `ScaleLessonView`); the `selectedTab` handoff infrastructure the spec assigns to this increment (Tasks 1-2), with the last lesson opening the Scale Explorer (Task 3); tests and a live run (Tasks 1, 3, 4, 5).
- **Out of scope (correctly):** stages 3 and 5 stay `.tab(.drift)` stubs; the Chords and Improvisation curricula are their own increments. No new core code (the scale functions already exist).
- **Type consistency:** `MainTab` (`.path/.chords/.scales/.solo`), `selectedTab`, `LessonKind.scale(key:type:)`, `Lesson.handoff`, `ScaleLessonView(key:type:)`, `handoff(to:)`, `handoffLabel(_:)`, and `forwardButton` are used with the same names and signatures across tasks. `scaleMarkers(instrument:key:scale:frets:)` matches the core signature used by `ScaleExplorerView`/`SoloPracticeView`.
- **Handoff order:** `handoff(to:)` marks complete, stops audio, pre-selects the scale, dismisses the lesson, then sets `selectedTab`. The UI test (Task 4) verifies the end state (the Scale Explorer's "SCALE DEGREES" legend appears), which would catch an ordering problem.
