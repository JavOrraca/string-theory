import SwiftUI

@main
struct StringTheoryApp: App {
    @State private var model: AppModel

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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
        }
    }
}
