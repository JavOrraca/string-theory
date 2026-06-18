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

    func toggleRiff() {
        if isPlayingRiff {
            stopRiff()
        } else {
            stopBacking()
            riffRepetitions = 0
            audio.playRiff(.drift, tuning: .guitar, stepDuration: riffStepDuration)
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

    private func stopBacking() {
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

enum StageStatus {
    case done, active, locked
}

/// What a lesson presents. `fretboardRiff` is the interactive fretboard + tab
/// demo we have today; `reading` is a short text lesson (used as real per-stage
/// content lands).
enum LessonKind: Hashable {
    case fretboardRiff
    case reading(String)
    case explore(ExploreLesson)
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
        [fretboardBasics, tabs, chords, scalesAndKeys, improvisation]
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

    // Stage 2 content lands in a later task. Keep a single stub for now.
    private static let tabs = LearningStage(
        id: 2, number: "02", title: "Tabs",
        subtitle: "Read tablature as fretboard positions · short riffs",
        lessons: [Lesson(id: 1, title: "Read the riff",
                         subtitle: "Each number is a fret on that string.", kind: .fretboardRiff)])

    private static let chords = LearningStage(
        id: 3, number: "03", title: "Chords",
        subtitle: "Shapes & diagrams tied back to the notes you know",
        lessons: [Lesson(id: 1, title: "Chords",
                         subtitle: "Watch the neck as the riff plays.", kind: .fretboardRiff)])

    private static let scalesAndKeys = LearningStage(
        id: 4, number: "04", title: "Scales & Keys",
        subtitle: "Major & pentatonic patterns across the neck",
        lessons: [Lesson(id: 1, title: "Scales & Keys",
                         subtitle: "Watch the neck as the riff plays.", kind: .fretboardRiff)])

    private static let improvisation = LearningStage(
        id: 5, number: "05", title: "Improvisation",
        subtitle: "Solo over a backing track using only safe notes",
        lessons: [Lesson(id: 1, title: "Improvisation",
                         subtitle: "Watch the neck as the riff plays.", kind: .fretboardRiff)])
}
