import AVFoundation
import StringTheoryCore

// MARK: - Voice (one synthesized note)

/// A single synthesized voice, ported from the prototype's Web Audio nodes:
/// a saw/triangle/sine oscillator with an AD envelope, an optional one-pole
/// lowpass (the pluck's closing filter), and an optional pitch glide (the kick).
struct SynthVoice: Sendable {
    enum Wave: Sendable { case saw, triangle, sine }

    let wave: Wave
    let startFreq: Double
    let endFreq: Double
    let glide: Double            // seconds of pitch glide (0 = none)
    let peak: Float
    let attack: Double           // seconds
    let release: Double          // seconds (exponential decay)
    let useFilter: Bool
    let filterStartHz: Double
    let filterEndHz: Double
    let gain: Float

    private var phase: Double = 0
    private var t: Double = 0
    private var lp: Float = 0
    private(set) var finished = false

    private var duration: Double { attack + release }

    init(wave: Wave, startFreq: Double, endFreq: Double, glide: Double = 0,
         peak: Float, attack: Double, release: Double,
         useFilter: Bool = false, filterStartHz: Double = 20_000, filterEndHz: Double = 20_000,
         gain: Float = 1) {
        self.wave = wave
        self.startFreq = startFreq
        self.endFreq = endFreq
        self.glide = glide
        self.peak = peak
        self.attack = attack
        self.release = release
        self.useFilter = useFilter
        self.filterStartHz = filterStartHz
        self.filterEndHz = filterEndHz
        self.gain = gain
    }

    /// Sum this voice's next `frameCount` samples into `mono`. Runs on the audio thread.
    mutating func render(into mono: inout [Float], frameCount: Int, sampleRate: Double) {
        let dt = 1.0 / sampleRate
        var f = 0
        while f < frameCount {
            if t >= duration { finished = true; return }
            let freq = (glide > 0 && t < glide)
                ? startFreq * pow(endFreq / startFreq, t / glide)
                : endFreq
            phase += freq * dt
            if phase >= 1 { phase -= 1 }

            var s: Float
            switch wave {
            case .saw:      s = Float(2 * phase - 1)
            case .triangle: s = Float(4 * abs(phase - 0.5) - 1)
            case .sine:     s = Float(sin(2 * .pi * phase))
            }

            let env: Float = t < attack
                ? peak * Float(t / attack)
                : peak * Float(exp(-(t - attack) / (release * 0.35)))
            s *= env

            if useFilter {
                let cx = min(1.0, t / duration)
                let cutoff = filterStartHz * pow(filterEndHz / filterStartHz, cx)
                let coeff = Float(1 - exp(-2 * .pi * cutoff / sampleRate))
                lp += coeff * (s - lp)
                s = lp
            }

            mono[f] += s * gain
            t += dt
            f += 1
        }
        if t >= duration { finished = true }
    }
}

extension SynthVoice {
    /// Filtered-saw pluck with a fast decay (riff notes + backing bass).
    static func pluck(freq: Double, dur: Double, peak: Float) -> SynthVoice {
        SynthVoice(wave: .saw, startFreq: freq, endFreq: freq, peak: peak,
                   attack: 0.006, release: dur, useFilter: true,
                   filterStartHz: min(6000, freq * 8), filterEndHz: max(400, freq * 2))
    }
    /// Soft triangle pad (backing chord tones).
    static func pad(freq: Double, dur: Double, peak: Float) -> SynthVoice {
        SynthVoice(wave: .triangle, startFreq: freq, endFreq: freq, peak: peak,
                   attack: 0.08, release: dur)
    }
    /// Sine kick with a pitch drop (backing beat).
    static func kick() -> SynthVoice {
        SynthVoice(wave: .sine, startFreq: 120, endFreq: 45, glide: 0.12,
                   peak: 0.5, attack: 0.005, release: 0.18)
    }
}

// MARK: - VoiceBank (audio-thread mixer)

/// Holds the currently-sounding voices. The audio render thread reads it; the
/// main-actor scheduler appends to it. A lock guards the array — contention is
/// tiny (voices are added a few times per second).
final class VoiceBank: @unchecked Sendable {
    private var voices: [SynthVoice] = []
    private let lock = NSLock()
    private var scratch: [Float] = []   // reused mix buffer (audio thread only)

    func add(_ voice: SynthVoice) {
        lock.lock(); voices.append(voice); lock.unlock()
    }

    func reset() {
        lock.lock(); voices.removeAll(); lock.unlock()
    }

    func render(frameCount: Int, sampleRate: Double, into abl: UnsafeMutableAudioBufferListPointer) {
        if scratch.count < frameCount { scratch = [Float](repeating: 0, count: frameCount) }
        for f in 0..<frameCount { scratch[f] = 0 }
        lock.lock()
        for i in voices.indices {
            voices[i].render(into: &scratch, frameCount: frameCount, sampleRate: sampleRate)
        }
        voices.removeAll { $0.finished }
        lock.unlock()
        for buffer in abl {
            guard let data = buffer.mData else { continue }
            let ptr = data.assumingMemoryBound(to: Float.self)
            for f in 0..<frameCount { ptr[f] = scratch[f] }
        }
    }
}

// MARK: - SynthAudioEngine

/// The real audio backend: an `AVAudioEngine` driving an `AVAudioSourceNode`
/// that mixes `VoiceBank` voices. Riff and backing loops are Task-based
/// schedulers that add voices and publish the current step/chord for the UI.
@MainActor
final class SynthAudioEngine: AudioEngine {
    var onRiffStep: (@MainActor (Int) -> Void)?
    var onBackingChord: (@MainActor (Int) -> Void)?

    private let engine = AVAudioEngine()
    private let bank = VoiceBank()
    private let sampleRate: Double = 44_100
    private var sourceNode: AVAudioSourceNode?
    private var started = false

    private var riffTask: Task<Void, Never>?
    private var backingTask: Task<Void, Never>?

    init() {
        let node = Self.makeSourceNode(bank: bank, sampleRate: sampleRate)
        sourceNode = node
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.85
    }

    /// Builds the render node in a `nonisolated` context so its block is not
    /// inferred as main-actor-isolated — otherwise the Swift 6 runtime traps
    /// when the real-time audio thread invokes it.
    nonisolated private static func makeSourceNode(bank: VoiceBank, sampleRate: Double) -> AVAudioSourceNode {
        AVAudioSourceNode { _, _, frameCount, audioBufferList in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            bank.render(frameCount: Int(frameCount), sampleRate: sampleRate, into: abl)
            return noErr
        }
    }

    private func startIfNeeded() {
        guard !started else { return }
        #if os(iOS)
        // Do not downgrade a live record session: when the tuner has set
        // .playAndRecord, leave it so reference tones still mix with the mic.
        if AVAudioSession.sharedInstance().category != .playAndRecord {
            AudioSessionController.activate(.playback)
        }
        #endif
        do {
            try engine.start()
            started = true
        } catch {
            print("SynthAudioEngine failed to start: \(error)")
        }
    }

    func playNote(frequency: Double) {
        startIfNeeded()
        bank.add(.pluck(freq: frequency, dur: 0.9, peak: 0.22))
    }

    func playChord(frequencies: [Double], strumGap: Double) {
        startIfNeeded()
        guard !frequencies.isEmpty else { return }
        // Lower per-voice peak than a single tap so six summed plucks do not clip.
        if strumGap <= 0 {
            for freq in frequencies { bank.add(.pluck(freq: freq, dur: 1.4, peak: 0.14)) }
            return
        }
        Task { @MainActor [weak self] in
            for freq in frequencies {
                self?.bank.add(.pluck(freq: freq, dur: 1.4, peak: 0.14))
                try? await Task.sleep(for: .seconds(strumGap))
            }
        }
    }

    // MARK: Riff

    func playRiff(_ riff: Riff, tuning: Tuning, stepDuration: Double) {
        startIfNeeded()
        stopRiff()
        let steps = riff.steps
        let stepDur = stepDuration
        riffTask = Task { @MainActor [weak self] in
            var i = 0
            while !Task.isCancelled {
                guard let self else { break }
                let step = steps[i % steps.count]
                let freq = freqAt(base: tuning.strings[step.string].frequency, fret: step.fret)
                self.bank.add(.pluck(freq: freq, dur: stepDur * 1.6, peak: 0.22))
                self.onRiffStep?(i % steps.count)
                i += 1
                try? await Task.sleep(for: .seconds(stepDur))
            }
        }
    }

    func stopRiff() {
        riffTask?.cancel()
        riffTask = nil
    }

    // MARK: Backing loop

    func playBacking(key: Note, scale: ScaleType, barDuration: Double) {
        startIfNeeded()
        stopBacking()
        let prog = backingProgression(key: key, scale: scale)
        guard !prog.isEmpty else { return }
        let barDur = barDuration
        backingTask = Task { @MainActor [weak self] in
            var bar = 0
            while !Task.isCancelled {
                guard let self else { break }
                let chord = prog[bar % prog.count]
                let tones = chordTones(root: chord.root, isMinor: chord.isMinor)
                let root = tones[0].frequency(octave: 3)
                let third = tones[1].frequency(octave: 3)
                let fifth = tones[2].frequency(octave: 3)
                self.bank.add(.pad(freq: root, dur: barDur * 0.96, peak: 0.045))
                self.bank.add(.pad(freq: third, dur: barDur * 0.96, peak: 0.038))
                self.bank.add(.pad(freq: fifth, dur: barDur * 0.96, peak: 0.038))
                let bass = chord.root.frequency(octave: 2)
                self.bank.add(.pluck(freq: bass, dur: 0.5, peak: 0.16))
                self.bank.add(.kick())
                self.onBackingChord?(bar % prog.count)
                try? await Task.sleep(for: .seconds(barDur / 2))
                if Task.isCancelled { break }
                self.bank.add(.pluck(freq: bass, dur: 0.45, peak: 0.14))
                self.bank.add(.kick())
                try? await Task.sleep(for: .seconds(barDur / 2))
                bar += 1
            }
        }
    }

    func stopBacking() {
        backingTask?.cancel()
        backingTask = nil
    }

    func stopAll() {
        stopRiff()
        stopBacking()
        bank.reset()
    }
}
