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
        let guitarStages = LearningPath.stages(for: .guitar)
        XCTAssertEqual(model.overallPercent, 0)
        XCTAssertEqual(model.status(for: guitarStages[0]), .active)
        XCTAssertEqual(model.status(for: guitarStages[1]), .locked)
    }

    func testCompletingFirstStageUnlocksTheSecond() {
        let model = freshModel()
        let guitarStages = LearningPath.stages(for: .guitar)
        let first = guitarStages[0]
        for lesson in first.lessons {
            model.markLessonComplete(stageID: first.id, lessonID: lesson.id)
        }
        XCTAssertEqual(model.status(for: first), .done)
        XCTAssertEqual(model.status(for: guitarStages[1]), .active)
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
        let stage = LearningPath.stages(for: .guitar)[0]
        first.markLessonComplete(stageID: stage.id, lessonID: stage.lessons[0].id)

        let reloaded = AppModel(defaults: defaults)
        XCTAssertEqual(reloaded.instrument, .bass)
        XCTAssertTrue(reloaded.isLeftHanded)
        XCTAssertTrue(reloaded.hasOnboarded)
        XCTAssertTrue(reloaded.isLessonComplete(stageID: stage.id, lessonID: stage.lessons[0].id))
    }

    func testTempoDefaultsClampsAndPersists() {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let model = AppModel(defaults: defaults)
        XCTAssertEqual(model.tempo, AppModel.defaultTempo)
        model.setTempo(40)
        XCTAssertEqual(model.tempo, model.tempoRange.lowerBound)
        model.setTempo(999)
        XCTAssertEqual(model.tempo, model.tempoRange.upperBound)
        model.setTempo(90)

        XCTAssertEqual(AppModel(defaults: defaults).tempo, 90)
    }

    func testLearningPathIsInstrumentAware() {
        let guitar = LearningPath.stages(for: .guitar)
        let bass = LearningPath.stages(for: .bass)
        XCTAssertEqual(guitar.count, 5)
        XCTAssertEqual(bass.count, 5)
        XCTAssertEqual(guitar.map(\.id), [1, 2, 3, 4, 5])
        XCTAssertEqual(bass.map(\.id), [1, 2, 3, 4, 5])
    }

    func testModelExposesInstrumentStages() {
        let model = freshModel()                 // guitar by default
        XCTAssertEqual(model.stages.map(\.id), [1, 2, 3, 4, 5])
        model.setInstrument(.bass)
        XCTAssertEqual(model.stages.map(\.id), [1, 2, 3, 4, 5])
    }

    func testStageTwoHasFiveLessonsPerInstrument() {
        XCTAssertEqual(LearningPath.stages(for: .guitar)[1].lessons.count, 5)
        XCTAssertEqual(LearningPath.stages(for: .bass)[1].lessons.count, 5)
    }

    func testStageTwoFinalLessonDiffersByInstrument() {
        let guitarLast = LearningPath.stages(for: .guitar)[1].lessons[4].title
        let bassLast = LearningPath.stages(for: .bass)[1].lessons[4].title
        XCTAssertNotEqual(guitarLast, bassLast)
    }

    func testCompletingStagesOneAndTwoUnlocksThree() {
        let model = freshModel()                                  // guitar
        for l in model.stages[0].lessons { model.markLessonComplete(stageID: 1, lessonID: l.id) }
        for l in model.stages[1].lessons { model.markLessonComplete(stageID: 2, lessonID: l.id) }
        XCTAssertEqual(model.status(for: model.stages[1]), .done)
        XCTAssertEqual(model.status(for: model.stages[2]), .active)
    }

    func testSelectedTabDefaultsToPath() {
        XCTAssertEqual(freshModel().selectedTab, .path)
    }

    func testSelectedTabIsSettable() {
        let model = freshModel()
        model.selectedTab = .scales
        XCTAssertEqual(model.selectedTab, .scales)
    }

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

    func testStageFourIntroHidesDegreesThenRevealsThem() {
        let lessons = LearningPath.stages(for: .guitar)[3].lessons
        func showsDegrees(_ lesson: Lesson) -> Bool {
            if case .scale(_, _, let show) = lesson.kind { return show }
            return false
        }
        // Lesson 1 introduces the shape as plain dots; the rest name the degrees.
        XCTAssertFalse(showsDegrees(lessons[0]), "lesson 1 should hide degree labels")
        XCTAssertTrue(lessons.dropFirst().allSatisfy(showsDegrees), "lessons 2-5 should show degrees")
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
}
