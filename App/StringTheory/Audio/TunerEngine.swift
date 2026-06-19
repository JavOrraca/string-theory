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
    /// The tuning to map detected pitches against is passed at start time, so the
    /// engine never has to capture AppModel (which would be illegal in init).
    func start(tuning: Tuning)
    func stop()
}

/// Used in previews and where the mic is not wanted.
@MainActor
final class NoopTunerEngine: TunerEngine {
    var onReading: (@MainActor (TunerReading) -> Void)?
    func start(tuning: Tuning) {}
    func stop() {}
}

/// Accumulates mic samples and turns a full window into a reading. The two steps
/// are split on purpose: `appendAndExtractWindow` is cheap (a locked append plus
/// a copy) and is the only part called from the realtime audio tap; `analyze`
/// runs the heavy YIN detector and is called off that thread on a background
/// queue. `@unchecked Sendable` because the lock guards the only mutable state.
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

    /// Append frames from the audio tap; once a full window has accumulated,
    /// return it and clear the buffer. Returns nil while still filling. Cheap
    /// enough for the realtime tap thread: no pitch detection happens here.
    func appendAndExtractWindow(_ frames: [Float]) -> [Float]? {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(contentsOf: frames)
        guard buffer.count >= windowSize else { return nil }
        let window = buffer
        buffer.removeAll(keepingCapacity: true)
        return window
    }

    /// Run the pitch detector on a full window and map it to a reading. Heavy;
    /// call off the audio thread. Returns `.idle` when the window is unvoiced.
    func analyze(_ window: [Float]) -> TunerReading {
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
    private var running = false
    /// Serial queue for pitch detection, so the heavy YIN pass runs off the
    /// realtime tap thread. Serial means windows are analyzed one at a time;
    /// detection is far shorter than a window, so it never falls behind.
    private let detectQueue = DispatchQueue(label: "com.javierorraca.stringtheory.tuner.detect", qos: .userInitiated)

    func start(tuning: Tuning) {
        guard !running else { return }
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        guard sampleRate > 0 else { return }            // no input route available

        let analyzer = TunerAnalyzer(sampleRate: sampleRate, windowSize: 4096, tuning: tuning)
        let forward = Self.forwarder { [weak self] reading in self?.onReading?(reading) }

        input.installTap(onBus: 0, bufferSize: 4096, format: format,
                         block: Self.makeTapBlock(analyzer: analyzer, queue: detectQueue, forward: forward))

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

    /// Builds the realtime tap block in a `nonisolated` context so it is not
    /// inferred main-actor-isolated. Otherwise the Swift 6 runtime traps when the
    /// realtime audio thread (`RealtimeMessenger`) invokes it: a closure formed in
    /// the `@MainActor` `start(tuning:)` and handed to the non-Sendable
    /// `AVAudioNodeTapBlock` carries main-actor isolation, and the inserted
    /// isolation check fires `dispatch_assert_queue` off the main queue. This is the
    /// same hazard `SynthAudioEngine`'s render-block factory avoids. The block
    /// captures only Sendable values and never reads main-actor state: it buffers
    /// and copies on the audio thread, then dispatches the heavy detection to `queue`.
    nonisolated private static func makeTapBlock(
        analyzer: TunerAnalyzer,
        queue: DispatchQueue,
        forward: @escaping @Sendable (TunerReading) -> Void
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            guard let window = analyzer.appendAndExtractWindow(monoSamples(from: buffer)) else { return }
            queue.async { forward(analyzer.analyze(window)) }
        }
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
