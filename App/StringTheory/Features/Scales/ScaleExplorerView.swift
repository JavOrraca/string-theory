import SwiftUI
import StringTheoryCore

/// Scale Explorer — Phase 4.
/// Horizontally scrolling key chips, wrapping scale-type chips, a live 12-fret
/// neck, scale-degree chips, and a "Chords that live here" diatonic panel.
struct ScaleExplorerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.top, 58)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 12)

                    VStack(alignment: .leading, spacing: 0) {
                        keySelector
                        scaleTypeSelector
                        fretboard
                        scaleDegrees
                        relatedChordsPanel
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("STAGE 04 · SCALES & KEYS")
                .sectionLabel()
            HStack(alignment: .lastTextBaseline) {
                Text("Scale Explorer")
                    .font(Typography.display(28))
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
                Text("\(model.scaleKey.name) \(model.scaleType.label)")
                    .font(Typography.mono(13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.signalCyan)
                    .accessibilityLabel("Current scale: \(model.scaleKey.name) \(model.scaleType.label)")
            }
        }
    }

    // MARK: - Key Selector

    private var keySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KEY")
                .font(Typography.mono(10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Color(oklchL: 0.58, c: 0.02, h: 230))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Note.allCases, id: \.self) { note in
                        let isSelected = note == model.scaleKey
                        Button {
                            model.scaleKey = note
                        } label: {
                            Text(note.name)
                                .font(Typography.mono(13, weight: .semibold))
                                .foregroundStyle(
                                    isSelected
                                        ? Color(oklchL: 0.18, c: 0.03, h: 220)
                                        : Color(oklchL: 0.78, c: 0.02, h: 230)
                                )
                                .frame(minWidth: 38, minHeight: 44)
                                .padding(.horizontal, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(isSelected ? Theme.Palette.signalCyan : Color(oklchL: 0.2, c: 0.018, h: 250))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9)
                                        .strokeBorder(
                                            isSelected ? Theme.Palette.signalCyan : Color(oklchL: 0.5, c: 0.03, h: 200, opacity: 0.16),
                                            lineWidth: 1
                                        )
                                )
                                .glow(isSelected ? Theme.Palette.signalCyan : .clear, radius: isSelected ? 12 : 0)
                        }
                        .accessibilityLabel("Key \(note.name)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Scale Type Selector

    private var scaleTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCALE")
                .font(Typography.mono(10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Color(oklchL: 0.58, c: 0.02, h: 230))

            FlowLayout(spacing: 7) {
                ForEach(ScaleType.allCases, id: \.self) { scaleType in
                    let isSelected = scaleType == model.scaleType
                    Button {
                        model.scaleType = scaleType
                    } label: {
                        Text(scaleType.label)
                            .font(Typography.display(13, weight: .semibold))
                            .foregroundStyle(
                                isSelected ? Theme.Palette.phosphor : Color(oklchL: 0.78, c: 0.02, h: 230)
                            )
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(
                                        isSelected
                                            ? Theme.Palette.phosphor.opacity(0.16)
                                            : Color(oklchL: 0.2, c: 0.018, h: 250)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .strokeBorder(
                                        isSelected ? Theme.Palette.phosphor : Color(oklchL: 0.5, c: 0.03, h: 160, opacity: 0.16),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .accessibilityLabel("Scale \(scaleType.label)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Fretboard

    private var fretboard: some View {
        FretboardView(
            geometry: FretboardGeometry(
                stringCount: model.stringCount,
                fretCount: 12,
                isLeftHanded: model.isLeftHanded
            ),
            openNotes: model.openNotes,
            markers: scaleMarkers(
                instrument: model.instrument,
                key: model.scaleKey,
                scale: model.scaleType,
                frets: 12
            )
        )
        .frame(height: 200)
        .padding(1)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(oklchL: 0.17, c: 0.016, h: 250))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(oklchL: 0.5, c: 0.03, h: 160, opacity: 0.16), lineWidth: 1)
        )
        .padding(.bottom, 20)
        .accessibilityLabel("Fretboard showing \(model.scaleKey.name) \(model.scaleType.label) scale")
    }

    // MARK: - Scale Degrees

    private var scaleDegrees: some View {
        let degrees = scaleMap(key: model.scaleKey, scale: model.scaleType)
            .sorted { $0.value.interval < $1.value.interval }

        return VStack(alignment: .leading, spacing: 9) {
            Text("SCALE DEGREES")
                .font(Typography.mono(10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Color(oklchL: 0.58, c: 0.02, h: 230))

            FlowLayout(spacing: 7) {
                ForEach(degrees, id: \.key) { note, degree in
                    let isRoot = note == model.scaleKey
                    VStack(spacing: 3) {
                        Text(degree.label)
                            .font(Typography.mono(10, weight: .semibold))
                            .foregroundStyle(
                                isRoot
                                    ? Theme.Palette.signalCyan
                                    : Color(oklchL: 0.6, c: 0.04, h: 160, opacity: 0.9)
                            )
                        Text(note.name)
                            .font(Typography.display(16, weight: .bold))
                            .foregroundStyle(
                                isRoot ? Theme.Palette.signalCyan : Theme.Palette.text
                            )
                    }
                    .padding(.vertical, 9)
                    .frame(minWidth: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 11)
                            .fill(
                                isRoot
                                    ? Theme.Palette.signalCyan.opacity(0.16)
                                    : Color(oklchL: 0.19, c: 0.018, h: 250)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(
                                isRoot ? Theme.Palette.signalCyan : Color(oklchL: 0.5, c: 0.03, h: 160, opacity: 0.16),
                                lineWidth: 1
                            )
                    )
                    .accessibilityLabel("Degree \(degree.label), note \(note.name)\(isRoot ? ", root" : "")")
                }
            }
        }
        .padding(.bottom, 18)
    }

    // MARK: - Related Chords Panel

    private var relatedChordsPanel: some View {
        let notes = Note.allCases
        let rootIndex = notes.firstIndex(of: model.scaleKey) ?? 0
        let at: (Int) -> String = { semitones in
            notes[(rootIndex + semitones) % notes.count].name
        }
        let isMinor = model.scaleType.isMinor
        let chordsText = isMinor
            ? "\(at(0))m · \(at(5))m · \(at(7))m"
            : "\(at(0)) · \(at(5)) · \(at(7))"

        return HStack {
            Text("Chords that live here")
                .font(Typography.body(13))
                .foregroundStyle(Color(oklchL: 0.7, c: 0.02, h: 230))
            Spacer()
            Text(chordsText)
                .font(Typography.mono(15, weight: .semibold))
                .foregroundStyle(Theme.Palette.phosphor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(Color(oklchL: 0.17, c: 0.016, h: 250))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(Color(oklchL: 0.5, c: 0.03, h: 160, opacity: 0.16), lineWidth: 1)
        )
        .accessibilityLabel("Chords in \(model.scaleKey.name) \(model.scaleType.label): \(chordsText)")
    }
}

// MARK: - FlowLayout

/// A simple left-aligned wrapping layout for chip rows.
/// Used for scale type chips and scale degree chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                totalHeight += rowHeight + spacing
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
