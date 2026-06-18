import SwiftUI

/// Onboarding gates the rest of the app; once complete we show the 4-tab shell
/// (Path · Chords · Scales · Solo), matching the prototype's bottom nav.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            AppBackground()
            if model.hasOnboarded {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .foregroundStyle(Theme.Palette.text)
    }
}

struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            HomeView()
                .tag(MainTab.path)
                .tabItem { Label("Path", systemImage: "chart.line.uptrend.xyaxis") }
            ChordLibraryView()
                .settingsGear()
                .tag(MainTab.chords)
                .tabItem { Label("Chords", systemImage: "circle.grid.2x2.fill") }
            ScaleExplorerView()
                .settingsGear()
                .tag(MainTab.scales)
                .tabItem { Label("Scales", systemImage: "chart.bar.fill") }
            SoloPracticeView()
                .settingsGear()
                .tag(MainTab.solo)
                .tabItem { Label("Solo", systemImage: "play.fill") }
        }
        .tint(Theme.Palette.phosphor)
    }
}
