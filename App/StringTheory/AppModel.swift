import Foundation
import Observation
import StringTheoryCore

/// The single shared state object. Holds instrument, handedness, the current
/// key/scale/chord, tempo, playback state, and the learning-path progress.
///
/// Onboarding, instrument, handedness, tempo, and completed lessons are persisted
/// in `UserDefaults`, so the app remembers them across launches. The Scale,
/// Chord, and Solo selections are session-only, like the prototype.
@MainActor
@Observable
final class AppModel {
    // Persisted. Mutated through the methods below so the writes also hit storage.
    private(set) var hasOnboarded: Bool
    private(set) var instrument: Instrument
    private(set) var isLeftHanded: Bool
    private(set) var tempo: Int                       // BPM for the riff and backing loop
    private(set) var completedLessons: Set<String>    // keys of finished lessons

    // Session-only exploration state.
    /// Which tab is showing. Session-only. A lesson handoff sets this to send the
    /// learner into the matching tool tab.
    var selectedTab: MainTab = .path
    var scaleKey: Note = .e
    var scaleType: ScaleType = .minorPentatonic
    var chordID: String = "C"
    var soloKey: Note = .a
    var soloScale: ScaleType = .minorPentatonic

    // Playback, driven by the audio engine.
    private(set) var isPlayingRiff = false
    private(set) var riffStep: Int?
    private(set) var riffRepetitions = 0
    private(set) var isPlayingBacking = false
    private(set) var backingChordIndex: Int?

    /// How many full passes of the riff count as "practiced enough" for a lesson.
    let riffRepetitionGoal = 2
    var riffGoalReached: Bool { riffRepetitions >= riffRepetitionGoal }

    /// Allowed tempo range in BPM. 110 is the prototype's default.
    let tempoRange = 60...160
    static let defaultTempo = 110

    @ObservationIgnored private let audio: AudioEngine = SynthAudioEngine()
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasOnboarded = defaults.bool(forKey: Keys.hasOnboarded)
        instrument = defaults.string(forKey: Keys.instrument).flatMap(Instrument.init(rawValue:)) ?? .guitar
        isLeftHanded = defaults.bool(forKey: Keys.isLeftHanded)
        tempo = (defaults.object(forKey: Keys.tempo) as? Int) ?? Self.defaultTempo
        completedLessons = Set(defaults.stringArray(forKey: Keys.completedLessons) ?? [])

        audio.onRiffStep = { [weak self] step in
            guard let self else { return }
            if let previous = self.riffStep, step < previous { self.riffRepetitions += 1 }
            self.riffStep = step
        }
        audio.onBackingChord = { [weak self] index in self?.backingChordIndex = index }
    }

    // MARK: Setup (persisted)

    func setInstrument(_ value: Instrument) {
        instrument = value
        defaults.set(value.rawValue, forKey: Keys.instrument)
    }

    func setLeftHanded(_ value: Bool) {
        isLeftHanded = value
        defaults.set(value, forKey: Keys.isLeftHanded)
    }

    func completeOnboarding() {
        hasOnboarded = true
        defaults.set(true, forKey: Keys.hasOnboarded)
    }

    /// Sets the tempo (clamped to `tempoRange`). Takes effect the next time the
    /// riff or backing loop is started.
    func setTempo(_ bpm: Int) {
        let clamped = min(max(bpm, tempoRange.lowerBound), tempoRange.upperBound)
        guard clamped != tempo else { return }
        tempo = clamped
        defaults.set(clamped, forKey: Keys.tempo)
    }

    // MARK: Derived state

    var tuning: Tuning { .standard(for: instrument) }

    /// The learning path for the current instrument.
    var stages: [LearningStage] { LearningPath.stages(for: instrument) }

    var openNotes: [Note] { tuning.strings.map(\.note) }
    var stringCount: Int { tuning.stringCount }
    var selectedChord: Chord { Chord.named(chordID) ?? Chord.library[0] }

    /// Riff step / backing bar durations, scaled from the default 110 BPM.
    private var riffStepDuration: Double { 0.30 * Double(Self.defaultTempo) / Double(tempo) }
    private var backingBarDuration: Double { 1.7 * Double(Self.defaultTempo) / Double(tempo) }

    /// Root note of the chord currently sounding in the backing loop, if any.
    var activeBackingRoot: Note? {
        guard let index = backingChordIndex else { return nil }
        let progression = backingProgression(key: soloKey, scale: soloScale)
        guard progression.indices.contains(index) else { return nil }
        return progression[index].root
    }

    /// Plays the note at (string, fret) on the current instrument's tuning (tap-to-hear).
    func playNote(string: Int, fret: Int) {
        guard tuning.strings.indices.contains(string) else { return }
        audio.playNote(frequency: freqAt(base: tuning.strings[string].frequency, fret: fret))
    }

    // MARK: Learning path (persisted progress)

    func isLessonComplete(stageID: Int, lessonID: Int) -> Bool {
        completedLessons.contains(Self.lessonKey(stageID, lessonID))
    }

    func markLessonComplete(stageID: Int, lessonID: Int) {
        if completedLessons.insert(Self.lessonKey(stageID, lessonID)).inserted {
            defaults.set(Array(completedLessons), forKey: Keys.completedLessons)
        }
    }

    /// Completion fraction (0...1) for a stage: finished lessons over total.
    func progress(for stage: LearningStage) -> Double {
        guard !stage.lessons.isEmpty else { return 0 }
        let done = stage.lessons.reduce(0) { $0 + (isLessonComplete(stageID: stage.id, lessonID: $1.id) ? 1 : 0) }
        return Double(done) / Double(stage.lessons.count)
    }

    /// `done` once a stage is finished, `active` for the first unfinished stage,
    /// `locked` for everything after it.
    func status(for stage: LearningStage) -> StageStatus {
        if progress(for: stage) >= 1 { return .done }
        let current = stages.first { progress(for: $0) < 1 }
        return stage.id == current?.id ? .active : .locked
    }

    var overallPercent: Int {
        guard !stages.isEmpty else { return 0 }
        let total = stages.reduce(0.0) { $0 + progress(for: $1) }
        return Int((total / Double(stages.count) * 100).rounded())
    }

    // MARK: Lesson transport

    func toggleRiff(_ riff: Riff = .drift) {
        if isPlayingRiff {
            stopRiff()
        } else {
            stopBacking()
            riffRepetitions = 0
            audio.playRiff(riff, tuning: tuning, stepDuration: riffStepDuration)
            isPlayingRiff = true
        }
    }

    func stopRiff() {
        audio.stopRiff()
        isPlayingRiff = false
        riffStep = nil
    }

    // MARK: Solo transport

    func toggleBacking() {
        if isPlayingBacking {
            stopBacking()
        } else {
            stopRiff()
            audio.playBacking(key: soloKey, scale: soloScale, barDuration: backingBarDuration)
            isPlayingBacking = true
        }
    }

    /// Stops the backing loop. Public so a `.backing` lesson can stop it when the
    /// learner advances or leaves the stage, the way `stopRiff` works for tabs.
    func stopBacking() {
        audio.stopBacking()
        isPlayingBacking = false
        backingChordIndex = nil
    }

    /// Changing key or scale stops the backing loop (mirrors the prototype).
    func setSoloKey(_ note: Note) {
        stopBacking()
        soloKey = note
    }

    func setSoloScale(_ scale: ScaleType) {
        stopBacking()
        soloScale = scale
    }

    // MARK: Persistence

    private enum Keys {
        static let hasOnboarded = "hasOnboarded"
        static let instrument = "instrument"
        static let isLeftHanded = "isLeftHanded"
        static let tempo = "tempo"
        static let completedLessons = "completedLessons"
    }

    private static func lessonKey(_ stageID: Int, _ lessonID: Int) -> String {
        "\(stageID).\(lessonID)"
    }
}

// MARK: - Learning path content

/// The four tabs in the main shell. Drives `TabView` selection so a lesson can
/// hand off to a tool tab.
enum MainTab: Hashable {
    case path, chords, scales, solo
}

enum StageStatus {
    case done, active, locked
}

/// What a lesson presents. `tab` plays any riff on the learner's own tuning;
/// `reading` is a short text lesson (used as real per-stage content lands);
/// `scale` shows a scale on the neck, tap-to-hear, with `showDegrees` choosing
/// whether each tone is labelled with its degree or left as a plain dot;
/// `backing` is the Solo screen's neck driven by the backing loop, tap-to-hear.
enum LessonKind: Hashable {
    case tab(Riff)
    case reading(String)
    case explore(ExploreLesson)
    case scale(key: Note, type: ScaleType, showDegrees: Bool)
    case backing(key: Note, type: ScaleType)
}

/// A guided fretboard exploration used by the Fretboard Basics lessons.
enum ExploreLesson: Hashable {
    case openStrings
    case fretNumbers
    case findNote(Note)
}

struct Lesson: Identifiable, Hashable {
    let id: Int            // unique within its stage
    let title: String
    let subtitle: String
    let kind: LessonKind
    /// When set, this lesson's forward button opens the named tool tab instead
    /// of just advancing or dismissing.
    var handoff: MainTab? = nil
}

struct LearningStage: Identifiable, Hashable {
    let id: Int
    let number: String     // "01" ... "05"
    let title: String
    let subtitle: String
    let lessons: [Lesson]
}

enum LearningPath {
    /// The five stages, resolved for the chosen instrument. Stage 2 (Tabs) and,
    /// in a later increment, stage 3 (Chords) differ by instrument; the rest are
    /// the same and adapt through the shared fretboard geometry.
    static func stages(for instrument: Instrument) -> [LearningStage] {
        [fretboardBasics, tabs(for: instrument), chords, scalesAndKeys, improvisation]
    }

    private static let fretboardBasics = LearningStage(
        id: 1, number: "01", title: "Fretboard Basics",
        subtitle: "String names · fret numbers · note at each position",
        lessons: [
            Lesson(id: 1, title: "Open strings",
                   subtitle: "These are your open strings, low to high. Tap each one to hear it.",
                   kind: .explore(.openStrings)),
            Lesson(id: 2, title: "Fret numbers",
                   subtitle: "Frets count up from the nut, each one a semitone higher. Tap a fret to hear it.",
                   kind: .explore(.fretNumbers)),
            Lesson(id: 3, title: "Find a note",
                   subtitle: "The same note lives in many places. Here is every A in the first few frets. Tap any to hear it.",
                   kind: .explore(.findNote(.a))),
        ])

    private static func tabs(for instrument: Instrument) -> LearningStage {
        let lessons: [Lesson]
        switch instrument {
        case .guitar:
            lessons = [
                Lesson(id: 1, title: "Reading a tab number",
                       subtitle: "The lines are your strings, lowest at the bottom. A number is the fret to press on that string. Tap a number to hear it.",
                       kind: .tab(.tabReadGuitar)),
                Lesson(id: 2, title: "One string, climbing",
                       subtitle: "Same string, higher frets, higher pitch. Tap each note, then press Play.",
                       kind: .tab(.tabClimbGuitar)),
                Lesson(id: 3, title: "Crossing strings",
                       subtitle: "Now the riff jumps between the low two strings. Watch the neck light up as it plays.",
                       kind: .tab(.tabCrossGuitar)),
                Lesson(id: 4, title: "Timing and repeats",
                       subtitle: "A short pattern that loops. Press Play and let it come around a few times.",
                       kind: .tab(.tabGrooveGuitar)),
                Lesson(id: 5, title: "Play \u{201C}Drift\u{201D}",
                       subtitle: "Your first full riff. Press Play and follow the neck until it feels locked in.",
                       kind: .tab(.drift)),
            ]
        case .bass:
            lessons = [
                Lesson(id: 1, title: "Reading a tab number",
                       subtitle: "The lines are your four strings, lowest at the bottom. A number is the fret to press. Tap a number to hear it.",
                       kind: .tab(.tabReadBass)),
                Lesson(id: 2, title: "One string, climbing",
                       subtitle: "Same string, higher frets, higher pitch. Tap each note, then press Play.",
                       kind: .tab(.tabClimbBass)),
                Lesson(id: 3, title: "Crossing strings",
                       subtitle: "Now the line moves across the low three strings. Watch the neck as it plays.",
                       kind: .tab(.tabCrossBass)),
                Lesson(id: 4, title: "Locking with the beat",
                       subtitle: "A repeating groove. Press Play and feel where the notes land.",
                       kind: .tab(.tabGrooveBass)),
                Lesson(id: 5, title: "Play the bassline",
                       subtitle: "Your first full bassline. Press Play and follow the neck until it feels locked in.",
                       kind: .tab(.bassline)),
            ]
        }
        return LearningStage(
            id: 2, number: "02", title: "Tabs",
            subtitle: "Read tablature as fretboard positions · short riffs",
            lessons: lessons)
    }

    private static let chords = LearningStage(
        id: 3, number: "03", title: "Chords",
        subtitle: "Shapes & diagrams tied back to the notes you know",
        lessons: [Lesson(id: 1, title: "Chords",
                         subtitle: "Watch the neck as the riff plays.", kind: .tab(.drift))])

    private static let scalesAndKeys = LearningStage(
        id: 4, number: "04", title: "Scales & Keys",
        subtitle: "Major & pentatonic patterns across the neck",
        lessons: [
            Lesson(id: 1, title: "What a scale is",
                   subtitle: "A scale is the set of notes that fit a key. This is E minor pentatonic. The cyan note is the root. Tap any note to hear it.",
                   kind: .scale(key: .e, type: .minorPentatonic, showDegrees: false)),
            Lesson(id: 2, title: "The root and the degrees",
                   subtitle: "Every note shows its scale degree, and the root is 1. Tap up from the root to hear the degrees climb.",
                   kind: .scale(key: .e, type: .minorPentatonic, showDegrees: true)),
            Lesson(id: 3, title: "Minor vs major pentatonic",
                   subtitle: "Same key, brighter sound. This is E major pentatonic. Compare it to the minor shape you just saw.",
                   kind: .scale(key: .e, type: .majorPentatonic, showDegrees: true)),
            Lesson(id: 4, title: "Same shape, new key",
                   subtitle: "Move the whole pattern up and the key changes with it. This is A minor pentatonic: same shape, new root.",
                   kind: .scale(key: .a, type: .minorPentatonic, showDegrees: true)),
            Lesson(id: 5, title: "Explore on your own",
                   subtitle: "Now pick any key and scale yourself and watch the whole neck redraw.",
                   kind: .scale(key: .a, type: .minorPentatonic, showDegrees: true),
                   handoff: .scales),
        ])

    private static let improvisation = LearningStage(
        id: 5, number: "05", title: "Improvisation",
        subtitle: "Solo over a backing track using only safe notes",
        lessons: [Lesson(id: 1, title: "Improvisation",
                         subtitle: "Watch the neck as the riff plays.", kind: .tab(.drift))])
}
