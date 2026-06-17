import SwiftUI
import StringTheoryCore

/// Stage lesson detail. Shows the tapped stage's header plus, for now, one
/// shared interactive fretboard: as the riff plays, the current note lights up
/// on the neck and the matching tab column highlights in time with the pluck.
struct LessonView: View {
    let stageNumber: String
    let stageTitle: String
    let stageSubtitle: String

    @Environment(AppModel.self) private var model

    private let riff = Riff.drift

    private var guitarOpenNotes: [Note] { Tuning.guitar.strings.map(\.note) }

    /// Riff markers — the current step is `.active`, the rest `.safe` (de-duped).
    private var lessonMarkers: [Marker] {
        let activeStep = model.riffStep
        var seen: [String: Marker] = [:]
        for (i, step) in riff.steps.enumerated() {
            let key = "\(step.string):\(step.fret)"
            if i == activeStep {
                seen[key] = Marker(string: step.string, fret: step.fret, kind: .active)
            } else if seen[key] == nil {
                seen[key] = Marker(string: step.string, fret: step.fret, kind: .safe)
            }
        }
        return Array(seen.values)
    }

    /// Tab rows high string (5) → low string (0); each carries one cell per step.
    private var tabRows: [TabRow] {
        let activeStep = model.riffStep
        return stride(from: 5, through: 0, by: -1).map { sIdx in
            let note = guitarOpenNotes.indices.contains(sIdx) ? guitarOpenNotes[sIdx].name : ""
            let cells = riff.steps.enumerated().map { i, step -> TabCell in
                let has = step.string == sIdx
                return TabCell(fret: has ? step.fret : nil, isActive: has && i == activeStep)
            }
            return TabRow(stringIndex: sIdx, noteName: note, cells: cells)
        }
    }

    private var stepReadout: String {
        if let step = model.riffStep { return String(format: "%02d", step + 1) }
        return "--"
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow.padding(.bottom, 18)

                    Text(stageTitle)
                        .font(Typography.display(26))
                        .foregroundStyle(Theme.Palette.text)
                        .padding(.bottom, 8)

                    Text(stageSubtitle)
                        .font(Typography.body(14))
                        .foregroundStyle(Theme.Palette.textDim)
                        .lineSpacing(4)
                        .padding(.bottom, 6)

                    Text("Full per-stage lessons are on the way. For now, here is an interactive fretboard. Press play to watch the notes light up on the neck and the tab in time.")
                        .font(Typography.body(13))
                        .foregroundStyle(Theme.Palette.textDim)
                        .lineSpacing(4)
                        .padding(.bottom, 22)

                    Text("FRETBOARD").sectionLabel().padding(.bottom, 8)

                    FretboardView(
                        geometry: FretboardGeometry(stringCount: 6, fretCount: 5, startFret: 0, isLeftHanded: model.isLeftHanded),
                        openNotes: guitarOpenNotes,
                        markers: lessonMarkers
                    )
                    .frame(height: 180)
                    .panel()
                    .padding(.bottom, 22)

                    tabStaff.padding(.bottom, 28)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 100) // room for the transport bar
            }

            VStack { Spacer(); transportBar }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Header

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("STAGE \(stageNumber)").sectionLabel()
            Spacer()
        }
    }

    // MARK: Tab staff

    private var tabStaff: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("TABLATURE · \(riff.name)").sectionLabel()
                Spacer()
                Text("♩ = 110").font(Typography.mono(10)).foregroundStyle(Theme.Palette.textDim)
            }
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(tabRows.enumerated()), id: \.offset) { _, row in
                    TabRowView(row: row).frame(height: 28)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .background(Theme.Palette.panel, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.Palette.hairline, lineWidth: 1))
        }
    }

    // MARK: Transport

    private var transportBar: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(stepReadout)
                    .font(Typography.mono(22, weight: .bold))
                    .foregroundStyle(Theme.Palette.phosphor)
                    .glow(Theme.Palette.phosphor, radius: 10)
                    .contentTransition(.numericText())
                Text("STEP")
                    .font(Typography.mono(9)).tracking(1.0)
                    .foregroundStyle(Theme.Palette.textDim)
            }
            .frame(minWidth: 44)

            Button {
                model.toggleRiff()
            } label: {
                Text(model.isPlayingRiff ? "■  Stop" : "▶  Play riff")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel(model.isPlayingRiff ? "Stop riff" : "Play riff")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .padding(.bottom, 16)
        .background(
            Theme.Palette.panelDeep
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Theme.Palette.hairline), alignment: .top)
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
    let isActive: Bool
}

private struct TabRowView: View {
    let row: TabRow

    var body: some View {
        HStack(spacing: 10) {
            Text(row.noteName)
                .font(Typography.mono(11, weight: .semibold))
                .foregroundStyle(Color(oklchL: 0.6, c: 0.04, h: 160).opacity(0.8))
                .frame(width: 14, alignment: .center)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(oklchL: 0.5, c: 0.03, h: 160).opacity(0.22))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                    HStack(spacing: 0) {
                        ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                            ZStack {
                                if let fret = cell.fret {
                                    Text("\(fret)")
                                        .font(Typography.mono(13, weight: .bold))
                                        .foregroundStyle(cell.isActive ? Color(oklchL: 0.16, c: 0.03, h: 150) : Color(oklchL: 0.88, c: 0.02, h: 220))
                                        .frame(minWidth: 22, alignment: .center)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(cell.isActive ? Theme.Palette.phosphor : Color(oklchL: 0.17, c: 0.016, h: 250))
                                        )
                                        .glow(cell.isActive ? Theme.Palette.phosphor : .clear, radius: cell.isActive ? 10 : 0)
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
