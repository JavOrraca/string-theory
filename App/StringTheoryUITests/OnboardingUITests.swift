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
}
