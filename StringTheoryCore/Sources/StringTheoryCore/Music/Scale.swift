/// A scale's quality — port of the `SCALES` table in `music.js`.
public enum ScaleType: String, CaseIterable, Sendable, Hashable {
    case major
    case majorPentatonic
    case minorPentatonic
    case naturalMinor

    /// Human-readable label — matches the prototype labels exactly.
    public var label: String {
        switch self {
        case .major: "Major"
        case .majorPentatonic: "Major Pentatonic"
        case .minorPentatonic: "Minor Pentatonic"
        case .naturalMinor: "Natural Minor"
        }
    }

    /// Semitone offsets from the root.
    public var intervals: [Int] {
        switch self {
        case .major: [0, 2, 4, 5, 7, 9, 11]
        case .majorPentatonic: [0, 2, 4, 7, 9]
        case .minorPentatonic: [0, 3, 5, 7, 10]
        case .naturalMinor: [0, 2, 3, 5, 7, 8, 10]
        }
    }

    /// Whether this scale is minor-flavored. Replaces the prototype's
    /// `scaleType.includes('min')` string check; drives the backing progression.
    public var isMinor: Bool {
        switch self {
        case .minorPentatonic, .naturalMinor: true
        case .major, .majorPentatonic: false
        }
    }
}

/// A scale member's role: its semitone interval from the root and the degree
/// label shown on the fretboard (`"1"`, `"♭3"`, `"5"`, `"♭7"`, …).
public struct ScaleDegree: Sendable, Hashable {
    public let interval: Int
    public let label: String
    public init(interval: Int, label: String) {
        self.interval = interval
        self.label = label
    }
}

public enum Scale {
    /// Degree label for a semitone interval from the root — port of `music.js` `DEGREE`.
    public static func degreeLabel(forInterval interval: Int) -> String {
        labels[((interval % 12) + 12) % 12]
    }

    private static let labels = [
        "1", "♭2", "2", "♭3", "3", "4", "♭5", "5", "♭6", "6", "♭7", "7",
    ]
}

/// Map of note → its degree within `key` + `scale`. Port of `scaleMap`.
public func scaleMap(key: Note, scale: ScaleType) -> [Note: ScaleDegree] {
    var map: [Note: ScaleDegree] = [:]
    for interval in scale.intervals {
        let note = noteAt(open: key, fret: interval)
        map[note] = ScaleDegree(interval: interval, label: Scale.degreeLabel(forInterval: interval))
    }
    return map
}

/// Markers for every in-scale note across `startFret ... startFret + frets` on
/// `instrument`. The tonic is `.root`; other tones are `.safe`. Port of `scaleMarkers`.
public func scaleMarkers(
    instrument: Instrument,
    key: Note,
    scale: ScaleType,
    frets: Int = 12,
    startFret: Int = 0
) -> [Marker] {
    let tuning = Tuning.standard(for: instrument)
    let map = scaleMap(key: key, scale: scale)
    var out: [Marker] = []
    for (stringIndex, openString) in tuning.strings.enumerated() {
        for fret in startFret...(startFret + frets) {
            let note = noteAt(open: openString.note, fret: fret)
            guard let degree = map[note] else { continue }
            out.append(Marker(
                string: stringIndex,
                fret: fret,
                kind: note == key ? .root : .safe,
                note: note,
                label: degree.label
            ))
        }
    }
    return out
}
