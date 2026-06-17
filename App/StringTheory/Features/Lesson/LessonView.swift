import SwiftUI
import StringTheoryCore

/// Plays through a stage's lessons one at a time. Each lesson fits the screen
/// (no scrolling); finishing one shows a Completed state with Next / Back to
/// Main, and completing a stage's lessons advances the path. A settings gear is
/// in the top-right so tempo and setup are reachable from inside a lesson.
struct StageLessonsView: View {
    let stage: LearningStage

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var showSettings = false

    private var lesson: Lesson { stage.lessons[min(index, stage.lessons.count - 1)] }
    private var isLastLesson: Bool { index >= stage.lessons.count - 1 }
    private var lessonComplete: Bool { model.isLessonComplete(stageID: stage.id, lessonID: lesson.id) }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                footer
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .tint(Theme.Palette.phosphor)
                .accessibilityLabel("Setup")
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onChange(of: lesson.id) { model.stopRiff() }
        .onChange(of: model.riffGoalReached) { _, reached in
            if reached, !lessonComplete {
                model.markLessonComplete(stageID: stage.id, lessonID: lesson.id)
                model.stopRiff()
            }
        }
        .onDisappear { model.stopRiff() }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("STAGE \(stage.number)").sectionLabel()
                Spacer()
                if stage.lessons.count > 1 {
                    Text("LESSON \(index + 1) / \(stage.lessons.count)")
                        .font(Typography.mono(10, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(Theme.Palette.textDim)
                }
            }

            Text(lesson.title)
                .font(Typography.display(24))
                .foregroundStyle(Theme.Palette.text)

            Text(lesson.subtitle)
                .font(Typography.body(13))
                .foregroundStyle(Theme.Palette.textDim)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            switch lesson.kind {
            case .fretboardRiff:
                RiffLesson()
            case .reading(let body):
                Text(body)
                    .font(Typography.body(15))
                    .foregroundStyle(Theme.Palette.text)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: Footer

    @ViewBuilder private var footer: some View {
        if lessonComplete {
            completedBar
        } else {
            switch lesson.kind {
            case .fretboardRiff: transportBar
            case .reading:
                bottomBar {
                    Button("Continue") {
                        model.markLessonComplete(stageID: stage.id, lessonID: lesson.id)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }

    private var transportBar: some View {
        bottomBar {
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text(model.riffStep.map { String(format: "%02d", $0 + 1) } ?? "--")
                        .font(Typography.mono(22, weight: .bold))
                        .foregroundStyle(Theme.Palette.phosphor)
                        .glow(Theme.Palette.phosphor, radius: 10)
                        .contentTransition(.numericText())
                    Text("STEP")
                        .font(Typography.mono(9)).tracking(1.0)
                        .foregroundStyle(Theme.Palette.textDim)
                }
                .frame(minWidth: 44)

                Button { model.toggleRiff() } label: {
                    Text(model.isPlayingRiff ? "■  Stop" : "▶  Play riff")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel(model.isPlayingRiff ? "Stop riff" : "Play riff")
            }
        }
    }

    private var completedBar: some View {
        bottomBar {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Palette.phosphor)
                    Text("Lesson complete")
                        .font(Typography.display(15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.text)
                    Spacer()
                }
                HStack(spacing: 10) {
                    if isLastLesson {
                        Button("Back to Main") { back() }
                            .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button("Back to Main") { back() }
                            .buttonStyle(SecondaryButtonStyle())
                        Button("Next lesson") { goNext() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
        }
    }

    private func bottomBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
            .background(
                Theme.Palette.panelDeep
                    .overlay(Rectangle().frame(height: 1).foregroundStyle(Theme.Palette.hairline), alignment: .top)
            )
    }

    private func goNext() {
        model.stopRiff()
        if !isLastLesson { index += 1 }
    }

    private func back() {
        model.stopRiff()
        dismiss()
    }
}

// MARK: - Riff lesson content (fretboard + tab)

/// The interactive fretboard locked to a tab staff. As the riff plays, the
/// current note lights up on the neck and the matching tab column highlights.
private struct RiffLesson: View {
    @Environment(AppModel.self) private var model

    private let riff = Riff.drift
    private var guitarOpenNotes: [Note] { Tuning.guitar.strings.map(\.note) }

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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FretboardView(
                geometry: FretboardGeometry(stringCount: 6, fretCount: 5, startFret: 0, isLeftHanded: model.isLeftHanded),
                openNotes: guitarOpenNotes,
                markers: lessonMarkers
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .panel()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("TABLATURE · \(riff.name)").sectionLabel()
                    Spacer()
                    Text("♩ = 110").font(Typography.mono(10)).foregroundStyle(Theme.Palette.textDim)
                }
                VStack(spacing: 0) {
                    ForEach(Array(tabRows.enumerated()), id: \.offset) { _, row in
                        TabRowView(row: row).frame(height: 24)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.Palette.panel, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.Palette.hairline, lineWidth: 1))
            }
        }
    }
}

// MARK: - Tab data models

private struct TabRow {
    let stringIndex: Int
    let noteName: String
    let cells: [TabCell]
}

private struct TabCell {
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
