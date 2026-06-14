/// One chord in a backing loop. Port of a `backingProgression` entry.
public struct ProgressionChord: Sendable, Hashable {
    public let root: Note
    public let isMinor: Bool

    /// Display name, e.g. `"Am"` or `"F"`.
    public var name: String { root.name + (isMinor ? "m" : "") }

    public init(root: Note, isMinor: Bool) {
        self.root = root
        self.isMinor = isMinor
    }
}

/// A diatonic 4-chord backing loop for `key` + `scale`.
///
/// Minor scales use i–VI–III–VII (e.g. A minor → Am F C G); major scales use
/// I–V–vi–IV (e.g. C major → C G Am F). Port of `backingProgression`.
public func backingProgression(key: Note, scale: ScaleType) -> [ProgressionChord] {
    let minor = scale.isMinor
    let degrees = minor ? [0, 8, 3, 10] : [0, 7, 9, 5]      // i VI III VII | I V vi IV
    let minorChord = minor ? [true, false, false, false] : [false, false, true, false]
    return degrees.enumerated().map { index, semitones in
        ProgressionChord(root: noteAt(open: key, fret: semitones), isMinor: minorChord[index])
    }
}
