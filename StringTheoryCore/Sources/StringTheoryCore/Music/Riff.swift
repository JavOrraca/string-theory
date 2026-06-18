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
        name: "Riff 01 \u{2014} \u{201C}Drift\u{201D}",
        key: .e,
        scale: .minorPentatonic,
        steps: [
            RiffStep(string: 0, fret: 0), RiffStep(string: 0, fret: 3), RiffStep(string: 1, fret: 0),
            RiffStep(string: 0, fret: 0), RiffStep(string: 0, fret: 3), RiffStep(string: 1, fret: 2),
            RiffStep(string: 1, fret: 0), RiffStep(string: 0, fret: 3), RiffStep(string: 0, fret: 0),
            RiffStep(string: 1, fret: 0), RiffStep(string: 1, fret: 2), RiffStep(string: 2, fret: 0),
        ]
    )

    // MARK: Stage 2 teaching riffs (guitar, played on Tuning.guitar)

    /// "Read": three notes on the low string, to show a number means a fret.
    static let tabReadGuitar = Riff(name: "Read", key: .e, scale: .minorPentatonic, steps: [
        RiffStep(string: 0, fret: 0), RiffStep(string: 0, fret: 3), RiffStep(string: 0, fret: 5),
    ])
    /// "Climb": one string, rising frets, rising pitch.
    static let tabClimbGuitar = Riff(name: "Climb", key: .e, scale: .minorPentatonic, steps: [
        RiffStep(string: 0, fret: 0), RiffStep(string: 0, fret: 2),
        RiffStep(string: 0, fret: 3), RiffStep(string: 0, fret: 5),
    ])
    /// "Crossing": jumps between the low two strings.
    static let tabCrossGuitar = Riff(name: "Crossing", key: .e, scale: .minorPentatonic, steps: [
        RiffStep(string: 0, fret: 0), RiffStep(string: 0, fret: 3), RiffStep(string: 1, fret: 0),
        RiffStep(string: 1, fret: 2), RiffStep(string: 0, fret: 3), RiffStep(string: 1, fret: 0),
    ])
    /// "Groove": a short looping pattern for timing practice.
    static let tabGrooveGuitar = Riff(name: "Groove", key: .e, scale: .minorPentatonic, steps: [
        RiffStep(string: 0, fret: 0), RiffStep(string: 1, fret: 0), RiffStep(string: 0, fret: 0),
        RiffStep(string: 1, fret: 2), RiffStep(string: 0, fret: 3), RiffStep(string: 1, fret: 0),
        RiffStep(string: 0, fret: 0), RiffStep(string: 1, fret: 0),
    ])

    // MARK: Stage 2 teaching riffs (bass, played on Tuning.bass)

    /// "Read": three notes on the low string, to show a number means a fret.
    static let tabReadBass = Riff(name: "Read", key: .e, scale: .minorPentatonic, steps: [
        RiffStep(string: 0, fret: 0), RiffStep(string: 0, fret: 3), RiffStep(string: 0, fret: 5),
    ])
    /// "Climb": one string, rising frets, rising pitch.
    static let tabClimbBass = Riff(name: "Climb", key: .e, scale: .minorPentatonic, steps: [
        RiffStep(string: 0, fret: 0), RiffStep(string: 0, fret: 2),
        RiffStep(string: 0, fret: 3), RiffStep(string: 0, fret: 5),
    ])
    /// "Crossing": moves across the low three strings.
    static let tabCrossBass = Riff(name: "Crossing", key: .e, scale: .minorPentatonic, steps: [
        RiffStep(string: 0, fret: 0), RiffStep(string: 1, fret: 0), RiffStep(string: 0, fret: 3),
        RiffStep(string: 1, fret: 0), RiffStep(string: 2, fret: 0), RiffStep(string: 1, fret: 0),
    ])
    /// "Groove": a short looping pattern for timing practice.
    static let tabGrooveBass = Riff(name: "Groove", key: .e, scale: .minorPentatonic, steps: [
        RiffStep(string: 0, fret: 0), RiffStep(string: 0, fret: 0), RiffStep(string: 1, fret: 0),
        RiffStep(string: 0, fret: 0), RiffStep(string: 2, fret: 0), RiffStep(string: 1, fret: 0),
        RiffStep(string: 0, fret: 3), RiffStep(string: 0, fret: 0),
    ])
    /// "Bassline": the fuller groove for the final bass lesson.
    static let bassline = Riff(name: "Bassline", key: .e, scale: .minorPentatonic, steps: [
        RiffStep(string: 0, fret: 0), RiffStep(string: 1, fret: 0), RiffStep(string: 0, fret: 0),
        RiffStep(string: 2, fret: 0), RiffStep(string: 1, fret: 2), RiffStep(string: 1, fret: 0),
        RiffStep(string: 0, fret: 3), RiffStep(string: 0, fret: 0),
    ])
}
