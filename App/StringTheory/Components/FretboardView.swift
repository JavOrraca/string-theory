import SwiftUI
import StringTheoryCore

/// Reusable fretboard renderer. The neck (strings, frets, nut, inlays) is drawn
/// with a SwiftUI `Canvas`; marker dots are overlaid as views so they get crisp
/// text and glows. Every position comes from the core's `FretboardGeometry`, so
/// 4/6 strings, handedness, and the fret window are handled by pure math.
///
/// Reused across Lesson, Chord Library, Scale Explorer, and Solo Practice.
struct FretboardView: View {
    let geometry: FretboardGeometry
    let openNotes: [Note]
    var markers: [Marker] = []
    var showStringLabels = true
    var showFretNumbers = true
    var showInlays = true

    private let labelColumnWidth: CGFloat = 22

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                if showStringLabels && !geometry.isLeftHanded { stringLabels }
                board
                if showStringLabels && geometry.isLeftHanded { stringLabels }
            }
            if showFretNumbers { fretNumberRow }
        }
    }

    // MARK: Board

    private var board: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Canvas { context, canvasSize in
                    drawStrings(in: &context, size: canvasSize)
                    drawFrets(in: &context, size: canvasSize)
                    if showInlays { drawInlays(in: &context, size: canvasSize) }
                }
                ForEach(Array(markers.enumerated()), id: \.offset) { _, marker in
                    let point = geometry.position(for: marker)
                    MarkerDot(marker: marker, diameter: markerDiameter(size))
                        .position(x: point.x / 100 * size.width,
                                  y: point.y / 100 * size.height)
                }
            }
        }
        .frame(minHeight: 120)
    }

    private func markerDiameter(_ size: CGSize) -> CGFloat {
        let spaceW = (geometry.span / 100) * size.width / CGFloat(max(1, geometry.fretCount))
        let gapH = ((100 - 2 * geometry.verticalPadding) / 100) * size.height
            / CGFloat(max(1, geometry.stringCount - 1))
        return min(max(min(spaceW, gapH) * 0.64, 13), 34)
    }

    private func drawStrings(in context: inout GraphicsContext, size: CGSize) {
        let color = Color(oklchL: 0.74, c: 0.04, h: 160).opacity(0.45)
        for i in 0..<geometry.stringCount {
            let y = geometry.stringY(i) / 100 * size.height
            let thickness = 0.8 + (CGFloat(geometry.stringCount - 1 - i)
                / CGFloat(max(1, geometry.stringCount - 1))) * 1.4
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(color), lineWidth: thickness)
        }
    }

    private func drawFrets(in context: inout GraphicsContext, size: CGSize) {
        let top = (geometry.verticalPadding - 2) / 100 * size.height
        let bottom = (100 - (geometry.verticalPadding - 2)) / 100 * size.height
        let normal = Color(oklchL: 0.62, c: 0.02, h: 200).opacity(0.32)
        let nut = Color(oklchL: 0.86, c: 0.06, h: 160).opacity(0.85)
        for col in 0...geometry.fretCount {
            let x = geometry.fretLineX(column: col) / 100 * size.width
            let isNut = geometry.isNut(column: col)
            var path = Path()
            path.move(to: CGPoint(x: x, y: top))
            path.addLine(to: CGPoint(x: x, y: bottom))
            context.stroke(path, with: .color(isNut ? nut : normal), lineWidth: isNut ? 2.5 : 1)
        }
    }

    private func drawInlays(in context: inout GraphicsContext, size: CGSize) {
        let color = Color(oklchL: 0.6, c: 0.03, h: 200).opacity(0.45)
        let dotSize: CGFloat = 5
        func dot(x: CGFloat, yPercent: CGFloat) {
            let rect = CGRect(x: x - dotSize / 2, y: yPercent / 100 * size.height - dotSize / 2,
                              width: dotSize, height: dotSize)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
        for col in 1...max(1, geometry.fretCount) {
            let absFret = geometry.startFret + col
            let x = geometry.fretCenterX(column: col) / 100 * size.width
            switch FretboardGeometry.inlay(forAbsoluteFret: absFret) {
            case .double: dot(x: x, yPercent: 36); dot(x: x, yPercent: 64)
            case .single: dot(x: x, yPercent: 50)
            case .none: break
            }
        }
    }

    // MARK: String labels & fret numbers

    private var stringLabels: some View {
        GeometryReader { proxy in
            ForEach(Array(0..<geometry.stringCount), id: \.self) { i in
                Text(openNotes.indices.contains(i) ? openNotes[i].name : "")
                    .font(Typography.mono(11, weight: .semibold))
                    .foregroundStyle(Color(oklchL: 0.7, c: 0.04, h: 160).opacity(0.7))
                    .position(x: proxy.size.width / 2,
                              y: geometry.stringY(i) / 100 * proxy.size.height)
            }
        }
        .frame(width: labelColumnWidth)
    }

    private var fretNumberRow: some View {
        HStack(spacing: 6) {
            if showStringLabels && !geometry.isLeftHanded { Spacer().frame(width: labelColumnWidth) }
            GeometryReader { proxy in
                ForEach(Array(1...max(1, geometry.fretCount)), id: \.self) { col in
                    Text("\(geometry.startFret + col)")
                        .font(Typography.mono(10))
                        .foregroundStyle(Color(oklchL: 0.6, c: 0.02, h: 200).opacity(0.6))
                        .position(x: geometry.fretCenterX(column: col) / 100 * proxy.size.width, y: 8)
                }
            }
            .frame(height: 16)
            if showStringLabels && geometry.isLeftHanded { Spacer().frame(width: labelColumnWidth) }
        }
    }
}

/// A single fretboard dot — the five marker kinds (plus `ghost`) with their glows.
private struct MarkerDot: View {
    let marker: Marker
    let diameter: CGFloat

    var body: some View {
        let green = Theme.Palette.phosphor
        let cyan = Theme.Palette.signalCyan
        let red = Theme.Palette.warning

        switch marker.kind {
        case .muted:
            Text("\u{00D7}")
                .font(Typography.mono(diameter * 0.7, weight: .bold))
                .foregroundStyle(red)
                .frame(width: diameter * 0.66, height: diameter * 0.66)
        case .ghost:
            Circle()
                .fill(Color(oklchL: 0.6, c: 0.02, h: 200).opacity(0.35))
                .frame(width: diameter * 0.4, height: diameter * 0.4)
        case .root:
            dot(fill: cyan, ink: Color(oklchL: 0.18, c: 0.03, h: 220), glow: cyan, border: nil)
        case .active:
            dot(fill: green, ink: Color(oklchL: 0.16, c: 0.03, h: 150), glow: green, border: nil)
        case .open:
            dot(fill: .clear, ink: green, glow: green.opacity(0.4), border: green)
        case .safe:
            dot(fill: green.opacity(0.13), ink: green, glow: green.opacity(0.35), border: green)
        }
    }

    @ViewBuilder
    private func dot(fill: Color, ink: Color, glow: Color, border: Color?) -> some View {
        Text(marker.label ?? "")
            .font(Typography.mono(diameter * 0.44, weight: .semibold))
            .foregroundStyle(ink)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(fill))
            .overlay {
                if let border { Circle().strokeBorder(border, lineWidth: 1.5) }
            }
            .glow(glow, radius: diameter * 0.4)
    }
}
