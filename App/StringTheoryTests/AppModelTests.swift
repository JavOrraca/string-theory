import XCTest
import StringTheoryCore
@testable import StringTheory

@MainActor
final class AppModelTests: XCTestCase {

    /// A model backed by a clean, isolated UserDefaults suite.
    private func freshModel() -> AppModel {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppModel(defaults: defaults)
    }

    func testDefaultsToRightHandedGuitar() {
        let model = freshModel()
        XCTAssertEqual(model.instrument, .guitar)
        XCTAssertFalse(model.isLeftHanded)
        XCTAssertFalse(model.hasOnboarded)
        XCTAssertEqual(model.stringCount, 6)
        XCTAssertEqual(model.openNotes, [.e, .a, .d, .g, .b, .e])
    }

    func testSwitchingToBassUpdatesDerivedTuning() {
        let model = freshModel()
        model.setInstrument(.bass)
        XCTAssertEqual(model.stringCount, 4)
        XCTAssertEqual(model.openNotes, [.e, .a, .d, .g])
    }

    func testSelectedChordDefaultsToC() {
        XCTAssertEqual(freshModel().selectedChord.id, "C")
    }

    func testFreshUserStartsAtZeroWithFirstStageActive() {
        let model = freshModel()
        XCTAssertEqual(model.overallPercent, 0)
        XCTAssertEqual(model.status(for: LearningPath.stages[0]), .active)
        XCTAssertEqual(model.status(for: LearningPath.stages[1]), .locked)
    }

    func testCompletingFirstStageUnlocksTheSecond() {
        let model = freshModel()
        let first = LearningPath.stages[0]
        for lesson in first.lessons {
            model.markLessonComplete(stageID: first.id, lessonID: lesson.id)
        }
        XCTAssertEqual(model.status(for: first), .done)
        XCTAssertEqual(model.status(for: LearningPath.stages[1]), .active)
        XCTAssertGreaterThan(model.overallPercent, 0)
    }

    func testSetupPersistsAcrossModelInstances() {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let first = AppModel(defaults: defaults)
        first.setInstrument(.bass)
        first.setLeftHanded(true)
        first.completeOnboarding()
        let stage = LearningPath.stages[0]
        first.markLessonComplete(stageID: stage.id, lessonID: stage.lessons[0].id)

        let reloaded = AppModel(defaults: defaults)
        XCTAssertEqual(reloaded.instrument, .bass)
        XCTAssertTrue(reloaded.isLeftHanded)
        XCTAssertTrue(reloaded.hasOnboarded)
        XCTAssertTrue(reloaded.isLessonComplete(stageID: stage.id, lessonID: stage.lessons[0].id))
    }
}
