import SwiftUI
import StringTheoryCore

/// Solo Practice — the payoff screen (Stage 05 · Improvisation). KEY/SCALE
/// selectors, a live neck of safe notes, the backing progression, and an audio
/// transport. As the backing loop plays, the current chord highlights and its
/// root pulses bright on the neck.
struct SoloPracticeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack(alignment: .bottom) {
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
                        legend
                        backingLoop
                    }
                    .padding(.horizontal, 22)

                    Spacer().frame(height: 110) // clear the fixed transport bar
                }
            }

            transportBar
        }
    }

    // MARK: - Markers (safe notes; the active chord's root pulses)

    private var soloMarkers: [Marker] {
        let activeRoot = model.activeBackingRoot
        return scaleMarkers(instrument: model.instrument, key: model.soloKey, scale: model.soloScale, frets: 12)
            .map { marker in
                if let activeRoot, marker.note == activeRoot {
                    return Marker(string: marker.string, fret: marker.fret, kind: .active, note: marker.note, label: marker.label)
                }
                return marker
            }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("STAGE 05 · IMPROVISATION").sectionLabel()
            Text("Solo Practice")
                .font(Typography.display(28))
                .foregroundStyle(Theme.Palette.text)
        }
    }

    // MARK: - KEY Selector

    private var keySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KEY")
                .font(Typography.mono(10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Color(oklchL: 0.58, c: 0.02, h: 230))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Note.allCases, id: \.self) { note in
                        let isSelected = note == model.soloKey
                        Button {
                            model.setSoloKey(note)
                        } label: {
                            Text(note.name)
                                .font(Typography.mono(13, weight: .semibold))
                                .foregroundStyle(isSelected ? Color(oklchL: 0.18, c: 0.03, h: 220) : Color(oklchL: 0.78, c: 0.02, h: 230))
                                .frame(minWidth: 38, minHeight: 44)
                                .padding(.horizontal, 4)
                                .background(RoundedRectangle(cornerRadius: 9).fill(isSelected ? Theme.Palette.signalCyan : Color(oklchL: 0.2, c: 0.018, h: 250)))
                                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(isSelected ? Theme.Palette.signalCyan : Color(oklchL: 0.5, c: 0.03, h: 200, opacity: 0.16), lineWidth: 1))
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

    // MARK: - SCALE Selector

    private var scaleTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCALE")
                .font(Typography.mono(10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Color(oklchL: 0.58, c: 0.02, h: 230))

            FlowLayout(spacing: 7) {
                ForEach(ScaleType.allCases, id: \.self) { scaleType in
                    let isSelected = scaleType == model.soloScale
                    Button {
                        model.setSoloScale(scaleType)
                    } label: {
                        Text(scaleType.label)
                            .font(Typography.display(13, weight: .semibold))
                            .foregroundStyle(isSelected ? Theme.Palette.phosphor : Color(oklchL: 0.78, c: 0.02, h: 230))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: 9).fill(isSelected ? Theme.Palette.phosphor.opacity(0.16) : Color(oklchL: 0.2, c: 0.018, h: 250)))
                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(isSelected ? Theme.Palette.phosphor : Color(oklchL: 0.5, c: 0.03, h: 160, opacity: 0.16), lineWidth: 1))
                            .glow(isSelected ? Theme.Palette.phosphor : .clear, radius: isSelected ? 10 : 0)
                    }
                    .accessibilityLabel("Scale \(scaleType.label)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .padding(.bottom, 18)
    }

    // MARK: - Fretboard

    private var fretboard: some View {
        FretboardView(
            geometry: FretboardGeometry(stringCount: model.stringCount, fretCount: 12, isLeftHanded: model.isLeftHanded),
            openNotes: model.openNotes,
            markers: soloMarkers
        )
        .frame(height: 208)
        .padding(1)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(oklchL: 0.17, c: 0.016, h: 250)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(oklchL: 0.5, c: 0.03, h: 160, opacity: 0.16), lineWidth: 1))
        .padding(.bottom, 14)
        .accessibilityLabel("Fretboard showing \(model.soloKey.name) \(model.soloScale.label) — all safe notes highlighted")
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(alignment: .center, spacing: 9) {
            Circle()
                .fill(Theme.Palette.phosphor.opacity(0.13))
                .overlay(Circle().strokeBorder(Theme.Palette.phosphor, lineWidth: 1.5))
                .frame(width: 14, height: 14)
                .glow(Theme.Palette.phosphor, radius: 6)
            Text("Every glowing note is safe over this backing track.")
                .font(Typography.body(13))
                .foregroundStyle(Color(oklchL: 0.68, c: 0.02, h: 230))
        }
        .padding(.bottom, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Legend: glowing notes are safe to play over the backing track")
    }

    // MARK: - Backing Loop

    private var backingLoop: some View {
        let chords = backingProgression(key: model.soloKey, scale: model.soloScale)

        return VStack(alignment: .leading, spacing: 9) {
            Text("BACKING LOOP")
                .font(Typography.mono(10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Color(oklchL: 0.58, c: 0.02, h: 230))

            HStack(spacing: 7) {
                ForEach(Array(chords.enumerated()), id: \.offset) { index, chord in
                    let isActive = model.backingChordIndex == index
                    Text(chord.name)
                        .font(Typography.display(15, weight: .semibold))
                        .foregroundStyle(isActive ? Color(oklchL: 0.16, c: 0.03, h: 150) : Theme.Palette.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 9).fill(isActive ? Theme.Palette.phosphor : Color(oklchL: 0.2, c: 0.018, h: 250)))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(isActive ? Theme.Palette.phosphor : Color(oklchL: 0.5, c: 0.03, h: 160, opacity: 0.16), lineWidth: 1))
                        .glow(isActive ? Theme.Palette.phosphor : .clear, radius: isActive ? 12 : 0)
                        .animation(.easeOut(duration: 0.12), value: isActive)
                        .accessibilityLabel("Chord \(chord.name)")
                }
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Transport Bar

    private var transportBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color(oklchL: 0.5, c: 0.03, h: 160, opacity: 0.16))

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .center, spacing: 2) {
                    Text(model.soloKey.name)
                        .font(Typography.display(22, weight: .bold))
                        .foregroundStyle(Theme.Palette.phosphor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("KEY · \(model.soloScale.label)")
                        .font(Typography.mono(9, weight: .medium))
                        .tracking(1.0)
                        .foregroundStyle(Color(oklchL: 0.58, c: 0.02, h: 230))
                }
                .frame(minWidth: 54)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Current key: \(model.soloKey.name), scale: \(model.soloScale.label)")

                Button {
                    model.toggleBacking()
                } label: {
                    Text(model.isPlayingBacking ? "■  Stop" : "▶  Play backing")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel(model.isPlayingBacking ? "Stop backing track" : "Play backing track")
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 30)
            .background(Theme.Palette.panelDeep)
        }
    }
}

// MARK: - FlowLayout

/// Left-aligned wrapping chip layout.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                totalHeight += rowHeight + spacing
                currentX = 0
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
