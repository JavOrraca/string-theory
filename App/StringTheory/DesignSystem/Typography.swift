import SwiftUI
import UIKit

/// Type roles from the prototype, backed by the bundled OFL fonts:
/// Space Grotesk (display), Hanken Grotesk (body), JetBrains Mono (data).
///
/// The fonts are variable, so weight is applied through the font descriptor
/// rather than `Font.weight`, which gives the correct weight along the wght axis.
enum Typography {
    /// Display, headings, labels.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        custom("Space Grotesk", size: size, weight: weight)
    }

    /// Body and instructions.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        custom("Hanken Grotesk", size: size, weight: weight)
    }

    /// Frets, tab, and data.
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        custom("JetBrains Mono", size: size, weight: weight)
    }

    private static func custom(_ family: String, size: CGFloat, weight: Font.Weight) -> Font {
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: family,
            .traits: [UIFontDescriptor.TraitKey.weight: uiWeight(weight)],
        ])
        return Font(UIFont(descriptor: descriptor, size: size))
    }

    private static func uiWeight(_ weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
}
