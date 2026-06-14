import SwiftUI

/// Type roles from the prototype.
///
/// TODO: bundle the OFL fonts — Space Grotesk (display), Hanken Grotesk (body),
/// JetBrains Mono (data) — register them in Info.plist, and switch the three
/// roles below. For now they map to the closest system faces.
enum Typography {
    /// Display · headings · labels → Space Grotesk.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight)
    }

    /// Body · instructions → Hanken Grotesk.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Frets · tab · data → JetBrains Mono.
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
