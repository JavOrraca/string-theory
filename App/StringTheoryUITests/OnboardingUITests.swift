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
