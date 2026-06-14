# Architecture

String Theory is split into a pure-logic Swift package and a SwiftUI app on top of it.

## StringTheoryCore (Swift package)

No UIKit or SwiftUI. It builds and tests with `swift test` on the Mac host, which keeps the music logic fast to test and easy to reason about.

Music model, in `Sources/StringTheoryCore/Music/`:

- `Note` is the 12-note chromatic pitch class, with `noteAt(open:fret:)`, `freqAt(base:fret:)`, and `frequency(octave:)`.
- `Tuning` holds the guitar and bass tunings (open notes plus open-string frequencies).
- `Scale` has the four scale types, their intervals, degree labels, `scaleMap`, and `scaleMarkers`.
- `Chord` has the ten-chord library, `chordMarkers`, and `chordSpan`.
- `Riff` is the practice riff. `Progression` is `backingProgression` (i-VI-III-VII in minor, I-V-vi-IV in major).
- `Marker` and `MarkerKind` are the dot model shared by every diagram.

Fretboard, in `Sources/StringTheoryCore/Fretboard/`:

- `FretboardGeometry` turns a (string, fret) into a normalized point in 0 to 100 percent of the board. It also gives string Y positions, fret X positions, the open-string zone, inlay placement, and left-handed mirroring. All pure math, tested without a view.

## The app (App/StringTheory)

- `AppModel` is the single `@Observable` state object: instrument, handedness, the selected key, scale, and chord, plus playback state. Flipping instrument or handedness re-renders every diagram, the way the prototype works. It owns the audio engine.
- `DesignSystem/` holds the palette, type roles, and view modifiers. Colors are written in OKLCH, the same values as the prototype's CSS, and converted to sRGB at runtime in `Theme.swift`. Fonts map to system faces for now, with a TODO to bundle the real OFL fonts.
- `Components/FretboardView.swift` is one SwiftUI Canvas renderer. It draws the neck and overlays the marker dots, and it reads positions from `FretboardGeometry`, so 4 or 6 strings, handedness, and the fret window are handled by the core. Every screen reuses it.
- `Features/` has the six screens. `Audio/` has the `AudioEngine` protocol, a no-op for previews, and `SynthAudioEngine`.

## Audio

`SynthAudioEngine` drives an `AVAudioSourceNode` that mixes voices: a filtered-saw pluck, a triangle pad, and a sine kick, ported from the prototype's Web Audio. Two Task-based schedulers run the riff (about 110 BPM) and the four-bar backing loop (1.7 seconds per bar). They publish the current step and chord, which the Lesson and Solo screens read to highlight the neck and tab in time.

The render block runs on the real-time audio thread, so it is built in a `nonisolated` factory and reads its voices through a lock. Under Swift 6, a render block formed inside a `@MainActor` context is treated as main-actor isolated and traps when the audio thread calls it, so keeping it nonisolated is the point.

## Why the split

The brief asked for the theory engine and the geometry to be pure and well tested. Keeping them in a package with no UI import means the tests double as the spec, they run in milliseconds, and the same code drives both the app and any future target.
