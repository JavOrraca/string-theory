import SwiftUI
import Foundation

/// Design tokens extracted from the prototype. Colors are authored in OKLCH —
/// exactly as the prototype's CSS — and converted to sRGB at runtime so the
/// values stay readable and tweakable against the source of truth.
enum Theme {
    enum Palette {
        static let void       = Color(oklchL: 0.12,  c: 0.012, h: 250) // app background
        static let panel      = Color(oklchL: 0.19,  c: 0.018, h: 250) // surfaces
        static let panelDeep  = Color(oklchL: 0.155, c: 0.014, h: 250) // nav/transport bars
        static let phosphor   = Color(oklchL: 0.85,  c: 0.17,  h: 152) // safe · active · key UI
        static let signalCyan = Color(oklchL: 0.84,  c: 0.11,  h: 205) // root note only
        static let warning    = Color(oklchL: 0.64,  c: 0.16,  h: 25)  // muted / avoid
        static let text       = Color(oklchL: 0.93,  c: 0.01,  h: 220) // primary copy
        static let textDim    = Color(oklchL: 0.66,  c: 0.02,  h: 230) // secondary copy
        static let hairline   = Color(oklchL: 0.5,   c: 0.03,  h: 160).opacity(0.18)
    }
}

extension Color {
    /// Create a Color from OKLCH (L in `0...1`, chroma `c`, hue `h` in degrees).
    init(oklchL L: Double, c: Double, h: Double, opacity: Double = 1) {
        let rgb = OKLCH.toSRGB(L: L, c: c, hDegrees: h)
        self = Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: opacity)
    }
}

/// OKLCH → sRGB conversion using Björn Ottosson's OKLab matrices.
enum OKLCH {
    static func toSRGB(L: Double, c: Double, hDegrees: Double) -> (r: Double, g: Double, b: Double) {
        let h = hDegrees * .pi / 180
        let a = c * cos(h)
        let b = c * sin(h)

        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b

        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        let r =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let b2 = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        return (gamma(r), gamma(g), gamma(b2))
    }

    private static func gamma(_ x: Double) -> Double {
        let v = min(max(x, 0), 1)
        return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055
    }
}
