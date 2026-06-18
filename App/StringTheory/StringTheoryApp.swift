import SwiftUI

@main
struct StringTheoryApp: App {
    @State private var model: AppModel

    init() {
        let args = ProcessInfo.processInfo.arguments
        // UI tests pass -uitest-reset to start from a clean, not-yet-onboarded state.
        if args.contains("-uitest-reset") {
            let defaults = UserDefaults(suiteName: "uitest")!
            defaults.removePersistentDomain(forName: "uitest")
            let model = AppModel(defaults: defaults)
            // Pre-complete earlier stages so a test can land on a later one:
            // -uitest-unlock-scales reaches stage 4, -uitest-unlock-improv reaches stage 5.
            // If both flags are present, the higher unlock (improv) wins.
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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
        }
    }
}
