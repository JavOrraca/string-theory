import StringTheoryCore

/// Abstraction over the audio backend so the UI can be wired before the real
/// `AVAudioEngine` synth lands (Phase 5), and so synthesis can later be swapped
/// for sampled playback without touching the views.
@MainActor
protocol AudioEngine: AnyObject {
    /// Called as the riff plays with the index of the current step.
    var onRiffStep: (@MainActor (Int) -> Void)? { get set }
    /// Called as the backing loop plays with the index of the current chord.
    var onBackingChord: (@MainActor (Int) -> Void)? { get set }

    func playRiff(_ riff: Riff, tuning: Tuning, stepDuration: Double)
    func stopRiff()
    func playBacking(key: Note, scale: ScaleType, barDuration: Double)
    func stopBacking()
    func stopAll()
}

/// No-op engine used during scaffolding — keeps the UI fully interactive in silence.
@MainActor
final class NoopAudioEngine: AudioEngine {
    var onRiffStep: (@MainActor (Int) -> Void)?
    var onBackingChord: (@MainActor (Int) -> Void)?
    func playRiff(_ riff: Riff, tuning: Tuning, stepDuration: Double) {}
    func stopRiff() {}
    func playBacking(key: Note, scale: ScaleType, barDuration: Double) {}
    func stopBacking() {}
    func stopAll() {}
}
