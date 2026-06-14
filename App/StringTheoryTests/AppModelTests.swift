import XCTest
import StringTheoryCore
@testable import StringTheory

@MainActor
final class AppModelTests: XCTestCase {

    func testDefaultsToRightHandedGuitar() {
        let model = AppModel()
        XCTAssertEqual(model.instrument, .guitar)
        XCTAssertFalse(model.isLeftHanded)
        XCTAssertFalse(model.hasOnboarded)
        XCTAssertEqual(model.stringCount, 6)
        XCTAssertEqual(model.openNotes, [.e, .a, .d, .g, .b, .e])
    }

    func testSwitchingToBassUpdatesDerivedTuning() {
        let model = AppModel()
        model.instrument = .bass
        XCTAssertEqual(model.stringCount, 4)
        XCTAssertEqual(model.openNotes, [.e, .a, .d, .g])
    }

    func testSelectedChordDefaultsToC() {
        let model = AppModel()
        XCTAssertEqual(model.selectedChord.id, "C")
    }
}
