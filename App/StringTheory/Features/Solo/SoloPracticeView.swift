import SwiftUI
import StringTheoryCore

/// Solo Practice — the payoff screen. Phase 2 shows the live backing progression
/// from the core; safe-note highlighting on the neck + the synthesized backing
/// loop and transport arrive in Phases 3–5.
struct SoloPracticeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 14) {
                Text("STAGE 05 · IMPROVISATION").sectionLabel()
                Text("Solo Practice").font(Typography.display(28))

                FretboardView(
                    geometry: FretboardGeometry(stringCount: model.stringCount, fretCount: 12, isLeftHanded: model.isLeftHanded),
                    openNotes: model.openNotes,
                    markers: scaleMarkers(instrument: model.instrument, key: model.soloKey, scale: model.soloScale, frets: 12)
                )
                .frame(height: 208)

                Text("BACKING LOOP · \(model.soloKey.name) \(model.soloScale.label)").sectionLabel()
                HStack(spacing: 8) {
                    ForEach(Array(backingProgression(key: model.soloKey, scale: model.soloScale).enumerated()), id: \.offset) { _, chord in
                        Text(chord.name)
                            .font(Typography.display(15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.Palette.panel, in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.Palette.hairline))
                    }
                }
                Text("Safe-note highlighting + transport land in Phases 3–5.")
                    .font(Typography.body(13))
                    .foregroundStyle(Theme.Palette.textDim)
                Spacer()
            }
            .padding(22)
        }
    }
}
