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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
        }
    }
}
