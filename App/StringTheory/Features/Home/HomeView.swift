import SwiftUI

// MARK: - Row view model

/// One row of the Signal Path, built from `LearningPath` plus the user's
/// persisted progress in `AppModel`.
private struct Stage {
    let number: String      // "01" ... "05"
    let title: String
    let sub: String
    let status: StageStatus
    let pct: Int            // 0...100
}

// MARK: - HomeView

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false

    private var rows: [Stage] {
        LearningPath.stages.map { stage in
            Stage(
                number: stage.number,
                title: stage.title,
                sub: stage.subtitle,
                status: model.status(for: stage),
                pct: Int((model.progress(forStage: stage.id) * 100).rounded())
            )
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HeaderSection(overallPercent: model.overallPercent, onSettings: { showSettings = true })
                            .padding(.bottom, 8)
                        StageListSection(stages: rows)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }
}

// MARK: - Header

private struct HeaderSection: View {
    let overallPercent: Int
    let onSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("STANDARD TUNING · 440Hz")
                    .sectionLabel()
                Spacer()
                Button(action: onSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Palette.textDim)
                        .frame(width: 44, height: 28, alignment: .trailing)
                }
                .accessibilityLabel("Setup")
            }

            HStack(alignment: .bottom) {
                Text("Your Path")
                    .font(Typography.display(30))
                    .foregroundStyle(Theme.Palette.text)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(overallPercent)%")
                        .font(Typography.display(26))
                        .foregroundStyle(Theme.Palette.phosphor)
                        .glow(Theme.Palette.phosphor, radius: 8)
                    Text("COMPLETE")
                        .font(Typography.mono(10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.Palette.textDim)
                }
            }
            .padding(.top, 6)

            // Overall progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999)
                        .fill(Color(oklchL: 0.20, c: 0.018, h: 250))
                    RoundedRectangle(cornerRadius: 999)
                        .fill(Theme.Palette.phosphor)
                        .frame(width: geo.size.width * CGFloat(overallPercent) / 100)
                        .glow(Theme.Palette.phosphor, radius: 6)
                }
            }
            .frame(height: 5)
            .padding(.top, 14)
        }
        .padding(.bottom, 20)
    }
}

// MARK: - Stage list

private struct StageListSection: View {
    let stages: [Stage]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.offset) { idx, stage in
                StageRow(stage: stage, isLast: idx == stages.count - 1)
            }
        }
    }
}

// MARK: - Individual stage row (node + connector + card)

private struct StageRow: View {
    let stage: Stage
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // Left column: node + connector line
            VStack(alignment: .center, spacing: 0) {
                NodeView(stage: stage)
                if !isLast {
                    ConnectorLine(status: stage.status)
                }
            }

            // Right column: card (the active stage pushes into the lesson)
            Group {
                switch stage.status {
                case .active:
                    NavigationLink(destination: LessonView()) {
                        StageCard(stage: stage)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stage \(stage.number): \(stage.title). \(stage.pct == 0 ? "Ready to start" : "In progress, \(stage.pct) percent complete"). Tap to begin.")
                case .done:
                    StageCard(stage: stage)
                        .accessibilityLabel("Stage \(stage.number): \(stage.title). Complete.")
                case .locked:
                    StageCard(stage: stage)
                        .accessibilityLabel("Stage \(stage.number): \(stage.title). Locked.")
                }
            }
            .padding(.bottom, 14)
        }
    }
}

// MARK: - Node circle

private struct NodeView: View {
    let stage: Stage

    private var nodeBackground: Color {
        switch stage.status {
        case .done:
            return Theme.Palette.phosphor
        case .active:
            return Color(oklchL: 0.185, c: 0.017, h: 250)
                .mix(with: Theme.Palette.signalCyan, by: 0.16)
        case .locked:
            return Color(oklchL: 0.18, c: 0.016, h: 250)
        }
    }

    private var nodeForeground: Color {
        switch stage.status {
        case .done:   return Color(oklchL: 0.16, c: 0.03, h: 150)
        case .active: return Theme.Palette.signalCyan
        case .locked: return Color(oklchL: 0.50, c: 0.02, h: 230)
        }
    }

    private var nodeBorderColor: Color {
        switch stage.status {
        case .done:   return .clear
        case .active: return Theme.Palette.signalCyan
        case .locked: return Theme.Palette.hairline
        }
    }

    private var glyphText: String {
        stage.status == .done ? "✓" : stage.number
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(nodeBackground)
            Circle()
                .strokeBorder(nodeBorderColor, lineWidth: stage.status == .done ? 0 : 1.5)

            Text(glyphText)
                .font(Typography.mono(15, weight: .bold))
                .foregroundStyle(nodeForeground)
        }
        .frame(width: 46, height: 46)
        .modifier(NodeGlowModifier(status: stage.status))
    }
}

private struct NodeGlowModifier: ViewModifier {
    let status: StageStatus
    func body(content: Content) -> some View {
        switch status {
        case .done:
            content.glow(Theme.Palette.phosphor, radius: 10)
        case .active:
            content.glow(Theme.Palette.signalCyan, radius: 12)
        case .locked:
            content
        }
    }
}

// MARK: - Connector line

private struct ConnectorLine: View {
    let status: StageStatus

    private var lineColor: Color {
        status == .done
            ? Theme.Palette.phosphor.opacity(0.50)
            : Color(oklchL: 0.50, c: 0.03, h: 160).opacity(0.18)
    }

    var body: some View {
        Rectangle()
            .fill(lineColor)
            .frame(width: 2)
            .frame(minHeight: 14)
            .cornerRadius(2)
    }
}

// MARK: - Stage card

private struct StageCard: View {
    let stage: Stage

    private var cardBackground: Color {
        switch stage.status {
        case .active:
            return Color(oklchL: 0.185, c: 0.017, h: 250)
                .mix(with: Theme.Palette.signalCyan, by: 0.07)
        default:
            return Color(oklchL: 0.185, c: 0.017, h: 250)
        }
    }

    private var borderColor: Color {
        switch stage.status {
        case .active: return Theme.Palette.signalCyan.opacity(0.40)
        default:      return Color(oklchL: 0.50, c: 0.03, h: 160).opacity(0.14)
        }
    }

    private var titleColor: Color {
        stage.status == .locked
            ? Color(oklchL: 0.62, c: 0.02, h: 230)
            : Theme.Palette.text
    }

    private var statusText: String {
        switch stage.status {
        case .done:   return "Complete"
        case .active: return stage.pct == 0 ? "Start" : "In progress · \(stage.pct)%"
        case .locked: return "Locked"
        }
    }

    private var statusColor: Color {
        switch stage.status {
        case .done:   return Theme.Palette.phosphor
        case .active: return Theme.Palette.signalCyan
        case .locked: return Color(oklchL: 0.50, c: 0.02, h: 230)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text(stage.title)
                    .font(Typography.display(17, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(statusText)
                    .font(Typography.mono(10.5, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(statusColor)
                    .fixedSize()
            }

            Text(stage.sub)
                .font(Typography.body(13))
                .foregroundStyle(Color(oklchL: 0.64, c: 0.02, h: 230))
                .lineSpacing(4)
                .padding(.top, 5)

            if stage.status == .done || (stage.status == .active && stage.pct > 0) {
                ProgressMeterView(pct: stage.pct, status: stage.status)
                    .padding(.top, 11)
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 15))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .opacity(stage.status == .locked ? 0.62 : 1.0)
    }
}

// MARK: - Progress meter

private struct ProgressMeterView: View {
    let pct: Int
    let status: StageStatus

    private var fillColor: Color {
        status == .active ? Theme.Palette.signalCyan : Theme.Palette.phosphor
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color(oklchL: 0.22, c: 0.018, h: 250))
                RoundedRectangle(cornerRadius: 999)
                    .fill(fillColor)
                    .frame(width: geo.size.width * CGFloat(pct) / 100)
                    .glow(fillColor, radius: 6)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Color.mix helper (iOS 17 compatibility shim)
// SwiftUI's Color.mix(with:by:) is iOS 18+. We replicate it by blending in sRGB,
// which is indistinguishable from OKLCH at the small fractions used here.

private extension Color {
    func mix(with other: Color, by fraction: Double) -> Color {
        let f = max(0, min(1, fraction))
        let inv = 1.0 - f
        return Color(uiColor: {
            let a = UIColor(self)
            let b = UIColor(other)
            var (r1, g1, b1, a1) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
            var (r2, g2, b2, a2) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
            a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            return UIColor(
                red:   r1 * inv + r2 * f,
                green: g1 * inv + g2 * f,
                blue:  b1 * inv + b2 * f,
                alpha: a1 * inv + a2 * f
            )
        }())
    }
}
