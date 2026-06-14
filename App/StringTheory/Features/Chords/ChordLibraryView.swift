import SwiftUI
import StringTheoryCore

/// Chord Library — guitar voicings (as in the prototype, even when bass is the
/// chosen instrument). Phase 2 proves the core wiring with a live notes readout;
/// the diagram + tappable grid arrive in Phases 3–4.
struct ChordLibraryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 14) {
                Text("STAGE 03 · CHORDS").sectionLabel()
                Text("Chord Library").font(Typography.display(28))

                FretboardView(
                    geometry: FretboardGeometry(stringCount: 6, fretCount: 5, isLeftHanded: model.isLeftHanded),
                    openNotes: Tuning.guitar.strings.map(\.note),
                    markers: chordMarkers(model.selectedChord)
                )
                .frame(height: 190)

                let chord = model.selectedChord
                let notes = chordMarkers(chord)
                    .filter { $0.kind != .muted }
                    .compactMap(\.note)
                HStack(alignment: .firstTextBaseline) {
                    Text(chord.name).font(Typography.display(38))
                    Spacer()
                    Text(orderedUnique(notes).map(\.name).joined(separator: " · "))
                        .font(Typography.mono(15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.signalCyan)
                }
                Text("Tappable chord grid + labelled diagram land in Phase 4.")
                    .font(Typography.body(13))
                    .foregroundStyle(Theme.Palette.textDim)
                Spacer()
            }
            .padding(22)
        }
    }

    /// Unique notes preserving first-seen order (for a stable readout).
    private func orderedUnique(_ notes: [Note]) -> [Note] {
        var seen = Set<Note>()
        return notes.filter { seen.insert($0).inserted }
    }
}
