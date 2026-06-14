import StringTheoryCore

/// Abstraction over the audio backend so the UI can be wired before the real
/// `AVAudioEngine` synth lands (Phase 5), and so synthesis can later be swapped
/// for sampled playback without touching the views.
@MainActor
protocol AudioEngine: AnyObject {
    func playRiff(_ riff: Riff, tuning: Tuning)
    func stopRiff()
    func playBacking(key: Note, scale: ScaleType)
    func stopBacking()
    func stopAll()
}

/// No-op engine used during scaffolding — keeps the UI fully interactive in silence.
@MainActor
final class NoopAudioEngine: AudioEngine {
    func playRiff(_ riff: Riff, tuning: Tuning) {}
    func stopRiff() {}
    func playBacking(key: Note, scale: ScaleType) {}
    func stopBacking() {}
    func stopAll() {}
}
