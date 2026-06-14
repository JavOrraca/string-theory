import Observation
import StringTheoryCore

/// The single shared state object — mirrors the prototype, where flipping
/// instrument or handedness re-renders every diagram in the app.
@MainActor
@Observable
final class AppModel {
    // Onboarding / global
    var instrument: Instrument = .guitar
    var isLeftHanded: Bool = false
    var hasOnboarded: Bool = false

    // Scale Explorer
    var scaleKey: Note = .e
    var scaleType: ScaleType = .minorPentatonic

    // Chord Library
    var chordID: String = "C"

    // Solo Practice
    var soloKey: Note = .a
    var soloScale: ScaleType = .minorPentatonic

    // MARK: Derived state

    var tuning: Tuning { .standard(for: instrument) }
    var openNotes: [Note] { tuning.strings.map(\.note) }
    var stringCount: Int { tuning.stringCount }
    var selectedChord: Chord { Chord.named(chordID) ?? Chord.library[0] }
}
