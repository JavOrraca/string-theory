/// One open string: its pitch class and open-string frequency in Hz.
public struct OpenString: Sendable, Hashable {
    public let note: Note
    public let frequency: Double
    public init(note: Note, frequency: Double) {
        self.note = note
        self.frequency = frequency
    }
}

/// The instruments the app supports.
public enum Instrument: String, CaseIterable, Sendable, Hashable {
    case guitar
    case bass

    public var stringCount: Int { Tuning.standard(for: self).stringCount }
}

/// A tuning stored low string → high string — port of `music.js` `TUNINGS`.
public struct Tuning: Sendable, Hashable {
    public let instrument: Instrument
    /// Index 0 = lowest-pitched string.
    public let strings: [OpenString]
    public var stringCount: Int { strings.count }

    public init(instrument: Instrument, strings: [OpenString]) {
        self.instrument = instrument
        self.strings = strings
    }
}

public extension Tuning {
    /// Standard 6-string guitar: E A D G B E (low → high).
    static let guitar = Tuning(instrument: .guitar, strings: [
        OpenString(note: .e, frequency: 82.41),  // low E (string 6)
        OpenString(note: .a, frequency: 110.0),
        OpenString(note: .d, frequency: 146.83),
        OpenString(note: .g, frequency: 196.0),
        OpenString(note: .b, frequency: 246.94),
        OpenString(note: .e, frequency: 329.63), // high e (string 1)
    ])

    /// Standard 4-string bass: E A D G (low → high).
    static let bass = Tuning(instrument: .bass, strings: [
        OpenString(note: .e, frequency: 41.20),
        OpenString(note: .a, frequency: 55.0),
        OpenString(note: .d, frequency: 73.42),
        OpenString(note: .g, frequency: 98.0),
    ])

    static func standard(for instrument: Instrument) -> Tuning {
        switch instrument {
        case .guitar: .guitar
        case .bass: .bass
        }
    }
}
