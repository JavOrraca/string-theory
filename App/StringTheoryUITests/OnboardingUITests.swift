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
}
