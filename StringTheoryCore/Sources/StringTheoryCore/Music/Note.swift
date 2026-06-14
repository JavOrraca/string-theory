import Foundation

/// A pitch class in 12-tone equal temperament, spelled with sharps — the direct
/// port of the `NOTES` array in the prototype's `music.js`.
///
/// This models a *pitch class* (no octave): `Note.e` represents every E on the
/// neck. Raw values are semitone offsets from C (`C = 0 ... B = 11`).
public enum Note: Int, CaseIterable, Sendable, Hashable {
    case c, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b

    /// Display name (e.g. `"C#"`) — matches `music.js` `NOTES` exactly.
    public var name: String {
        Self.names[rawValue]
    }

    /// Parse a sharp-spelled name (`"C"`, `"F#"`). Returns `nil` if unrecognized.
    public init?(name: String) {
        guard let match = Self.allCases.first(where: { $0.name == name }) else { return nil }
        self = match
    }

    private static let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
}

// MARK: - Pitch helpers (ports of music.js `noteAt` / `freqAt`)

/// The note sounding at `fret` on a string whose open note is `open`.
/// Port of `noteAt(openNote, fret)`. The modulo is written to stay correct for
/// negative fret offsets too.
public func noteAt(open: Note, fret: Int) -> Note {
    let index = ((open.rawValue + fret) % 12 + 12) % 12
    return Note(rawValue: index)!
}

/// The frequency (Hz) at `fret` on a string whose open frequency is `base` Hz.
/// Port of `freqAt(baseFreq, fret)` — equal temperament, doubling every octave.
public func freqAt(base: Double, fret: Int) -> Double {
    base * pow(2.0, Double(fret) / 12.0)
}

public extension Note {
    /// Concert-pitch frequency (Hz) of this pitch class at the given octave
    /// (A4 = 440 Hz, MIDI-based). Port of the prototype's `_noteFreq(name, octave)`,
    /// used by the synthesized backing voices.
    func frequency(octave: Int) -> Double {
        let midi = (octave + 1) * 12 + rawValue
        return 440 * pow(2.0, Double(midi - 69) / 12.0)
    }
}
