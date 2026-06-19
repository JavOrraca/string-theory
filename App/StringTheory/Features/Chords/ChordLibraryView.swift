import SwiftUI
import StringTheoryCore

/// Chord Library — STAGE 03 · CHORDS.
///
/// Always renders guitar voicings (6 strings, standard tuning), faithful to the
/// prototype which keeps guitar chords even when the global instrument is bass.
struct ChordLibraryView: View {
    @Environment(AppModel.self) private var model

    // Fixed 4-column grid for the chord chip strip.
    private let chipColumns = Array(repeating: GridItem(.flexible(), spacing: 9), count: 4)

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {

                    // ── Header ─────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 4) {
                        Text("STAGE 03 · CHORDS")
                            .sectionLabel()
                        Text("Chord Library")
                            .font(Typography.display(28))
                            .foregroundStyle(Theme.Palette.text)
                    }

                    // ── Diagram card ───────────────────────────────────────
                    diagramCard

                    // ── Chord chip grid ────────────────────────────────────
                    chordGrid
                }
                .padding(.horizontal, 20)
                .padding(.top, 58)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Diagram card

    private var diagramCard: some View {
        let chord = model.selectedChord
        let markers = chordMarkers(chord)
        let soundedNotes = orderedUnique(
            markers.filter { $0.kind != .muted }.compactMap(\.note)
        )

        return VStack(alignment: .leading, spacing: 14) {

            // Name row: big chord name left, NOTES + pitched notes right
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(chord.name)
                        .font(Typography.display(38))
                        .foregroundStyle(Theme.Palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(chord.quality.rawValue) · guitar voicing")
                        .font(Typography.mono(11, weight: .medium))
                        .tracking(1.0)
                        .foregroundStyle(Theme.Palette.textDim)
                        .textCase(.uppercase)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("NOTES")
                        .font(Typography.mono(10, weight: .medium))
                        .tracking(1.0)
                        .foregroundStyle(Theme.Palette.textDim)
                    Text(soundedNotes.map(\.name).joined(separator: " · "))
                        .font(Typography.mono(15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.signalCyan)
                        .multilineTextAlignment(.trailing)
                }
            }

            // Fretboard
            FretboardView(
                geometry: FretboardGeometry(
                    stringCount: 6,
                    fretCount: 5,
                    isLeftHanded: model.isLeftHanded
                ),
                openNotes: Tuning.guitar.strings.map(\.note),
                markers: markers
            )
            .frame(height: 190)
            .accessibilityLabel("Chord diagram for \(chord.name)")

            Button { model.playChord(chord) } label: {
                Text("▶  Play chord")
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel("Play the \(chord.name) chord")
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(oklchL: 0.17, c: 0.016, h: 250))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    Color(oklchL: 0.5, c: 0.03, h: 160, opacity: 0.16),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Chord chip grid

    private var chordGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ALL CHORDS · TAP TO LOAD")
                .font(Typography.mono(10, weight: .medium))
                .tracking(1.6)
                .foregroundStyle(Theme.Palette.textDim)

            LazyVGrid(columns: chipColumns, spacing: 9) {
                ForEach(Chord.library) { chord in
                    chordChip(chord)
                }
            }
        }
    }

    @ViewBuilder
    private func chordChip(_ chord: Chord) -> some View {
        let isActive = model.chordID == chord.id
        let phosphor = Theme.Palette.phosphor

        Button {
            model.chordID = chord.id
        } label: {
            Text(chord.name)
                .font(Typography.display(17, weight: .semibold))
                .foregroundStyle(
                    isActive
                        ? phosphor
                        : Color(oklchL: 0.82, c: 0.02, h: 230)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isActive
                                ? phosphor.opacity(0.16)
                                : Color(oklchL: 0.2, c: 0.018, h: 250)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isActive
                                ? phosphor
                                : Color(oklchL: 0.5, c: 0.03, h: 160, opacity: 0.16),
                            lineWidth: 1
                        )
                )
                // Phosphor glow on the active chip
                .glow(isActive ? phosphor.opacity(0.55) : .clear, radius: isActive ? 8 : 0)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.14), value: isActive)
        .accessibilityLabel("Load \(chord.name) chord")
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    // MARK: - Helpers

    /// Unique notes preserving first-seen order for a stable readout.
    private func orderedUnique(_ notes: [Note]) -> [Note] {
        var seen = Set<Note>()
        return notes.filter { seen.insert($0).inserted }
    }
}
