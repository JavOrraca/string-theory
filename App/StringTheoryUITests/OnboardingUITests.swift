import XCTest

final class OnboardingUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingRendersAndEntersApp() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"]
        app.launch()

        // Step 1 — instrument
        XCTAssertTrue(app.staticTexts["Pick your instrument"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()

        // Step 2 — handedness
        XCTAssertTrue(app.staticTexts["Which hand frets?"].waitForExistence(timeout: 3))
        app.buttons["Enter the path"].tap()

        // We should now be in the tab shell, on the Path tab.
        XCTAssertTrue(app.staticTexts["Your Path"].waitForExistence(timeout: 3))
    }

    /// Walks the three Fretboard Basics lessons end to end: each explore lesson
    /// renders, Next advances, and Finish returns to the path. Exercises
    /// ExploreLessonView and the lesson player at runtime.
    @MainActor
    func testFretboardBasicsLessonFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"]
        app.launch()

        // Onboarding.
        XCTAssertTrue(app.staticTexts["Pick your instrument"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Which hand frets?"].waitForExistence(timeout: 3))
        app.buttons["Enter the path"].tap()

        // Open the first stage from the path.
        XCTAssertTrue(app.staticTexts["Your Path"].waitForExistence(timeout: 3))
        app.staticTexts["Fretboard Basics"].tap()

        // Lesson 1 of 3.
        XCTAssertTrue(app.staticTexts["Open strings"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()

        // Lesson 2 of 3.
        XCTAssertTrue(app.staticTexts["Fret numbers"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()

        // Lesson 3 of 3 — the last one shows Finish.
        XCTAssertTrue(app.staticTexts["Find a note"].waitForExistence(timeout: 3))
        app.buttons["Finish"].tap()

        // Back on the path.
        XCTAssertTrue(app.staticTexts["Your Path"].waitForExistence(timeout: 3))
    }

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

        // Step through to the last lesson. Lesson 2's transport was just
        // exercised, so confirm the button is settled before the first advance.
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 3))
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
        // Step the diagram from E to Em. The picker row is separate from the
        // lesson title, so wait for the button before tapping it.
        XCTAssertTrue(app.buttons["Show Em"].waitForExistence(timeout: 3))
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

    /// Onboards as a bassist, then walks the five bass Chords lessons (the
    /// root-and-arpeggio track). Exercises ArpeggioLessonView at runtime and
    /// confirms the bass track has no Chord Library handoff: the last lesson
    /// shows Finish and returns to the path.
    @MainActor
    func testBassArpeggioStageFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-unlock-chords"]
        app.launch()

        // Onboarding: pick Bass (the stage-1/2 unlock keys match across instruments).
        XCTAssertTrue(app.staticTexts["Pick your instrument"].waitForExistence(timeout: 5))
        app.staticTexts["Bass"].tap()
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Which hand frets?"].waitForExistence(timeout: 3))
        app.buttons["Enter the path"].tap()

        // Stage 3 is active; open the bass Chords (arpeggio) track. The card title
        // "Chords" collides with the tab button, so tap it by its a11y label.
        XCTAssertTrue(app.staticTexts["Your Path"].waitForExistence(timeout: 3))
        let chordsStage = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Stage 03: Chords")).firstMatch
        XCTAssertTrue(chordsStage.waitForExistence(timeout: 3))
        chordsStage.tap()

        // Walk the five bass arpeggio lessons.
        XCTAssertTrue(app.staticTexts["Play the root"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Find every root"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Root and fifth"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Add the third"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()

        // The last bass lesson has no handoff (the Chord Library is guitar only):
        // it shows Finish and returns to the path.
        XCTAssertTrue(app.staticTexts["Walk a I-IV-V"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Finish"].waitForExistence(timeout: 3))
        app.buttons["Finish"].tap()
        XCTAssertTrue(app.staticTexts["Your Path"].waitForExistence(timeout: 3))
    }

    /// Completes Fretboard Basics, then walks the Tabs stage: lesson 1 renders,
    /// Play/Stop works, and stepping to the end finishes back on the path.
    @MainActor
    func testTabsStageFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"]
        app.launch()

        // Onboarding.
        XCTAssertTrue(app.staticTexts["Pick your instrument"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Which hand frets?"].waitForExistence(timeout: 3))
        app.buttons["Enter the path"].tap()

        // Complete Fretboard Basics (three lessons).
        XCTAssertTrue(app.staticTexts["Your Path"].waitForExistence(timeout: 3))
        app.staticTexts["Fretboard Basics"].tap()
        XCTAssertTrue(app.staticTexts["Open strings"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Fret numbers"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Find a note"].waitForExistence(timeout: 3))
        app.buttons["Finish"].tap()

        // Tabs is now active.
        XCTAssertTrue(app.staticTexts["Your Path"].waitForExistence(timeout: 3))
        app.staticTexts["Tabs"].tap()

        // Lesson 1 renders, and Play toggles to Stop and back.
        XCTAssertTrue(app.staticTexts["Reading a tab number"].waitForExistence(timeout: 3))
        app.buttons["Play riff"].tap()
        XCTAssertTrue(app.buttons["Stop riff"].waitForExistence(timeout: 3))
        app.buttons["Stop riff"].tap()
        XCTAssertTrue(app.buttons["Play riff"].waitForExistence(timeout: 3))

        // Step to the last lesson and finish.
        app.buttons["Next"].tap()   // 2
        app.buttons["Next"].tap()   // 3
        app.buttons["Next"].tap()   // 4
        app.buttons["Next"].tap()   // 5
        XCTAssertTrue(app.buttons["Finish"].waitForExistence(timeout: 3))
        app.buttons["Finish"].tap()
        XCTAssertTrue(app.staticTexts["Your Path"].waitForExistence(timeout: 3))
    }
}
