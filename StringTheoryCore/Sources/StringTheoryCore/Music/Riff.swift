/// One pluck in a tab riff — a fret on a string. Port of a `RIFF.steps` entry.
public struct RiffStep: Sendable, Hashable {
    /// 0 = lowest-pitched string.
    public let string: Int
    public let fret: Int
    public init(string: Int, fret: Int) {
        self.string = string
        self.fret = fret
    }
}

/// A short tab riff for the Tabs lesson. Port of `music.js` `RIFF`.
public struct Riff: Sendable, Hashable {
    public let name: String
    public let key: Note
    public let scale: ScaleType
    /// Played left to right.
    public let steps: [RiffStep]
    public init(name: String, key: Note, scale: ScaleType, steps: [RiffStep]) {
        self.name = name
        self.key = key
        self.scale = scale
        self.steps = steps
    }
}

public extension Riff {
    /// "Drift" — the built-in practice riff, in E minor pentatonic territory.
    static let drift = Riff(
        name: "Riff 01 — “Drift”",
        key: .e,
        scale: .minorPentatonic,
        steps: [
            RiffStep(string: 0, fret: 0), RiffStep(string: 0, fret: 3), RiffStep(string: 1, fret: 0),
            RiffStep(string: 0, fret: 0), RiffStep(string: 0, fret: 3), RiffStep(string: 1, fret: 2),
            RiffStep(string: 1, fret: 0), RiffStep(string: 0, fret: 3), RiffStep(string: 0, fret: 0),
            RiffStep(string: 1, fret: 0), RiffStep(string: 1, fret: 2), RiffStep(string: 2, fret: 0),
        ]
    )
}
