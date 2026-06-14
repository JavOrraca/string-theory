import SwiftUI
import StringTheoryCore

/// Tabs lesson — fretboard locked to a tab staff with a transport. Phase 2 shows
/// the structure; the live fretboard (Phase 3), synced tab, and audio (Phase 5)
/// fill in next.
struct LessonView: View {
    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 14) {
                Text("STAGE 02 · TABS").sectionLabel()
                Text("Read the riff").font(Typography.display(26))
                Text("Each number is a fret. The neck will light up as the tab plays.")
                    .font(Typography.body(14))
                    .foregroundStyle(Theme.Palette.textDim)

                FretboardPlaceholder()

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
