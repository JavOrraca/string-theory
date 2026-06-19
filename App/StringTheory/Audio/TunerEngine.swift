import AVFoundation
import StringTheoryCore

/// One pitch reading published to the UI. `isVoiced` is false when the input is
/// too quiet or aperiodic to read, so the needle can show an idle state instead
/// of chasing noise.
struct TunerReading: Sendable, Equatable {
    var hz: Double
    var stringIndex: Int
    var cents: Double
    var isVoiced: Bool

    static let idle = TunerReading(hz: 0, stringIndex: 0, cents: 0, isVoiced: false)
}

@MainActor
protocol TunerEngine: AnyObject {
    var onReading: (@MainActor (TunerReading) -> Void)? { get set }
    func start()
    func stop()
}

/// Used in previews and where the mic is not wanted.
@MainActor
final class NoopTunerEngine: TunerEngine {
    var onReading: (@MainActor (TunerReading) -> Void)?
    func start() {}
    func stop() {}
}

/// Accumulates mic samples on the audio thread and runs the core detector when a
/// full window is ready. Audio-thread safe via a lock. `@unchecked Sendable`
/// because the lock guards the only mutable state.
final class TunerAnalyzer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: [Float] = []
    private let windowSize: Int
    private let sampleRate: Double
    private let tuning: Tuning

    init(sampleRate: Double, windowSize: Int, tuning: Tuning) {
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.tuning = tuning
    }

    /// Append frames; once a window is full, detect and clear. Returns a reading
    /// (voiced or idle) when it analyzed, or nil while still filling.
    func append(_ frames: [Float]) -> TunerReading? {
        lock.lock()
        buffer.append(contentsOf: frames)
        guard buffer.count >= windowSize else { lock.unlock(); return nil }
        let window = buffer
        buffer.removeAll(keepingCapacity: true)
        lock.unlock()

        guard let hz = detectPitchHz(window, sampleRate: sampleRate) else {
            return .idle
        }
        let near = nearestString(toHz: hz, in: tuning)
        return TunerReading(hz: hz, stringIndex: near.index, cents: near.cents, isVoiced: true)
    }
}

/// Taps the microphone, detects pitch off the main actor, and publishes readings
/// on the main actor. The tap closure is nonisolated and never reads main-actor
/// state, matching the render-block rule that the synth follows.
@MainActor
final class MicTunerEngine: TunerEngine {
    var onReading: (@MainActor (TunerReading) -> Void)?

    private let engine = AVAudioEngine()
    private let tuningProvider: () -> Tuning
    private var running = false

    init(tuning: @escaping () -> Tuning) {
        self.tuningProvider = tuning
    }

    func start() {
        guard !running else { return }
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        guard sampleRate > 0 else { return }            // no input route available

        let analyzer = TunerAnalyzer(sampleRate: sampleRate, windowSize: 4096, tuning: tuningProvider())
        let forward = Self.forwarder { [weak self] reading in self?.onReading?(reading) }

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            let frames = Self.monoSamples(from: buffer)
            if let reading = analyzer.append(frames) { forward(reading) }
        }

        do {
            try engine.start()
            running = true
        } catch {
            print("MicTunerEngine failed to start: \(error)")
            input.removeTap(onBus: 0)
        }
    }

    func stop() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
    }

    nonisolated private static func monoSamples(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channels = buffer.floatChannelData else { return [] }
        let count = Int(buffer.frameLength)
        return Array(UnsafeBufferPointer(start: channels[0], count: count))
    }

    /// Wraps a main-actor sink in a Sendable closure that hops to the main actor.
    nonisolated private static func forwarder(
        _ sink: @escaping @MainActor (TunerReading) -> Void
    ) -> @Sendable (TunerReading) -> Void {
        { reading in Task { @MainActor in sink(reading) } }
    }
}
