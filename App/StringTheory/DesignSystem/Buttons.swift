import SwiftUI

/// The prototype's primary action button — solid phosphor with a soft glow.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.display(16, weight: .bold))
            .foregroundStyle(Color(oklchL: 0.16, c: 0.03, h: 150)) // dark ink on phosphor
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 8)
            .background(Theme.Palette.phosphor, in: RoundedRectangle(cornerRadius: 14))
            .glow(Theme.Palette.phosphor, radius: 18)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Outline button for secondary actions (for example "Back to Main").
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.display(16, weight: .semibold))
            .foregroundStyle(Theme.Palette.phosphor)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.Palette.phosphor.opacity(0.6), lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
