/// A chord voicing — port of an entry in `music.js` `CHORDS`. These are guitar
/// voicings, stored low string → high string (`-1` = muted, `0` = open).
public struct Chord: Sendable, Hashable, Identifiable {
    public enum Quality: String, Sendable, Hashable { case major, minor }
    public enum Family: String, Sendable, Hashable { case open, barre }

    public let id: String
    public let name: String
    public let quality: Quality
    /// Fret per string, low → high. `-1` = muted, `0` = open.
    public let frets: [Int]
    public let family: Family

    public init(id: String, name: String, quality: Quality, frets: [Int], family: Family) {
        self.id = id
        self.name = name
        self.quality = quality
        self.frets = frets
        self.family = family
    }
}

public extension Chord {
    /// The 10-chord starter library from the prototype (open + barre voicings).
    static let library: [Chord] = [
        Chord(id: "C",  name: "C",  quality: .major, frets: [-1, 3, 2, 0, 1, 0],  family: .open),
        Chord(id: "A",  name: "A",  quality: .major, frets: [-1, 0, 2, 2, 2, 0],  family: .open),
        Chord(id: "G",  name: "G",  quality: .major, frets: [3, 2, 0, 0, 0, 3],   family: .open),
        Chord(id: "E",  name: "E",  quality: .major, frets: [0, 2, 2, 1, 0, 0],   family: .open),
        Chord(id: "D",  name: "D",  quality: .major, frets: [-1, -1, 0, 2, 3, 2], family: .open),
        Chord(id: "Am", name: "Am", quality: .minor, frets: [-1, 0, 2, 2, 1, 0],  family: .open),
        Chord(id: "Em", name: "Em", quality: .minor, frets: [0, 2, 2, 0, 0, 0],   family: .open),
        Chord(id: "Dm", name: "Dm", quality: .minor, frets: [-1, -1, 0, 2, 3, 1], family: .open),
        Chord(id: "F",  name: "F",  quality: .major, frets: [1, 3, 3, 2, 1, 1],   family: .barre),
        Chord(id: "Bm", name: "Bm", quality: .minor, frets: [-1, 2, 4, 4, 3, 2],  family: .barre),
    ]

    /// Look up a voicing by its id (`"C"`, `"Am"`, `"F"`, …).
    static func named(_ id: String) -> Chord? { library.first { $0.id == id } }
}

/// Inclusive fret range covered by a chord's fretted notes — port of `chordSpan`.
public struct FretSpan: Sendable, Hashable {
    public let min: Int
    public let max: Int
    public init(min: Int, max: Int) {
        self.min = min
        self.max = max
    }
}

// MARK: - Chord geometry (ports of music.js chordMarkers / chordSpan)

/// Markers for a chord diagram, including open (ring) and muted (×) strings.
/// Always a guitar voicing, per the prototype. Port of `chordMarkers`.
public func chordMarkers(_ chord: Chord, tuning: Tuning = .guitar) -> [Marker] {
    chord.frets.enumerated().map { stringIndex, fret in
        let openNote = tuning.strings[stringIndex].note
        switch fret {
        case ..<0:
            return Marker(string: stringIndex, fret: 0, kind: .muted)
        case 0:
            return Marker(string: stringIndex, fret: 0, kind: .open, note: openNote, label: openNote.name)
        default:
            let note = noteAt(open: openNote, fret: fret)
            return Marker(string: stringIndex, fret: fret, kind: .safe, note: note, label: note.name)
        }
    }
}

/// The fret span of a chord's fretted notes; defaults to `{0, 4}` when nothing
/// is fretted. Port of `chordSpan`.
public func chordSpan(_ chord: Chord) -> FretSpan {
    let fretted = chord.frets.filter { $0 > 0 }
    guard let low = fretted.min(), let high = fretted.max() else {
        return FretSpan(min: 0, max: 4)
    }
    return FretSpan(min: low, max: high)
}
