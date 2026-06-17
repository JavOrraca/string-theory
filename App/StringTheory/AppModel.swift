import Foundation
import Observation
import StringTheoryCore

/// The single shared state object. Holds instrument, handedness, the current
/// key/scale/chord, playback state, and the learning-path progress.
///
/// Onboarding, instrument, handedness, and progress are persisted in
/// `UserDefaults`, so the app remembers them across launches. The Scale, Chord,
/// and Solo selections are session-only, like the prototype.
@MainActor
@Observable
final class AppModel {
    // Persisted. Mutated through the methods below so the writes also hit storage.
    private(set) var hasOnboarded: Bool
    private(set) var instrument: Instrument
    private(set) var isLeftHanded: Bool
    private(set) var stageCompletion: [Int: Double]   // stage id -> fraction 0...1

    // Session-only exploration state.
    var scaleKey: Note = .e
    var scaleType: ScaleType = .minorPentatonic
    var chordID: String = "C"
    var soloKey: Note = .a
    var soloScale: ScaleType = .minorPentatonic

    // Playback, driven by the audio engine.
    private(set) var isPlayingRiff = false
    private(set) var riffStep: Int?
    private(set) var isPlayingBacking = false
    private(set) var backingChordIndex: Int?

    @ObservationIgnored private let audio: AudioEngine = SynthAudioEngine()
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasOnboarded = defaults.bool(forKey: Keys.hasOnboarded)
        instrument = defaults.string(forKey: Keys.instrument).flatMap(Instrument.init(rawValue:)) ?? .guitar
        isLeftHanded = defaults.bool(forKey: Keys.isLeftHanded)
        stageCompletion = Self.loadCompletion(from: defaults)

        audio.onRiffStep = { [weak self] step in self?.riffStep = step }
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

    // MARK: Derived state

    var tuning: Tuning { .standard(for: instrument) }
    var openNotes: [Note] { tuning.strings.map(\.note) }
    var stringCount: Int { tuning.stringCount }
    var selectedChord: Chord { Chord.named(chordID) ?? Chord.library[0] }

    /// Root note of the chord currently sounding in the backing loop, if any.
    var activeBackingRoot: Note? {
        guard let index = backingChordIndex else { return nil }
        let progression = backingProgression(key: soloKey, scale: soloScale)
        guard progression.indices.contains(index) else { return nil }
        return progression[index].root
    }

    // MARK: Learning path (persisted progress)

    /// Completion fraction (0...1) for a stage. A fresh user is 0 everywhere.
    func progress(forStage id: Int) -> Double {
        min(max(stageCompletion[id] ?? 0, 0), 1)
    }

    /// `done` once a stage is finished, `active` for the first unfinished stage,
    /// `locked` for everything after it.
    func status(for stage: LearningStage) -> StageStatus {
        if progress(forStage: stage.id) >= 1 { return .done }
        let current = LearningPath.stages.first { progress(forStage: $0.id) < 1 }
        return stage.id == current?.id ? .active : .locked
    }

    var overallPercent: Int {
        guard !LearningPath.stages.isEmpty else { return 0 }
        let total = LearningPath.stages.reduce(0.0) { $0 + progress(forStage: $1.id) }
        return Int((total / Double(LearningPath.stages.count) * 100).rounded())
    }

    /// Record progress for a stage (0...1). The hook real lessons will call as
    /// the user completes them.
    func setStageProgress(_ fraction: Double, forStage id: Int) {
        stageCompletion[id] = min(max(fraction, 0), 1)
        persistCompletion()
    }

    // MARK: Lesson transport

    func toggleRiff() {
        if isPlayingRiff {
            stopRiff()
        } else {
            stopBacking()
            audio.playRiff(.drift, tuning: .guitar)
            isPlayingRiff = true
        }
    }

    private func stopRiff() {
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
            audio.playBacking(key: soloKey, scale: soloScale)
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
        static let stageCompletion = "stageCompletion"
    }

    private func persistCompletion() {
        let stored = Dictionary(uniqueKeysWithValues: stageCompletion.map { (String($0.key), $0.value) })
        defaults.set(stored, forKey: Keys.stageCompletion)
    }

    private static func loadCompletion(from defaults: UserDefaults) -> [Int: Double] {
        guard let stored = defaults.dictionary(forKey: Keys.stageCompletion) else { return [:] }
        var result: [Int: Double] = [:]
        for (key, value) in stored {
            if let id = Int(key), let fraction = value as? Double {
                result[id] = fraction
            }
        }
        return result
    }
}

// MARK: - Learning path content

enum StageStatus {
    case done, active, locked
}

struct LearningStage: Identifiable, Hashable {
    let id: Int
    let number: String      // "01" ... "05"
    let title: String
    let subtitle: String
}

enum LearningPath {
    static let stages: [LearningStage] = [
        LearningStage(id: 1, number: "01", title: "Fretboard Basics",
                      subtitle: "String names · fret numbers · note at each position"),
        LearningStage(id: 2, number: "02", title: "Tabs",
                      subtitle: "Read tablature as fretboard positions · short riffs"),
        LearningStage(id: 3, number: "03", title: "Chords",
                      subtitle: "Shapes & diagrams tied back to the notes you know"),
        LearningStage(id: 4, number: "04", title: "Scales & Keys",
                      subtitle: "Major & pentatonic patterns across the neck"),
        LearningStage(id: 5, number: "05", title: "Improvisation",
                      subtitle: "Solo over a backing track using only safe notes"),
    ]
}
