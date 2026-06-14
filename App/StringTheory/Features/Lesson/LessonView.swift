import SwiftUI
import StringTheoryCore

/// Tabs lesson — fretboard locked to a tab staff with a transport. Phase 2 shows
/// the structure; the live fretboard (Phase 3), synced tab, and audio (Phase 5)
/// fill in next.
struct LessonView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 14) {
                Text("STAGE 02 · TABS").sectionLabel()
                Text("Read the riff").font(Typography.display(26))
                Text("Each number is a fret. The neck will light up as the tab plays.")
                    .font(Typography.body(14))
                    .foregroundStyle(Theme.Palette.textDim)

                FretboardView(
                    geometry: FretboardGeometry(stringCount: 6, fretCount: 5, isLeftHanded: model.isLeftHanded),
                    openNotes: Tuning.guitar.strings.map(\.note),
                    markers: Riff.drift.steps.map { Marker(string: $0.string, fret: $0.fret, kind: .safe) }
                )
                .frame(height: 180)

                Text("TABLATURE · \(Riff.drift.name)").sectionLabel()
                Text("Synced tab staff + ♩=110 transport land in Phases 3–5.")
                    .font(Typography.body(13))
                    .foregroundStyle(Theme.Palette.textDim)
                Spacer()
            }
            .padding(22)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
