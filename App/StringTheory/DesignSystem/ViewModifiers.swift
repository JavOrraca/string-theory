import SwiftUI

extension View {
    /// Phosphor-style glow used on active markers, primary buttons, and meters.
    func glow(_ color: Color, radius: CGFloat = 12) -> some View {
        shadow(color: color.opacity(0.55), radius: radius)
            .shadow(color: color.opacity(0.40), radius: radius / 3)
    }

    /// Standard rounded panel surface with a hairline border.
    func panel(cornerRadius: CGFloat = 16) -> some View {
        padding(16)
            .background(Theme.Palette.panel, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: 1)
            )
    }

    /// A monospaced, wide-tracked section label (e.g. "STAGE 04 · SCALES & KEYS").
    func sectionLabel() -> some View {
        font(Typography.mono(10, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(Theme.Palette.textDim)
            .textCase(.uppercase)
    }
}

/// The app's near-black background with a subtle top phosphor glow and the
/// faint scanline texture from the prototype.
struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.Palette.void
            RadialGradient(
                colors: [Theme.Palette.phosphor.opacity(0.05), .clear],
                center: .top, startRadius: 0, endRadius: 420
            )
            GeometryReader { geo in
                Path { path in
                    var y: CGFloat = 0
                    while y < geo.size.height {
                        path.addRect(CGRect(x: 0, y: y, width: geo.size.width, height: 1))
                        y += 3
                    }
                }
                .fill(Color.black.opacity(0.16))
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

/// A top-trailing settings gear that opens the Settings sheet. For screens that
/// are not inside a NavigationStack (the Chords / Scales / Solo tabs); Home and
/// the lesson screen have their own gear.
private struct SettingsGearModifier: ViewModifier {
    @State private var show = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                Button { show = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Palette.textDim)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Setup")
                .padding(.trailing, 8)
            }
            .sheet(isPresented: $show) { SettingsView() }
    }
}

extension View {
    func settingsGear() -> some View { modifier(SettingsGearModifier()) }
}
