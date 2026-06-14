import SwiftUI

/// Temporary stand-in for the real `FretboardView` (Phase 3). Keeps the screen
/// layouts honest about where the neck sits.
struct FretboardPlaceholder: View {
    var height: CGFloat = 180

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Theme.Palette.panel)
            Text("FRETBOARD")
                .font(Typography.mono(11, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Theme.Palette.textDim)
        }
        .frame(height: height)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.Palette.hairline, lineWidth: 1))
    }
}
