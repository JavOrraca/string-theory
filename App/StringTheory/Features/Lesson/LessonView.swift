import SwiftUI
import StringTheoryCore

/// Tabs lesson — fretboard locked to a tab staff with a stubbed transport.
/// Audio and step-sync wire up in Phase 5.
struct LessonView: View {
    @Environment(AppModel.self) private var model

    // TODO: wire AudioEngine + step sync in Phase 5
    @State private var isPlaying = false

    private let riff = Riff.drift

    // Guitar open notes low→high (string 0 = low E, string 5 = high e).
    private var guitarOpenNotes: [Note] {
        Tuning.guitar.strings.map(\.note)
    }

    // Riff markers — all safe (active highlighting deferred to Phase 5).
    private var lessonMarkers: [Marker] {
        // De-duplicate positions; in Phase 5 the active step will use .active kind.
        var seen: [String: Marker] = [:]
        for step in riff.steps {
            let key = "\(step.string):\(step.fret)"
            seen[key] = Marker(string: step.string, fret: step.fret, kind: .safe)
        }
        return Array(seen.values)
    }

    // Tab rows: high string (index 5) down to low string (index 0).
    // Each row carries 12 cells, one per riff step.
    private var tabRows: [TabRow] {
        let stringCount = 6
        return stride(from: stringCount - 1, through: 0, by: -1).map { sIdx in
            let note = guitarOpenNotes.indices.contains(sIdx) ? guitarOpenNotes[sIdx].name : ""
            let cells = riff.steps.map { step -> TabCell in
                let has = step.string == sIdx
                return TabCell(fret: has ? step.fret : nil)
            }
            return TabRow(stringIndex: sIdx, noteName: note, cells: cells)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Header row ────────────────────────────────────────────
                    headerRow
                        .padding(.bottom, 18)

                    // ── Title + intro ─────────────────────────────────────────
                    Text("Read the riff")
                        .font(Typography.display(26))
                        .foregroundStyle(Theme.Palette.text)
                        .padding(.bottom, 8)

                    Text("Each number is a fret on that string. Watch the neck light up as the tab plays — that link is the whole skill.")
                        .font(Typography.body(14))
                        .foregroundStyle(Theme.Palette.textDim)
                        .lineSpacing(4)
                        .padding(.bottom, 22)

                    // ── Fretboard ─────────────────────────────────────────────
                    Text("FRETBOARD")
                        .sectionLabel()
                        .padding(.bottom, 8)

                    FretboardView(
                        geometry: FretboardGeometry(
                            stringCount: 6,
                            fretCount: 5,
                            startFret: 0,
                            isLeftHanded: model.isLeftHanded
                        ),
                        openNotes: guitarOpenNotes,
                        markers: lessonMarkers
                    )
                    .frame(height: 180)
                    .panel()
                    .padding(.bottom, 22)

                    // ── Tab staff ─────────────────────────────────────────────
                    tabStaff
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 100) // room for transport bar
            }

            // ── Transport bar (floated at bottom) ─────────────────────────
            VStack {
                Spacer()
                transportBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Header row

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("STAGE 02 · TABS")
                    .sectionLabel()
                Text("Lesson 2.3")
                    .font(Typography.display(16, weight: .semibold))
                    .foregroundStyle(Theme.Palette.text)
            }
            Spacer()
            Text("3 / 6")
                .font(Typography.mono(11, weight: .semibold))
                .foregroundStyle(Theme.Palette.phosphor)
                .accessibilityLabel("Progress: lesson 3 of 6")
        }
    }

    // MARK: Tab staff

    private var tabStaff: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Label row
            HStack {
                Text("TABLATURE · \(riff.name)")
                    .sectionLabel()
                Spacer()
                Text("♩ = 110")
                    .font(Typography.mono(10))
                    .foregroundStyle(Theme.Palette.textDim)
            }
            .padding(.bottom, 8)

            // Staff panel
            VStack(spacing: 0) {
                ForEach(Array(tabRows.enumerated()), id: \.offset) { _, row in
                    TabRowView(row: row)
                        .frame(height: 28)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .background(Theme.Palette.panel, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: 1)
            )
        }
    }

    // MARK: Transport bar

    private var transportBar: some View {
        HStack(spacing: 16) {
            // Step readout
            VStack(spacing: 2) {
                Text(isPlaying ? "--" : "--")
                    .font(Typography.mono(22, weight: .bold))
                    .foregroundStyle(Theme.Palette.phosphor)
                    .glow(Theme.Palette.phosphor, radius: 10)
                    .accessibilityLabel(isPlaying ? "Playing" : "Stopped")
                Text("STEP")
                    .font(Typography.mono(9))
                    .tracking(1.0)
                    .foregroundStyle(Theme.Palette.textDim)
            }
            .frame(minWidth: 44)

            // Play / Stop button
            Button {
                isPlaying.toggle()
                // TODO: wire AudioEngine + step sync in Phase 5
            } label: {
                Text(isPlaying ? "■  Stop" : "▶  Play riff")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel(isPlaying ? "Stop riff" : "Play riff")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .padding(.bottom, 16)
        .background(
            Theme.Palette.panelDeep
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Theme.Palette.hairline),
                    alignment: .top
                )
        )
    }
}

// MARK: - Tab data models

private struct TabRow {
    let stringIndex: Int
    let noteName: String
    let cells: [TabCell]
}

private struct TabCell {
    /// nil means this step doesn't land on this string.
    let fret: Int?
}

// MARK: - TabRowView

private struct TabRowView: View {
    let row: TabRow

    var body: some View {
        HStack(spacing: 10) {
            // Open-string note name
            Text(row.noteName)
                .font(Typography.mono(11, weight: .semibold))
                .foregroundStyle(Color(oklchL: 0.6, c: 0.04, h: 160).opacity(0.8))
                .frame(width: 14, alignment: .center)

            // Horizontal string line with 12 evenly-spaced columns
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    // The string line
                    Rectangle()
                        .fill(Color(oklchL: 0.5, c: 0.03, h: 160).opacity(0.22))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                    // 12 columns, one per riff step
                    HStack(spacing: 0) {
                        ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                            ZStack {
                                if let fret = cell.fret {
                                    Text("\(fret)")
                                        .font(Typography.mono(13, weight: .bold))
                                        .foregroundStyle(Color(oklchL: 0.88, c: 0.02, h: 220))
                                        .frame(minWidth: 22, alignment: .center)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color(oklchL: 0.17, c: 0.016, h: 250))
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }
}
