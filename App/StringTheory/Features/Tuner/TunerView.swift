import SwiftUI
import StringTheoryCore

/// The microphone tuner. Shows a flat-to-sharp needle for the detected pitch, the
/// nearest string and cents, and a strip of open strings you can tap to hear a
/// reference tone. Starts tuning on appear and stops on disappear, so leaving the
/// screen never leaves the mic running. If the mic is denied it stays usable as
/// reference tones only.
struct TunerView: View {
    @Environment(AppModel.self) private var model

    private var strings: [OpenString] { model.tuning.strings }
    private var reading: TunerReading { model.tunerReading }
    private var inTune: Bool { reading.isVoiced && abs(reading.cents) <= 5 }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 22) {
                header
                needleCard
                referenceStrip
                if model.micGranted == false { micDeniedBanner }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .onAppear { model.beginTuning() }
        .onDisappear { model.endTuning() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TUNER · \(model.instrument == .bass ? "BASS" : "GUITAR")").sectionLabel()
            Text("Tune up")
                .font(Typography.display(28))
                .foregroundStyle(Theme.Palette.text)
        }
    }

    // The detected note, the cents readout, and a moving needle clamped to +/-50.
    private var needleCard: some View {
        VStack(spacing: 14) {
            Text(reading.isVoiced ? strings[safe: reading.stringIndex]?.note.name ?? "--" : "--")
                .font(Typography.display(64))
                .foregroundStyle(inTune ? Theme.Palette.phosphor : Theme.Palette.text)
                .glow(inTune ? Theme.Palette.phosphor : .clear, radius: inTune ? 14 : 0)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.15), value: reading.stringIndex)

            Text(reading.isVoiced ? centsLabel : "play a string")
                .font(Typography.mono(13, weight: .semibold))
                .foregroundStyle(reading.isVoiced ? (inTune ? Theme.Palette.phosphor : amber) : Theme.Palette.textDim)

            NeedleView(cents: reading.isVoiced ? reading.cents : nil, inTune: inTune, amber: amber)
                .frame(height: 56)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Theme.Palette.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.Palette.hairline, lineWidth: 1))
    }

    private var centsLabel: String {
        let c = Int(reading.cents.rounded())
        if abs(c) <= 5 { return "in tune" }
        return c > 0 ? "+\(c) cents · sharp" : "\(c) cents · flat"
    }

    private var referenceStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REFERENCE · TAP TO HEAR").sectionLabel()
            HStack(spacing: 8) {
                ForEach(Array(strings.enumerated()), id: \.offset) { index, string in
                    let isNear = reading.isVoiced && reading.stringIndex == index
                    Button { model.playReferenceTone(stringIndex: index) } label: {
                        Text(string.note.name)
                            .font(Typography.display(17, weight: .semibold))
                            .foregroundStyle(isNear ? Color(oklchL: 0.16, c: 0.03, h: 150) : Theme.Palette.text)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(RoundedRectangle(cornerRadius: 10).fill(isNear ? Theme.Palette.phosphor : Color(oklchL: 0.2, c: 0.018, h: 250)))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isNear ? Theme.Palette.phosphor : Theme.Palette.hairline, lineWidth: 1))
                            .glow(isNear ? Theme.Palette.phosphor : .clear, radius: isNear ? 10 : 0)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeOut(duration: 0.12), value: isNear)
                    .accessibilityLabel("Play reference \(string.note.name)")
                }
            }
        }
    }

    private var micDeniedBanner: some View {
        Text("Microphone access is off, so the needle is disabled. You can still tune by ear with the reference tones. Enable the mic in iOS Settings to use the needle.")
            .font(Typography.body(12))
            .foregroundStyle(Theme.Palette.textDim)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .background(Theme.Palette.panelDeep, in: RoundedRectangle(cornerRadius: 12))
    }

    private var amber: Color { Color(oklchL: 0.8, c: 0.13, h: 70) }
}

/// The flat-to-sharp meter: a track with a center mark and a dot at the cents
/// position. When `cents` is nil (idle) the dot rests at center, dimmed.
private struct NeedleView: View {
    let cents: Double?
    let inTune: Bool
    let amber: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, midX = w / 2, midY = geo.size.height / 2
            let clamped = max(-50, min(50, cents ?? 0))
            let x = midX + CGFloat(clamped / 50) * (w / 2 - 16)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.hairline).frame(height: 2).position(x: midX, y: midY)
                Rectangle().fill(Theme.Palette.phosphor.opacity(0.6)).frame(width: 2, height: 22).position(x: midX, y: midY)
                Circle()
                    .fill(cents == nil ? Theme.Palette.textDim.opacity(0.4) : (inTune ? Theme.Palette.phosphor : amber))
                    .frame(width: 18, height: 18)
                    .glow(cents == nil ? .clear : (inTune ? Theme.Palette.phosphor : amber), radius: 8)
                    .position(x: x, y: midY)
                    .animation(.easeOut(duration: 0.12), value: x)
                Text("♭").font(Typography.mono(13)).foregroundStyle(Theme.Palette.textDim).position(x: 10, y: midY)
                Text("♯").font(Typography.mono(13)).foregroundStyle(Theme.Palette.textDim).position(x: w - 10, y: midY)
            }
        }
    }
}

/// Safe indexed access for the reading's string index.
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
