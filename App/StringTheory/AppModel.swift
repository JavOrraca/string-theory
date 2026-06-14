import Observation
import StringTheoryCore

/// The single shared state object — mirrors the prototype, where flipping
/// instrument or handedness re-renders every diagram. Also owns the audio engine
/// and the riff/backing playback state the Lesson and Solo transports bind to.
@MainActor
@Observable
final class AppModel {
    // Onboarding / global
    var instrument: Instrument = .guitar
    var isLeftHanded: Bool = false
    var hasOnboarded: Bool = false

    // Scale Explorer
    var scaleKey: Note = .e
    var scaleType: ScaleType = .minorPentatonic

    // Chord Library
    var chordID: String = "C"

    // Solo Practice
    var soloKey: Note = .a
    var soloScale: ScaleType = .minorPentatonic

    // Playback (driven by the audio engine)
    private(set) var isPlayingRiff = false
    private(set) var riffStep: Int?
    private(set) var isPlayingBacking = false
    private(set) var backingChordIndex: Int?

    @ObservationIgnored private let audio: AudioEngine = SynthAudioEngine()

    init() {
        audio.onRiffStep = { [weak self] step in self?.riffStep = step }
        audio.onBackingChord = { [weak self] index in self?.backingChordIndex = index }
    }

    // MARK: Derived state

    var tuning: Tuning { .standard(for: instrument) }
    var openNotes: [Note] { tuning.strings.map(\.note) }
    var stringCount: Int { tuning.stringCount }
    var selectedChord: Chord { Chord.named(chordID) ?? Chord.library[0] }

    /// Root note of the chord currently sounding in the backing loop, if any —
    /// used by Solo Practice to pulse that root on the neck.
    var activeBackingRoot: Note? {
        guard let index = backingChordIndex else { return nil }
        let progression = backingProgression(key: soloKey, scale: soloScale)
        guard progression.indices.contains(index) else { return nil }
        return progression[index].root
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

    /// Changing key or scale stops the backing loop (mirrors the prototype's `_stopSolo`).
    func setSoloKey(_ note: Note) {
        stopBacking()
        soloKey = note
    }

    func setSoloScale(_ scale: ScaleType) {
        stopBacking()
        soloScale = scale
    }
}
