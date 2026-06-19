# Lessons depth, revisiting, chord playback, technique, and a tuner — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let learners revisit completed lessons, give lessons real depth, let them hear whole chords, teach absolute beginners how to hold the instrument and fret a note, and add a microphone tuner for guitar and bass.

**Architecture:** Pure DSP and music helpers go in `StringTheoryCore` (TDD under `swift test`). The app keeps its single `AppModel` state object, its one `FretboardView` renderer, the OKLCH palette, and the protocol-backed audio engine. `AppModel` is the single owner of `AVAudioSession`; a new `TunerEngine` taps the mic and feeds the core pitch detector; chord strumming extends the existing `AudioEngine` protocol.

**Tech Stack:** Swift 6, SwiftUI (iOS 17), Swift Testing, AVFoundation (`AVAudioEngine`, `AVAudioSession`, `AVAudioApplication`), SwiftUI `Canvas` for the technique diagrams.

---

## File structure

**Create:**
- `StringTheoryCore/Sources/StringTheoryCore/Music/PitchDetector.swift` — YIN pitch detection, cents math, nearest-string mapping. Pure, testable.
- `StringTheoryCore/Tests/StringTheoryCoreTests/PitchDetectorTests.swift` — detection on synthesized sines, cents, nearest string.
- `App/StringTheory/Audio/AudioSessionController.swift` — the one place that sets the `AVAudioSession` category.
- `App/StringTheory/Audio/TunerEngine.swift` — `TunerEngine` protocol, `TunerReading`, `NoopTunerEngine`, `MicTunerEngine`, `TunerAnalyzer`.
- `App/StringTheory/Features/Tuner/TunerView.swift` — the tuner screen.

**Modify:**
- `StringTheoryCore/Sources/StringTheoryCore/Music/Chord.swift` — add `chordVoicingFrequencies`.
- `StringTheoryCore/Tests/StringTheoryCoreTests/ChordTests.swift` — test it.
- `App/StringTheory/Audio/AudioEngine.swift` — add `playChord` to the protocol and `NoopAudioEngine`.
- `App/StringTheory/Audio/SynthAudioEngine.swift` — implement `playChord`; route session setup through `AudioSessionController`.
- `App/StringTheory/AppModel.swift` — own the tuner; `beginTuning`/`endTuning`; `playChord`/`arpeggiate`; add `LessonDetail`, `TechniqueLesson`, `.technique` kind, `Lesson.detail`; reorder Stage 1; author deep-dive content.
- `App/StringTheory/Features/Lesson/LessonView.swift` — technique view, back/stepper navigation, review-from-top, deep-dive disclosure, scrollable content, fixed fretboard heights, chord/arpeggio play buttons.
- `App/StringTheory/Features/Home/HomeView.swift` — make done stages navigable; add a tuner button.
- `App/StringTheory/Features/Settings/SettingsView.swift` — add a TOOLS group with a Tuner row.
- `App/StringTheory/Features/Chords/ChordLibraryView.swift` — add a Play chord button.
- `App/StringTheory/Info.plist` — add `NSMicrophoneUsageDescription`.
- `docs/AppStoreReadiness.md` — document the tuner and the mic usage answer.
- `CLAUDE.md` — document the new features in the architecture section.

---

## Conventions for this plan

- Core logic is TDD: write the failing Swift Testing case, run it red, implement, run it green. Run with `swift test --package-path StringTheoryCore`.
- App, audio, and UI changes are verified by building and **running** on the simulator, per CLAUDE.md ("Run it, do not just build it"). Prefer the `xc-all` MCP tools (`xcode_build`, `xcode_test`, `simulator_*`); fall back to `xcodebuild`.
- Commit after each task. Branch is `feature/lessons-and-tuner` (already created).
- Writing style for any prose (lesson copy, docs): plain, concrete, no em dash, no AI-slop filler.

---

# Phase A — Core DSP and the audio protocol

## Task A1: Pitch detection in the core (YIN)

**Files:**
- Create: `StringTheoryCore/Sources/StringTheoryCore/Music/PitchDetector.swift`
- Test: `StringTheoryCore/Tests/StringTheoryCoreTests/PitchDetectorTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `PitchDetectorTests.swift`:

```swift
import Testing
import Foundation
@testable import StringTheoryCore

@Suite("Pitch detection")
struct PitchDetectorTests {

    /// A pure sine of `hz` for `seconds` at `sampleRate`, amplitude 0.5.
    private func sine(hz: Double, seconds: Double, sampleRate: Double = 44_100) -> [Float] {
        let n = Int(seconds * sampleRate)
        return (0..<n).map { i in
            Float(0.5 * sin(2 * .pi * hz * Double(i) / sampleRate))
        }
    }

    @Test("detects mid-range guitar A (110 Hz)")
    func detectsA() {
        let hz = detectPitchHz(sine(hz: 110, seconds: 0.2), sampleRate: 44_100)
        #expect(hz != nil)
        #expect(abs(hz! - 110) < 110 * 0.01)   // within 1 percent
    }

    @Test("detects guitar low E (82.41 Hz)")
    func detectsLowE() {
        let hz = detectPitchHz(sine(hz: 82.41, seconds: 0.25), sampleRate: 44_100)
        #expect(hz != nil)
        #expect(abs(hz! - 82.41) < 82.41 * 0.01)
    }

    @Test("detects bass low E (41.20 Hz) with a longer window")
    func detectsBassLowE() {
        let hz = detectPitchHz(sine(hz: 41.20, seconds: 0.35), sampleRate: 44_100)
        #expect(hz != nil)
        #expect(abs(hz! - 41.20) < 41.20 * 0.015)
    }

    @Test("returns nil for silence")
    func silenceIsNil() {
        let quiet = [Float](repeating: 0, count: 4096)
        #expect(detectPitchHz(quiet, sampleRate: 44_100) == nil)
    }

    @Test("cents offset is signed and symmetric")
    func cents() {
        #expect(abs(centsOff(hz: 440, targetHz: 440)) < 0.001)
        #expect(centsOff(hz: 466.16, targetHz: 440) > 99)     // ~+100 cents (a semitone)
        #expect(centsOff(hz: 415.30, targetHz: 440) < -99)    // ~-100 cents
    }

    @Test("nearest string maps a slightly sharp A to the A string")
    func nearest() {
        let result = nearestString(toHz: 112, in: .guitar)
        #expect(result.target.note == .a)
        #expect(result.cents > 0)
    }

    @Test("nearest string tells low E from high e by octave")
    func nearestOctave() {
        #expect(nearestString(toHz: 84, in: .guitar).index == 0)    // low E string
        #expect(nearestString(toHz: 320, in: .guitar).index == 5)   // high e string
    }
}
```

- [ ] **Step 2: Run the tests, verify they fail**

Run: `swift test --package-path StringTheoryCore --filter PitchDetectorTests`
Expected: FAIL, `detectPitchHz` / `centsOff` / `nearestString` are not defined.

- [ ] **Step 3: Implement the detector**

Create `PitchDetector.swift`:

```swift
import Foundation

/// Monophonic fundamental-frequency detection by the YIN algorithm
/// (de Cheveigne and Kawahara). Pure and testable: feed it a buffer of mono
/// samples and a sample rate. Returns nil for near-silence or when no clear
/// period is found. The default range spans a bass low E (about 41 Hz) up to
/// just past a high guitar e.
public func detectPitchHz(
    _ samples: [Float],
    sampleRate: Double,
    minHz: Double = 38,
    maxHz: Double = 1350,
    threshold: Double = 0.15
) -> Double? {
    let n = samples.count
    guard n > 2 else { return nil }

    let maxLag = min(n / 2, Int((sampleRate / minHz).rounded(.up)))
    let minLag = max(2, Int((sampleRate / maxHz).rounded(.down)))
    guard maxLag > minLag else { return nil }

    // Near-silence gate so the reading does not chase noise.
    var sumSquares = 0.0
    for s in samples { sumSquares += Double(s) * Double(s) }
    guard (sumSquares / Double(n)).squareRoot() > 0.01 else { return nil }

    // Difference function and its cumulative-mean normalization (CMNDF).
    let window = n - maxLag
    var cmnd = [Double](repeating: 1, count: maxLag + 1)
    var runningSum = 0.0
    for tau in 1...maxLag {
        var diff = 0.0
        for i in 0..<window {
            let delta = Double(samples[i]) - Double(samples[i + tau])
            diff += delta * delta
        }
        runningSum += diff
        cmnd[tau] = runningSum > 0 ? diff * Double(tau) / runningSum : 1
    }

    // First tau in range that dips below the threshold, then descend to its
    // local minimum (YIN's absolute-threshold step). This avoids octave errors.
    var tau = minLag
    while tau <= maxLag {
        if cmnd[tau] < threshold {
            while tau + 1 <= maxLag && cmnd[tau + 1] < cmnd[tau] { tau += 1 }
            break
        }
        tau += 1
    }
    guard tau <= maxLag, cmnd[tau] < threshold else { return nil }

    // Parabolic interpolation around the minimum for sub-sample accuracy.
    let betterTau: Double
    if tau > 1, tau < maxLag {
        let s0 = cmnd[tau - 1], s1 = cmnd[tau], s2 = cmnd[tau + 1]
        let denom = s0 - 2 * s1 + s2
        betterTau = denom != 0 ? Double(tau) + 0.5 * (s0 - s2) / denom : Double(tau)
    } else {
        betterTau = Double(tau)
    }
    return sampleRate / betterTau
}

/// Signed cents from `targetHz` to `hz` (positive = sharp).
public func centsOff(hz: Double, targetHz: Double) -> Double {
    guard hz > 0, targetHz > 0 else { return 0 }
    return 1200 * log2(hz / targetHz)
}

/// The open string in `tuning` closest to `hz` in cents, with the signed cents
/// to it. Closest in cents, so the two E strings are told apart by octave.
public func nearestString(toHz hz: Double, in tuning: Tuning) -> (index: Int, target: OpenString, cents: Double) {
    var bestIndex = 0
    var bestCents = Double.greatestFiniteMagnitude
    for (i, string) in tuning.strings.enumerated() {
        let c = centsOff(hz: hz, targetHz: string.frequency)
        if abs(c) < abs(bestCents) {
            bestCents = c
            bestIndex = i
        }
    }
    return (bestIndex, tuning.strings[bestIndex], bestCents)
}
```

- [ ] **Step 4: Run the tests, verify they pass**

Run: `swift test --package-path StringTheoryCore --filter PitchDetectorTests`
Expected: PASS, all seven tests green.

- [ ] **Step 5: Commit**

```bash
git add StringTheoryCore/Sources/StringTheoryCore/Music/PitchDetector.swift StringTheoryCore/Tests/StringTheoryCoreTests/PitchDetectorTests.swift
git commit -m "feat(core): YIN pitch detection, cents, and nearest-string mapping"
```

## Task A2: Chord voicing frequencies in the core

**Files:**
- Modify: `StringTheoryCore/Sources/StringTheoryCore/Music/Chord.swift`
- Test: `StringTheoryCore/Tests/StringTheoryCoreTests/ChordTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `ChordTests.swift` (inside the existing chord suite, or add a new `@Test`):

```swift
@Test("chord voicing frequencies skip muted strings, low to high")
func voicingFrequencies() {
    let c = Chord.named("C")!                // [-1, 3, 2, 0, 1, 0]
    let freqs = chordVoicingFrequencies(c)
    #expect(freqs.count == 5)                // low E muted, five sound
    #expect(abs(freqs.first! - 130.81) < 0.5)   // A string, 3rd fret = C3
    #expect(abs(freqs.last! - 329.63) < 0.5)    // high e open
}
```

- [ ] **Step 2: Run it, verify it fails**

Run: `swift test --package-path StringTheoryCore --filter ChordTests`
Expected: FAIL, `chordVoicingFrequencies` is not defined.

- [ ] **Step 3: Implement it**

Append to `Chord.swift`, after `chordSpan`:

```swift
/// The sounding frequency (Hz) of each non-muted string in a chord voicing,
/// low string to high, for strum ordering and chord playback. Uses the same
/// guitar tuning and `freqAt` math as the diagram, so it stays consistent.
public func chordVoicingFrequencies(_ chord: Chord, tuning: Tuning = .guitar) -> [Double] {
    chord.frets.enumerated().compactMap { stringIndex, fret in
        guard fret >= 0 else { return nil }            // -1 = muted
        return freqAt(base: tuning.strings[stringIndex].frequency, fret: fret)
    }
}
```

- [ ] **Step 4: Run it, verify it passes**

Run: `swift test --package-path StringTheoryCore --filter ChordTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add StringTheoryCore/Sources/StringTheoryCore/Music/Chord.swift StringTheoryCore/Tests/StringTheoryCoreTests/ChordTests.swift
git commit -m "feat(core): chord voicing frequencies for chord playback"
```

## Task A3: Add `playChord` to the audio protocol

**Files:**
- Modify: `App/StringTheory/Audio/AudioEngine.swift`
- Modify: `App/StringTheory/Audio/SynthAudioEngine.swift`

- [ ] **Step 1: Extend the protocol and the no-op**

In `AudioEngine.swift`, add to the protocol (after `func playNote`):

```swift
    /// Plays several frequencies as one chord. `strumGap` staggers the voices so
    /// a downstrum sounds; pass 0 for a block chord.
    func playChord(frequencies: [Double], strumGap: Double)
```

And to `NoopAudioEngine`:

```swift
    func playChord(frequencies: [Double], strumGap: Double) {}
```

- [ ] **Step 2: Implement it in the synth**

In `SynthAudioEngine.swift`, add after `playNote(frequency:)`:

```swift
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
```

- [ ] **Step 3: Build**

Run: `xcodebuild build -project StringTheory.xcodeproj -scheme StringTheory -destination 'platform=iOS Simulator,name=iPhone 16'` (or the `xcode_build` MCP tool).
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add App/StringTheory/Audio/AudioEngine.swift App/StringTheory/Audio/SynthAudioEngine.swift
git commit -m "feat(audio): playChord on the audio engine"
```

---

# Phase B — The tuner

## Task B1: The one session owner

**Files:**
- Create: `App/StringTheory/Audio/AudioSessionController.swift`
- Modify: `App/StringTheory/Audio/SynthAudioEngine.swift`

- [ ] **Step 1: Create the controller**

`AudioSessionController.swift`:

```swift
import AVFoundation

/// The single place that sets the shared audio session category. `.playback`
/// for output only; `.playAndRecord` while the tuner needs the mic (and still
/// wants reference tones). Never throws to the caller; failures are logged so a
/// session hiccup leaves playback working.
enum AudioSessionController {
    static func activate(_ category: AVAudioSession.Category) {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            let options: AVAudioSession.CategoryOptions =
                category == .playAndRecord ? [.defaultToSpeaker, .allowBluetooth] : []
            try session.setCategory(category, mode: .default, options: options)
            try session.setActive(true)
        } catch {
            print("AudioSessionController failed to set \(category): \(error)")
        }
        #endif
    }
}
```

- [ ] **Step 2: Route the synth through it without downgrading a record session**

In `SynthAudioEngine.swift`, replace the body of `startIfNeeded()` with:

```swift
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
```

(The `import AVFoundation` at the top of `SynthAudioEngine.swift` already covers `AVAudioSession`.)

- [ ] **Step 3: Build, verify existing audio still works**

Run the app on the simulator, open a tab lesson, press Play. Expected: the riff still sounds (no regression from the session change).

- [ ] **Step 4: Commit**

```bash
git add App/StringTheory/Audio/AudioSessionController.swift App/StringTheory/Audio/SynthAudioEngine.swift
git commit -m "refactor(audio): centralize AVAudioSession category control"
```

## Task B2: The tuner engine

**Files:**
- Create: `App/StringTheory/Audio/TunerEngine.swift`

- [ ] **Step 1: Write the engine**

`TunerEngine.swift`:

```swift
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
```

- [ ] **Step 2: Build**

Run the build. Expected: BUILD SUCCEEDED. (Pay attention to Swift 6 concurrency errors here; if the tap closure complains, confirm `monoSamples`/`forwarder` are `nonisolated static` and the sink is `@MainActor`.)

- [ ] **Step 3: Commit**

```bash
git add App/StringTheory/Audio/TunerEngine.swift
git commit -m "feat(audio): microphone tuner engine feeding the core detector"
```

## Task B3: AppModel owns the tuner and the session

**Files:**
- Modify: `App/StringTheory/AppModel.swift`

- [ ] **Step 1: Add imports and tuner state**

At the top of `AppModel.swift`, add `import AVFoundation` under the existing imports.

Inside `AppModel`, add to the "Playback" group of stored properties:

```swift
    // Tuner. Session-only; owned here so the one session owner is the one
    // publisher of tuner data.
    private(set) var isTuning = false
    private(set) var tunerReading: TunerReading = .idle
    /// nil until the mic has been asked for; then true (granted) or false (denied).
    private(set) var micGranted: Bool?
```

Add the engine next to the audio engine:

```swift
    @ObservationIgnored private let tuner: TunerEngine
```

- [ ] **Step 2: Construct and wire the tuner in `init`**

In `init`, after the line `audio.onBackingChord = { ... }`, add:

```swift
        tuner = MicTunerEngine(tuning: { [weak self] in self?.tuning ?? .guitar })
        tuner.onReading = { [weak self] reading in self?.tunerReading = reading }
```

Move the `tuner` assignment before its `onReading` use; since `tuner` is a `let`, assign it before the `audio.onRiffStep` block if the compiler complains about use-before-init. Concretely, place `tuner = MicTunerEngine(...)` as the first statement after `completedLessons = ...`, and set `tuner.onReading` after the `audio` callbacks.

- [ ] **Step 3: Add the tuner transport**

Add a new `// MARK: Tuner` section after the Solo transport:

```swift
    // MARK: Tuner

    func beginTuning() {
        guard !isTuning else { return }
        isTuning = true
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in self?.handleMicPermission(granted) }
        }
    }

    private func handleMicPermission(_ granted: Bool) {
        micGranted = granted
        guard isTuning else { return }              // user may have left already
        stopRiff()
        stopBacking()
        AudioSessionController.activate(.playAndRecord)
        if granted { tuner.start() }
    }

    func endTuning() {
        guard isTuning else { return }
        isTuning = false
        tuner.stop()
        tunerReading = .idle
        AudioSessionController.activate(.playback)
    }

    /// Plays the open-string reference tone for `stringIndex` on the current tuning.
    func playReferenceTone(stringIndex: Int) {
        guard tuning.strings.indices.contains(stringIndex) else { return }
        audio.playNote(frequency: tuning.strings[stringIndex].frequency)
    }
```

- [ ] **Step 4: Build**

Run the build. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add App/StringTheory/AppModel.swift
git commit -m "feat(model): own the tuner engine and the audio session"
```

## Task B4: The tuner screen

**Files:**
- Create: `App/StringTheory/Features/Tuner/TunerView.swift`

- [ ] **Step 1: Write the view**

`TunerView.swift`:

```swift
import SwiftUI
import StringTheoryCore

/// The microphone tuner. Shows a flat-to-sharp needle for the detected pitch, the
/// nearest string and cents, and a strip of open strings you can tap to hear a
/// reference tone. Starts tuning on appear and stops on disappear, so leaving the
/// screen never leaves the mic running. If the mic is denied it stays usable as
/// reference tones only.
struct TunerView: View {
    @Environment(AppModel.self) private var model

    private var strings: [OpenString] { model.tuning.strings }
    private var reading: TunerReading { model.tunerReading }
    private var inTune: Bool { reading.isVoiced && abs(reading.cents) <= 5 }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 22) {
                header
                needleCard
                referenceStrip
                if model.micGranted == false { micDeniedBanner }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .onAppear { model.beginTuning() }
        .onDisappear { model.endTuning() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TUNER · \(model.instrument == .bass ? "BASS" : "GUITAR")").sectionLabel()
            Text("Tune up")
                .font(Typography.display(28))
                .foregroundStyle(Theme.Palette.text)
        }
    }

    // The detected note, the cents readout, and a moving needle clamped to +/-50.
    private var needleCard: some View {
        VStack(spacing: 14) {
            Text(reading.isVoiced ? strings[safe: reading.stringIndex]?.note.name ?? "--" : "--")
                .font(Typography.display(64))
                .foregroundStyle(inTune ? Theme.Palette.phosphor : Theme.Palette.text)
                .glow(inTune ? Theme.Palette.phosphor : .clear, radius: inTune ? 14 : 0)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.15), value: reading.stringIndex)

            Text(reading.isVoiced ? centsLabel : "play a string")
                .font(Typography.mono(13, weight: .semibold))
                .foregroundStyle(reading.isVoiced ? (inTune ? Theme.Palette.phosphor : amber) : Theme.Palette.textDim)

            NeedleView(cents: reading.isVoiced ? reading.cents : nil, inTune: inTune, amber: amber)
                .frame(height: 56)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Theme.Palette.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.Palette.hairline, lineWidth: 1))
    }

    private var centsLabel: String {
        let c = Int(reading.cents.rounded())
        if abs(c) <= 5 { return "in tune" }
        return c > 0 ? "+\(c) cents · sharp" : "\(c) cents · flat"
    }

    private var referenceStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REFERENCE · TAP TO HEAR").sectionLabel()
            HStack(spacing: 8) {
                ForEach(Array(strings.enumerated()), id: \.offset) { index, string in
                    let isNear = reading.isVoiced && reading.stringIndex == index
                    Button { model.playReferenceTone(stringIndex: index) } label: {
                        Text(string.note.name)
                            .font(Typography.display(17, weight: .semibold))
                            .foregroundStyle(isNear ? Color(oklchL: 0.16, c: 0.03, h: 150) : Theme.Palette.text)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(RoundedRectangle(cornerRadius: 10).fill(isNear ? Theme.Palette.phosphor : Color(oklchL: 0.2, c: 0.018, h: 250)))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isNear ? Theme.Palette.phosphor : Theme.Palette.hairline, lineWidth: 1))
                            .glow(isNear ? Theme.Palette.phosphor : .clear, radius: isNear ? 10 : 0)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeOut(duration: 0.12), value: isNear)
                    .accessibilityLabel("Play reference \(string.note.name)")
                }
            }
        }
    }

    private var micDeniedBanner: some View {
        Text("Microphone access is off, so the needle is disabled. You can still tune by ear with the reference tones. Enable the mic in iOS Settings to use the needle.")
            .font(Typography.body(12))
            .foregroundStyle(Theme.Palette.textDim)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .background(Theme.Palette.panelDeep, in: RoundedRectangle(cornerRadius: 12))
    }

    private var amber: Color { Color(oklchL: 0.8, c: 0.13, h: 70) }
}

/// The flat-to-sharp meter: a track with a center mark and a dot at the cents
/// position. When `cents` is nil (idle) the dot rests at center, dimmed.
private struct NeedleView: View {
    let cents: Double?
    let inTune: Bool
    let amber: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, midX = w / 2, midY = geo.size.height / 2
            let clamped = max(-50, min(50, cents ?? 0))
            let x = midX + CGFloat(clamped / 50) * (w / 2 - 16)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.hairline).frame(height: 2).position(x: midX, y: midY)
                Rectangle().fill(Theme.Palette.phosphor.opacity(0.6)).frame(width: 2, height: 22).position(x: midX, y: midY)
                Circle()
                    .fill(cents == nil ? Theme.Palette.textDim.opacity(0.4) : (inTune ? Theme.Palette.phosphor : amber))
                    .frame(width: 18, height: 18)
                    .glow(cents == nil ? .clear : (inTune ? Theme.Palette.phosphor : amber), radius: 8)
                    .position(x: x, y: midY)
                    .animation(.easeOut(duration: 0.12), value: x)
                Text("♭").font(Typography.mono(13)).foregroundStyle(Theme.Palette.textDim).position(x: 10, y: midY)
                Text("♯").font(Typography.mono(13)).foregroundStyle(Theme.Palette.textDim).position(x: w - 10, y: midY)
            }
        }
    }
}

/// Safe indexed access for the reading's string index.
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

- [ ] **Step 2: Build**

Run the build. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add App/StringTheory/Features/Tuner/TunerView.swift
git commit -m "feat(tuner): tuner screen with needle and reference tones"
```

## Task B5: Reach the tuner from Settings and the Path header

**Files:**
- Modify: `App/StringTheory/Features/Settings/SettingsView.swift`
- Modify: `App/StringTheory/Features/Home/HomeView.swift`

- [ ] **Step 1: Add a TOOLS row to Settings**

In `SettingsView.swift`, inside the main `VStack`, after the `group("TEMPO") { ... }` block and before the trailing descriptive `Text`, add:

```swift
                    group("TOOLS") {
                        NavigationLink {
                            TunerView()
                                .navigationTitle("Tuner")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "tuningfork")
                                    .foregroundStyle(Theme.Palette.phosphor)
                                Text("Tuner")
                                    .font(Typography.display(15, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.text)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.textDim)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.horizontal, 8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open the tuner")
                    }
```

- [ ] **Step 2: Add a tuner button to the Path header**

In `HomeView.swift`, add `@State private var showTuner = false` next to `showSettings`. In the `HeaderSection` `HStack` that holds the settings gear, add a tuner button before the settings `Button`:

Change the `HeaderSection` signature to also take `onTuner`:

```swift
private struct HeaderSection: View {
    let overallPercent: Int
    let onSettings: () -> Void
    let onTuner: () -> Void
```

and the buttons block:

```swift
                Spacer()
                Button(action: onTuner) {
                    Image(systemName: "tuningfork")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Palette.textDim)
                        .frame(width: 40, height: 28, alignment: .trailing)
                }
                .accessibilityLabel("Tuner")
                Button(action: onSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Palette.textDim)
                        .frame(width: 44, height: 28, alignment: .trailing)
                }
                .accessibilityLabel("Setup")
```

In `HomeView.body`, pass the new closure and present the tuner as a sheet. Update the `HeaderSection` call:

```swift
                        HeaderSection(overallPercent: model.overallPercent,
                                      onSettings: { showSettings = true },
                                      onTuner: { showTuner = true })
```

and add, next to the existing `.sheet(isPresented: $showSettings)`:

```swift
            .sheet(isPresented: $showTuner) {
                NavigationStack {
                    TunerView()
                        .navigationTitle("Tuner")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showTuner = false }
                                    .foregroundStyle(Theme.Palette.phosphor)
                            }
                        }
                }
            }
```

- [ ] **Step 3: Build**

Run the build. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add App/StringTheory/Features/Settings/SettingsView.swift App/StringTheory/Features/Home/HomeView.swift
git commit -m "feat(tuner): open the tuner from Settings and the Path header"
```

## Task B6: Microphone permission string and privacy docs

**Files:**
- Modify: `App/StringTheory/Info.plist`
- Modify: `docs/AppStoreReadiness.md`

- [ ] **Step 1: Add the usage description**

In `App/StringTheory/Info.plist`, add inside the top-level `<dict>` (for example right after the `CFBundleVersion` pair):

```xml
	<key>NSMicrophoneUsageDescription</key>
	<string>String Theory uses the microphone only to detect the pitch of your strings for tuning. Audio is never recorded, stored, or sent.</string>
```

- [ ] **Step 2: Document it for the App Store**

In `docs/AppStoreReadiness.md`, add a short section noting: the app now includes a tuner that uses the microphone for on-device pitch detection only; nothing is recorded, stored, or transmitted; the `PrivacyInfo.xcprivacy` stays no-collection and no-tracking; the App Store privacy answer for microphone is "used for app functionality (tuning), not collected." Keep the prose plain and free of em dashes.

- [ ] **Step 3: Run the tuner end to end on the simulator**

Launch the app, open the tuner from the Path header. Grant the mic prompt. Play or whistle a pitch and confirm the needle and note name move. Tap a reference string and confirm a tone plays. Leave the screen and confirm other audio (a tab lesson Play) still works (session restored to `.playback`). Decline the mic on a fresh install and confirm the reference tones still work with the denied banner shown.

- [ ] **Step 4: Commit**

```bash
git add App/StringTheory/Info.plist docs/AppStoreReadiness.md
git commit -m "feat(tuner): microphone usage string and privacy notes"
```

---

# Phase C — Play the chords

## Task C1: Chord and arpeggio playback in AppModel

**Files:**
- Modify: `App/StringTheory/AppModel.swift`

- [ ] **Step 1: Add the methods**

In `AppModel.swift`, after `playNote(string:fret:)`, add:

```swift
    /// Strums a guitar chord voicing (always guitar, matching the diagrams).
    func playChord(_ chord: Chord) {
        audio.playChord(frequencies: chordVoicingFrequencies(chord), strumGap: 0.028)
    }

    /// Sounds a triad's root, third, and fifth in sequence (the bass arpeggio
    /// lessons). Bass voices an octave lower than guitar.
    func arpeggiate(root: Note, isMinor: Bool) {
        let octave = instrument == .bass ? 2 : 3
        let freqs = chordTones(root: root, isMinor: isMinor).map { $0.frequency(octave: octave) }
        audio.playChord(frequencies: freqs, strumGap: 0.16)
    }
```

- [ ] **Step 2: Build**

Run the build. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add App/StringTheory/AppModel.swift
git commit -m "feat(model): strum chords and arpeggiate triads"
```

## Task C2: Play buttons in the chord lesson, the library, and the arpeggio lesson

**Files:**
- Modify: `App/StringTheory/Features/Lesson/LessonView.swift`
- Modify: `App/StringTheory/Features/Chords/ChordLibraryView.swift`

- [ ] **Step 1: Add a Play chord button to `ChordsLessonView`**

In `LessonView.swift`, in `ChordsLessonView.body`, replace the `HStack(spacing: 8) { Text("NOTES")... }` block at the bottom with this, which keeps the notes readout and adds a strum button:

```swift
            HStack(spacing: 12) {
                Button { model.playChord(chord) } label: {
                    Text("▶  Play chord")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel("Play the \(chord.name) chord")

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("NOTES").sectionLabel()
                    Text(soundedNotes.map(\.name).joined(separator: " · "))
                        .font(Typography.mono(13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.signalCyan)
                }
            }
```

- [ ] **Step 2: Add a Play button to `ArpeggioLessonView`**

In `LessonView.swift`, change `ArpeggioLessonView.body` to stack the fretboard with a play button:

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FretboardView(
                geometry: FretboardGeometry(stringCount: model.stringCount, fretCount: 12,
                                            startFret: 0, isLeftHanded: model.isLeftHanded),
                openNotes: model.openNotes,
                markers: arpeggioMarkers(instrument: model.instrument, root: root, isMinor: isMinor, frets: 12),
                onTapPosition: { string, fret in model.playNote(string: string, fret: fret) }
            )
            .frame(maxWidth: .infinity)
            .frame(height: 290)
            .panel()

            Button { model.arpeggiate(root: root, isMinor: isMinor) } label: {
                Text("▶  Play root · 3 · 5")
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel("Play the arpeggio")
        }
    }
```

(The fixed `height: 290` here lands ahead of the scrollable-layout change in Phase F; keep it.)

- [ ] **Step 3: Add a Play button to the Chord Library card**

In `ChordLibraryView.swift`, in `diagramCard`, after the `FretboardView(...)` block (still inside the card `VStack`), add:

```swift
            Button { model.playChord(chord) } label: {
                Text("▶  Play chord")
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel("Play the \(chord.name) chord")
```

- [ ] **Step 4: Run it**

Launch the app. In a guitar Chords lesson press Play chord and confirm a strum. In the Chord Library, load a few chords and play them. Switch to bass, open the bass Chords stage, and confirm the arpeggio plays root, third, fifth.

- [ ] **Step 5: Commit**

```bash
git add App/StringTheory/Features/Lesson/LessonView.swift App/StringTheory/Features/Chords/ChordLibraryView.swift
git commit -m "feat(lessons): play whole chords and arpeggios, not only tapped notes"
```

---

# Phase D — Revisit completed lessons

## Task D1: Make completed stages navigable

**Files:**
- Modify: `App/StringTheory/Features/Home/HomeView.swift`

- [ ] **Step 1: Wrap the done card in a NavigationLink**

In `HomeView.swift`, in `StageRow.body`, replace the `.done` case of the inner `switch` with:

```swift
                case .done:
                    if let learning = model.stages.first(where: { $0.id == stage.id }) {
                        NavigationLink(destination: StageLessonsView(stage: learning)) {
                            StageCard(stage: stage)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Stage \(stage.number): \(stage.title). Complete. Tap to review.")
                    }
```

- [ ] **Step 2: Run it**

Launch the app with a completed stage (finish Stage 1 if needed). Confirm the completed stage card is now tappable and opens its lessons, and the locked stages stay non-tappable.

- [ ] **Step 3: Commit**

```bash
git add App/StringTheory/Features/Home/HomeView.swift
git commit -m "feat(path): reopen completed stages to review them"
```

## Task D2: Back and stepper navigation inside a stage

**Files:**
- Modify: `App/StringTheory/Features/Lesson/LessonView.swift`

- [ ] **Step 1: Review a finished stage from the top**

In `StageLessonsView`, replace the `.onAppear` body that sets `index` with:

```swift
        .onAppear {
            let allDone = stage.lessons.allSatisfy { model.isLessonComplete(stageID: stage.id, lessonID: $0.id) }
            index = allDone
                ? 0
                : (stage.lessons.firstIndex { !model.isLessonComplete(stageID: stage.id, lessonID: $0.id) } ?? 0)
        }
```

- [ ] **Step 2: Add a back step and a tappable dot stepper to the header**

In `StageLessonsView.content`, replace the opening `HStack { Text("STAGE ...") ... }` block with:

```swift
            HStack(spacing: 10) {
                if index > 0 {
                    Button { back() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.Palette.phosphor)
                    .accessibilityLabel("Previous lesson")
                }
                Text("STAGE \(stage.number)").sectionLabel()
                Spacer()
                if stage.lessons.count > 1 {
                    LessonDots(count: stage.lessons.count, index: index) { target in
                        model.stopRiff(); model.stopBacking()
                        index = target
                    }
                }
            }
```

Add the `back()` helper to `StageLessonsView` (next to `advance()`):

```swift
    private func back() {
        guard index > 0 else { return }
        model.stopRiff()
        model.stopBacking()
        index -= 1
    }
```

- [ ] **Step 3: Add the `LessonDots` view**

At the end of `LessonView.swift`, add:

```swift
// MARK: - Lesson stepper

/// A tappable row of dots for jumping between a stage's lessons. The current
/// lesson glows; any lesson can be revisited.
private struct LessonDots: View {
    let count: Int
    let index: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Button { onSelect(i) } label: {
                    Circle()
                        .fill(i == index ? Theme.Palette.phosphor : Theme.Palette.textDim.opacity(0.4))
                        .frame(width: 7, height: 7)
                        .glow(i == index ? Theme.Palette.phosphor : .clear, radius: i == index ? 5 : 0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Go to lesson \(i + 1)")
                .accessibilityAddTraits(i == index ? [.isSelected] : [])
            }
        }
    }
}
```

- [ ] **Step 4: Run it**

Launch a stage with several lessons. Confirm the dots show the current lesson, tapping a dot jumps to it, the back chevron steps back, audio stops when you move, and reaching the end still finishes. Reopen a completed stage and confirm it starts at lesson 1.

- [ ] **Step 5: Commit**

```bash
git add App/StringTheory/Features/Lesson/LessonView.swift
git commit -m "feat(lessons): step back and jump between lessons in a stage"
```

---

# Phase E — Technique lessons (Fretboard Basics)

## Task E1: The `.technique` lesson kind

**Files:**
- Modify: `App/StringTheory/AppModel.swift`

- [ ] **Step 1: Add the kind and its enum**

In `AppModel.swift`, in `enum LessonKind`, add a case:

```swift
    case technique(TechniqueLesson)
```

Below `enum ExploreLesson`, add:

```swift
/// A beginner technique screen in Fretboard Basics, drawn as a SwiftUI diagram.
enum TechniqueLesson: Hashable {
    case holding   // how the instrument sits and where the hands go
    case fretting  // pressing a string with the fingertip just behind the fret
}
```

- [ ] **Step 2: Reorder Stage 1 to lead with technique**

Replace `LearningPath.fretboardBasics` with:

```swift
    private static let fretboardBasics = LearningStage(
        id: 1, number: "01", title: "Fretboard Basics",
        subtitle: "Holding the instrument · fretting · string names · note positions",
        lessons: [
            Lesson(id: 1, title: "Holding the instrument",
                   subtitle: "Before any notes, get comfortable. Here is how the instrument sits and where your hands go.",
                   kind: .technique(.holding)),
            Lesson(id: 2, title: "Fretting a note",
                   subtitle: "Press the string against the fret with your fingertip, just hard enough to ring clean.",
                   kind: .technique(.fretting)),
            Lesson(id: 3, title: "Open strings",
                   subtitle: "These are your open strings, low to high. Tap each one to hear it.",
                   kind: .explore(.openStrings)),
            Lesson(id: 4, title: "Fret numbers",
                   subtitle: "Frets count up from the nut, each one a semitone higher. Tap a fret to hear it.",
                   kind: .explore(.fretNumbers)),
            Lesson(id: 5, title: "Find a note",
                   subtitle: "The same note lives in many places. Here is every A in the first few frets. Tap any to hear it.",
                   kind: .explore(.findNote(.a))),
        ])
```

(Deep-dive `detail:` values are added in Phase G; do not add them yet.)

- [ ] **Step 3: Build**

The build will fail until `LessonView` handles `.technique`. That is the next task; you can build after E2. Skip running here.

- [ ] **Step 4: Commit**

```bash
git add App/StringTheory/AppModel.swift
git commit -m "feat(lessons): add the technique lesson kind and lead Stage 1 with it"
```

## Task E2: The technique view and its diagrams

**Files:**
- Modify: `App/StringTheory/Features/Lesson/LessonView.swift`

- [ ] **Step 1: Handle `.technique` in the content and footer switches**

In `StageLessonsView.content`, add a case to the `switch lesson.kind`:

```swift
            case .technique(let technique):
                TechniqueLessonView(lesson: technique)
```

In `StageLessonsView.footer`, add `.technique` to the plain-forward case:

```swift
        case .reading, .explore, .scale, .chords, .arpeggio, .technique:
            bottomBar { forwardButton }
```

- [ ] **Step 2: Add the technique view and diagrams**

At the end of `LessonView.swift`, add:

```swift
// MARK: - Technique lesson content (drawn diagrams, Fretboard Basics)

/// A beginner technique screen: a drawn diagram plus a short list of cues. No
/// fretboard and no audio. `.holding` adapts for guitar versus bass.
private struct TechniqueLessonView: View {
    let lesson: TechniqueLesson
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Group {
                switch lesson {
                case .holding:  HoldingDiagram(instrument: model.instrument)
                case .fretting: FrettingDiagram()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .panel()

            VStack(alignment: .leading, spacing: 9) {
                ForEach(cues, id: \.self) { cue in
                    HStack(alignment: .top, spacing: 9) {
                        Circle().fill(Theme.Palette.phosphor)
                            .frame(width: 5, height: 5).padding(.top, 6)
                        Text(cue)
                            .font(Typography.body(13))
                            .foregroundStyle(Theme.Palette.textDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var cues: [String] {
        switch lesson {
        case .holding:
            return model.instrument == .bass
                ? ["Sit with the bass against your stomach, its waist on your strong-side leg.",
                   "Let the neck point up and out, not flat across your body.",
                   "Thumb rests behind the neck, roughly opposite your fingers; keep the hand loose.",
                   "Your plucking hand floats over the strings near the pickups."]
                : ["Sit with the guitar against your stomach, its waist on your strong-side leg.",
                   "Angle the neck slightly up so your fretting wrist stays straight, not bent.",
                   "Thumb rests behind the neck, roughly opposite your fingers.",
                   "Your strumming hand floats over the sound hole or pickups."]
        case .fretting:
            return ["Press with the very tip of the finger, not the flat pad.",
                    "Land just behind the fret, never on top of it.",
                    "Keep the knuckle bent so the tip comes straight down.",
                    "Press only until the note rings clean. No buzz is enough; white knuckles is too hard.",
                    "Short nails let the fingertip stand up on the string."]
        }
    }
}

/// A schematic of the instrument at a playing angle, with the two hand zones
/// marked. Tuned for clarity, not realism.
private struct HoldingDiagram: View {
    let instrument: Instrument

    var body: some View {
        Canvas { ctx, size in
            let dim = GraphicsContext.Shading.color(Theme.Palette.textDim.opacity(0.55))
            let phosphor = GraphicsContext.Shading.color(Theme.Palette.phosphor)
            let cyan = GraphicsContext.Shading.color(Theme.Palette.signalCyan)
            let w = size.width, h = size.height

            // Body blob, lower-left.
            let bodyCenter = CGPoint(x: w * 0.34, y: h * 0.66)
            let bodyW = w * 0.30, bodyH = h * 0.40
            let body = Path(ellipseIn: CGRect(x: bodyCenter.x - bodyW / 2, y: bodyCenter.y - bodyH / 2,
                                              width: bodyW, height: bodyH))
            ctx.stroke(body, with: dim, lineWidth: 2)

            // Neck up to the upper-right.
            let neckLength = (instrument == .bass ? 0.60 : 0.50) * w
            let neckWidth: CGFloat = instrument == .bass ? 13 : 17
            let start = CGPoint(x: bodyCenter.x + bodyW * 0.18, y: bodyCenter.y - bodyH * 0.18)
            let angle = -0.5
            let end = CGPoint(x: start.x + CoreGraphics.cos(angle) * neckLength,
                              y: start.y + CoreGraphics.sin(angle) * neckLength)
            var neck = Path(); neck.move(to: start); neck.addLine(to: end)
            ctx.stroke(neck, with: phosphor, lineWidth: neckWidth)

            // Hand zones: fretting near the neck end, plucking over the body.
            func dot(_ p: CGPoint) { ctx.fill(Path(ellipseIn: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16)), with: cyan) }
            let fretHand = CGPoint(x: start.x + CoreGraphics.cos(angle) * neckLength * 0.78,
                                   y: start.y + CoreGraphics.sin(angle) * neckLength * 0.78 + 14)
            let pluckHand = CGPoint(x: bodyCenter.x + bodyW * 0.05, y: bodyCenter.y)
            dot(fretHand); dot(pluckHand)

            ctx.draw(Text("neck up + out").font(Typography.mono(10)).foregroundColor(Theme.Palette.textDim),
                     at: CGPoint(x: end.x - 4, y: end.y - 18))
            ctx.draw(Text("fretting hand").font(Typography.mono(10)).foregroundColor(Theme.Palette.signalCyan),
                     at: CGPoint(x: fretHand.x, y: fretHand.y + 18))
            ctx.draw(Text("plucking hand").font(Typography.mono(10)).foregroundColor(Theme.Palette.signalCyan),
                     at: CGPoint(x: pluckHand.x, y: pluckHand.y + 26))
        }
    }
}

/// A zoomed cross-section: a string over a fret, with a bent fingertip pressing
/// just behind the fret. The cyan dot is the contact point.
private struct FrettingDiagram: View {
    var body: some View {
        Canvas { ctx, size in
            let dim = GraphicsContext.Shading.color(Theme.Palette.textDim.opacity(0.6))
            let phosphor = GraphicsContext.Shading.color(Theme.Palette.phosphor)
            let cyan = GraphicsContext.Shading.color(Theme.Palette.signalCyan)
            let w = size.width, h = size.height
            let stringY = h * 0.62

            // The string.
            var stringPath = Path()
            stringPath.move(to: CGPoint(x: w * 0.08, y: stringY))
            stringPath.addLine(to: CGPoint(x: w * 0.92, y: stringY))
            ctx.stroke(stringPath, with: dim, lineWidth: 2)

            // Two frets (vertical ticks); the target fret is brighter.
            func fret(_ x: CGFloat, bright: Bool) {
                var p = Path(); p.move(to: CGPoint(x: x, y: stringY - 18)); p.addLine(to: CGPoint(x: x, y: stringY + 18))
                ctx.stroke(p, with: bright ? phosphor : dim, lineWidth: bright ? 3 : 2)
            }
            let targetFretX = w * 0.58
            fret(w * 0.30, bright: false)
            fret(targetFretX, bright: true)

            // The finger: a bent shape coming down just behind the target fret.
            let contact = CGPoint(x: targetFretX - w * 0.07, y: stringY)
            var finger = Path()
            finger.move(to: CGPoint(x: contact.x - 36, y: stringY - 96))
            finger.addQuadCurve(to: CGPoint(x: contact.x - 6, y: stringY - 30),
                                control: CGPoint(x: contact.x - 34, y: stringY - 48))
            finger.addQuadCurve(to: contact, control: CGPoint(x: contact.x - 2, y: stringY - 12))
            ctx.stroke(finger, with: GraphicsContext.Shading.color(Theme.Palette.text), lineWidth: 14)

            // Contact dot.
            ctx.fill(Path(ellipseIn: CGRect(x: contact.x - 7, y: contact.y - 7, width: 14, height: 14)), with: cyan)

            ctx.draw(Text("just behind the fret").font(Typography.mono(10)).foregroundColor(Theme.Palette.signalCyan),
                     at: CGPoint(x: contact.x + 6, y: stringY + 26))
            ctx.draw(Text("fret").font(Typography.mono(10)).foregroundColor(Theme.Palette.phosphor),
                     at: CGPoint(x: targetFretX, y: stringY - 30))
        }
    }
}
```

Note: `CoreGraphics.cos`/`CoreGraphics.sin` need `import CoreGraphics`; SwiftUI already transitively provides them, but if the build complains add `import CoreGraphics` at the top of `LessonView.swift`, or use `Foundation`'s `cos`/`sin` on `Double`.

- [ ] **Step 3: Build and run**

Run the app. Open Stage 1 and confirm the first two lessons show the holding and fretting diagrams with their cue lists, that Next advances through them into Open strings, and that switching instrument to bass changes the holding diagram and cues. Tune the diagram coordinates visually if anything reads oddly.

- [ ] **Step 4: Commit**

```bash
git add App/StringTheory/Features/Lesson/LessonView.swift
git commit -m "feat(lessons): drawn holding and fretting technique screens"
```

---

# Phase F — Lesson deep-dive mechanism

## Task F1: The `LessonDetail` data and a scrollable, fixed-height layout

**Files:**
- Modify: `App/StringTheory/AppModel.swift`
- Modify: `App/StringTheory/Features/Lesson/LessonView.swift`

- [ ] **Step 1: Add the detail type and the optional field**

In `AppModel.swift`, above `struct Lesson`, add:

```swift
/// An expandable "Learn more" deep-dive attached to a lesson: a heading, a few
/// short paragraphs, and optional bullet cues. Plain data, rendered by the lesson.
struct LessonDetail: Hashable {
    let heading: String
    let paragraphs: [String]
    var bullets: [String] = []
}
```

Add the field to `Lesson` (after `var handoff`):

```swift
    /// An optional "Learn more" deep-dive shown under the interactive area.
    var detail: LessonDetail? = nil
```

- [ ] **Step 2: Make the lesson content scroll and give the fretboards fixed heights**

In `LessonView.swift`, in `StageLessonsView.body`, wrap `content` in a `ScrollView`:

```swift
            VStack(spacing: 0) {
                ScrollView {
                    content
                        .frame(maxWidth: .infinity, alignment: .top)
                }
                footer
            }
```

In each interactive sub-view, replace the greedy `.frame(maxWidth: .infinity, maxHeight: .infinity)` on the `FretboardView` with a fixed height so it lays out inside a scroll:

- `TabLessonView`: change the fretboard frame to `.frame(maxWidth: .infinity).frame(height: 230)`.
- `ExploreLessonView`: same, `.frame(height: 230)`.
- `ScaleLessonView`: `.frame(height: 290)`.
- `BackingLessonView`: the fretboard `.frame(height: 290)`.
- `ChordsLessonView`: the fretboard `.frame(height: 230)`.
- `ArpeggioLessonView`: already `.frame(height: 290)` from Task C2.
- `TechniqueLessonView`: already `.frame(height: 240)`.

Also change `StageLessonsView.content`'s outer `VStack` so it no longer forces full height; remove `maxHeight: .infinity` from the content's own frame if present (the `ScrollView` now owns the height). Keep `.padding(.horizontal, 20).padding(.top, 12)` and add `.padding(.bottom, 16)`.

- [ ] **Step 3: Render the deep-dive disclosure**

Add `@State private var showDetail = false` to `StageLessonsView`. In `content`, after the `switch lesson.kind { ... }` block and before the closing of the `VStack`, add:

```swift
            if let detail = lesson.detail {
                DisclosureGroup(isExpanded: $showDetail) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(detail.paragraphs, id: \.self) { paragraph in
                            Text(paragraph)
                                .font(Typography.body(13))
                                .foregroundStyle(Theme.Palette.text)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(detail.bullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 9) {
                                Circle().fill(Theme.Palette.signalCyan)
                                    .frame(width: 5, height: 5).padding(.top, 6)
                                Text(bullet)
                                    .font(Typography.body(13))
                                    .foregroundStyle(Theme.Palette.textDim)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text(detail.heading)
                        .font(Typography.display(14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.phosphor)
                }
                .tint(Theme.Palette.phosphor)
                .padding(.top, 4)
            }
```

Reset the disclosure when the lesson changes. In the existing `.onChange(of: lesson.id)` block, add `showDetail = false`:

```swift
        .onChange(of: lesson.id) {
            showDetail = false
            model.stopRiff()
            model.stopBacking()
        }
```

- [ ] **Step 4: Run it**

Launch a lesson that you will give a detail to in Phase G (or temporarily add a throwaway `detail:` to one lesson to test). Confirm the "Learn more" row appears, expands and collapses, scrolls when long, and that the interactive fretboard still shows at its fixed height with the footer pinned.

- [ ] **Step 5: Commit**

```bash
git add App/StringTheory/AppModel.swift App/StringTheory/Features/Lesson/LessonView.swift
git commit -m "feat(lessons): expandable deep-dive panel and scrollable lesson layout"
```

---

# Phase G — Deep-dive content

This phase is data only: it fills in `detail:` on the lessons in `LearningPath`. The prose is written here in full so there is nothing to invent. Keep the house style: plain, concrete, no em dash. This is the phase to hand to a cheaper model for entry, then review against the text below.

## Task G1: Stage 1 deep-dives (Fretboard Basics)

**Files:**
- Modify: `App/StringTheory/AppModel.swift`

- [ ] **Step 1: Attach details to the five Stage 1 lessons**

Set `detail:` on each `Lesson` in `fretboardBasics`:

- Lesson 1 "Holding the instrument":
```swift
detail: LessonDetail(
    heading: "Why posture matters",
    paragraphs: [
        "Good posture is not about looking right, it is about lasting. A bent wrist or a hunched back tires you out in minutes and is where most beginners quietly give up.",
        "Keep the instrument pulled in against your body so it does not slide, and let the neck ride a little up and out. That angle is what lets your fretting wrist stay straight instead of cranked."
    ],
    bullets: [
        "If your wrist aches, raise the neck angle before you blame your hand.",
        "A strap, even sitting down, takes the weight off your fretting hand."
    ])
```

- Lesson 2 "Fretting a note":
```swift
detail: LessonDetail(
    heading: "How hard to press",
    paragraphs: [
        "New players almost always press too hard. You need far less force than you think. Press, pluck, and the moment the note rings clean with no buzz, that is exactly enough.",
        "Place the fingertip just behind the fret, not in the middle of the gap and never on the metal itself. Right behind the fret is where the least pressure gives the cleanest note."
    ],
    bullets: [
        "Buzz usually means you are too far from the fret, not pressing too softly.",
        "A muffled, dead note usually means the finger is touching a neighboring string.",
        "Sore fingertips are normal at first and build into calluses within a couple of weeks."
    ])
```

- Lesson 3 "Open strings":
```swift
detail: LessonDetail(
    heading: "Why these notes",
    paragraphs: [
        "Standard tuning, low to high, is E A D G B E on guitar and E A D G on bass. Most neighboring strings are a fourth apart, which keeps shapes compact and repeatable up the neck.",
        "On guitar the one exception is G to B, a third, which is why a few chord shapes feel different on the top strings. Learning the open-string names cold pays off the moment you start naming frets."
    ],
    bullets: [
        "A common memory hook: Eddie Ate Dynamite, Good Bye Eddie.",
        "The lowest and highest guitar strings are both E, two octaves apart."
    ])
```

- Lesson 4 "Fret numbers":
```swift
detail: LessonDetail(
    heading: "Frets are semitones",
    paragraphs: [
        "Each fret raises the pitch by one semitone, the smallest step in Western music. Twelve frets up and you are back to the same note one octave higher.",
        "That is the whole logic of the neck: it is the same twelve notes repeating. Once you can count semitones from an open string, you can name any fret without memorizing them one by one."
    ],
    bullets: [
        "The dots on the neck mark frets 3, 5, 7, 9, and a double dot at 12.",
        "Fret 12 is the octave, where the pattern starts over."
    ])
```

- Lesson 5 "Find a note":
```swift
detail: LessonDetail(
    heading: "One note, many places",
    paragraphs: [
        "The same pitch shows up in several spots because the strings overlap in range. That is not clutter, it is choice: you can play a phrase where your hand already is instead of jumping around.",
        "Seeing every A at once trains the map in your head. Later, finding the nearest root under your fingers is what makes scales and chords feel reachable instead of memorized."
    ])
```

- [ ] **Step 2: Build and run**

Open Stage 1 and confirm each lesson now has a working "Learn more" panel with the text above.

- [ ] **Step 3: Commit**

```bash
git add App/StringTheory/AppModel.swift
git commit -m "content: deep-dives for Fretboard Basics"
```

## Task G2: Stage 2 deep-dives (Tabs, both instruments)

**Files:**
- Modify: `App/StringTheory/AppModel.swift`

- [ ] **Step 1: Attach details to the guitar Tabs lessons**

In `tabs(for:)`, set `detail:` on the guitar lessons:

- L1 "Reading a tab number":
```swift
detail: LessonDetail(
    heading: "What tab does and does not tell you",
    paragraphs: [
        "Tab is a map of where to put your fingers: which string, which fret. It is fast to read and needs no theory, which is why so much guitar and bass music is shared this way.",
        "What plain tab leaves out is rhythm. It shows you the notes in order but not how long each lasts, so you still need to know the tune in your ear or hear it played."
    ],
    bullets: [
        "0 means play the open string; a number means fret that number.",
        "Bottom line is the lowest string, which trips up readers who expect the opposite."
    ])
```

- L2 "One string, climbing":
```swift
detail: LessonDetail(
    heading: "Pitch and fret distance",
    paragraphs: [
        "Moving up the same string is the clearest way to feel that higher fret equals higher pitch. Each step is one semitone, and twelve of them is an octave.",
        "Notice the frets get physically closer together as you climb. The spacing is not even on purpose; it is what keeps every step the same musical distance."
    ])
```

- L3 "Crossing strings":
```swift
detail: LessonDetail(
    heading: "Same note, two strings",
    paragraphs: [
        "Jumping between strings lets you reach notes without sliding your whole hand. A phrase that would be a big stretch on one string sits under four fingers when you use two.",
        "The fifth fret of a lower string is usually the same pitch as the next string open. That overlap is the trick behind playing in one comfortable position."
    ])
```

- L4 "Timing and repeats":
```swift
detail: LessonDetail(
    heading: "Loops and feel",
    paragraphs: [
        "Most parts are short patterns that repeat. Once a loop is under your fingers, your attention is free for timing and tone instead of the next note.",
        "Play it slow until it is even, then let it come around a few times before you speed up. Steady and slow beats fast and ragged every time."
    ])
```

- L5 "Play Drift":
```swift
detail: LessonDetail(
    heading: "Putting it together",
    paragraphs: [
        "A full riff strings the moves you just practiced into one phrase: climbing, crossing, and repeating. Follow the lit note on the neck and let your hand learn the path.",
        "Lock it in slowly. The goal is not speed, it is that the riff plays itself while you listen."
    ])
```

- [ ] **Step 2: Attach details to the bass Tabs lessons**

Set `detail:` on the bass lessons in `tabs(for:)`:

- L1 "Reading a tab number":
```swift
detail: LessonDetail(
    heading: "Bass tab, four lines",
    paragraphs: [
        "Bass tab works the same as guitar tab with four lines instead of six. The bottom line is your low E, the thickest string, and a number is the fret to press.",
        "Bass usually carries one note at a time, so reading it is mostly about which string and when. Rhythm still lives in your ear, not on the page."
    ])
```

- L2 "One string, climbing":
```swift
detail: LessonDetail(
    heading: "Feeling the low end",
    paragraphs: [
        "Climbing one string on bass makes the octave obvious because the low notes are so physical. Twelve frets up is the same note, one octave higher.",
        "Let each note ring its full length. On bass, how long a note sustains is as much the part as the note itself."
    ])
```

- L3 "Crossing strings":
```swift
detail: LessonDetail(
    heading: "Staying in position",
    paragraphs: [
        "Moving across the low strings keeps your hand in one place while the line jumps around. That economy is what lets bass lines stay relaxed at speed.",
        "A note on a lower string at the fifth fret matches the next string open. Use that to find the easiest path, not the obvious one."
    ])
```

- L4 "Locking with the beat":
```swift
detail: LessonDetail(
    heading: "Where the note lands",
    paragraphs: [
        "Bass is a rhythm instrument as much as a pitched one. A groove is about exactly when each note hits, not just which note it is.",
        "Play with the kick drum in mind. Landing right on the beat, or just behind it, is what makes a line feel solid."
    ])
```

- L5 "Play the bassline":
```swift
detail: LessonDetail(
    heading: "Holding it down",
    paragraphs: [
        "A full bassline is your first taste of the job: keep time, outline the chord, leave space. Follow the neck and let the pattern settle into your hand.",
        "Once it loops without thought, try locking even tighter to the beat. That pocket is the whole point of the instrument."
    ])
```

- [ ] **Step 3: Build, run, commit**

```bash
git add App/StringTheory/AppModel.swift
git commit -m "content: deep-dives for Tabs, guitar and bass"
```

## Task G3: Stage 3 deep-dives (Chords, both instruments)

**Files:**
- Modify: `App/StringTheory/AppModel.swift`

- [ ] **Step 1: Guitar Chords details**

In `chords(for:)`, set `detail:` on the guitar lessons:

- L1 "Reading a chord diagram":
```swift
detail: LessonDetail(
    heading: "The diagram is the neck head on",
    paragraphs: [
        "Turn the neck to face you and that is the diagram. Vertical lines are strings, horizontal lines are frets, and a dot is a finger pressing there.",
        "A ring above a string means play it open, an x means do not play it at all. Reading those three marks is most of what you need to learn any new shape."
    ],
    bullets: [
        "Now you can hear the whole shape: press Play chord to strum it.",
        "The numbers off the diagram, when shown, tell you which finger to use."
    ])
```

- L2 "E and Em":
```swift
detail: LessonDetail(
    heading: "What makes a chord minor",
    paragraphs: [
        "Major and minor differ by one note, the third. Lower the third by a semitone and a bright major chord turns into a darker minor one.",
        "E to E minor is the clearest example because you only lift a single finger. Strum both and the drop in mood is the third moving down."
    ])
```

- L3 "A and Am":
```swift
detail: LessonDetail(
    heading: "The same move, a new shape",
    paragraphs: [
        "A to A minor is the same idea as E to E minor: the third drops a semitone. Different shape, identical logic.",
        "Once you hear that the lowered third is what makes minor, you can find it in any chord instead of memorizing each pair separately."
    ])
```

- L4 "D and Dm":
```swift
detail: LessonDetail(
    heading: "Partial chords",
    paragraphs: [
        "The D shapes only use the top four strings. The low two are left out on purpose, marked with an x, because they are not part of this voicing.",
        "Muting strings you do not want is a real skill. Resting a spare finger lightly against them keeps the chord clean."
    ])
```

- L5 "G and C":
```swift
detail: LessonDetail(
    heading: "Workhorse chords",
    paragraphs: [
        "G and C show up in a huge share of songs, often right next to each other. Getting a clean change between them unlocks a lot of music.",
        "When these feel steady, the Chord Library has every other shape, including the barre chords F and B minor that let you move a shape anywhere."
    ],
    bullets: ["Open the Chord Library to strum and explore every voicing."])
```

- [ ] **Step 2: Bass Chords details**

Set `detail:` on the bass lessons in `chords(for:)`:

- L1 "Play the root":
```swift
detail: LessonDetail(
    heading: "The root is your anchor",
    paragraphs: [
        "Bass rarely plays full chords. Instead you play the chord's root, the note it is named after, and that single note tells the ear which chord it is.",
        "Get comfortable finding the root fast. Almost everything else on bass is built out from it."
    ],
    bullets: ["Press Play root, 3, 5 to hear the chord spelled out one note at a time."])
```

- L2 "Find every root":
```swift
detail: LessonDetail(
    heading: "Roots repeat all over the neck",
    paragraphs: [
        "Every note exists in several places, so each root sits under your hand in more than one spot. Knowing the nearest one keeps your playing smooth.",
        "Same note, an octave up, is a common bass move: it adds energy without changing the harmony."
    ])
```

- L3 "Root and fifth":
```swift
detail: LessonDetail(
    heading: "The strongest pair",
    paragraphs: [
        "Root to fifth is the most stable jump in music and the backbone of countless basslines. The fifth supports the root without coloring the chord major or minor.",
        "On the neck the fifth usually sits right next door, one string up and a couple of frets over. That shape stays the same wherever you move it."
    ])
```

- L4 "Add the third":
```swift
detail: LessonDetail(
    heading: "The third sets the mood",
    paragraphs: [
        "The third is the note that makes a chord major or minor. A flattened third is what gives this A minor its darker color.",
        "Walking root, third, fifth spells the whole chord with your bass alone. It is the seed of basslines that move instead of just holding the root."
    ])
```

- L5 "Walk a I-IV-V":
```swift
detail: LessonDetail(
    heading: "Three chords, one key",
    paragraphs: [
        "The I, IV, and V chords are the three most common in any key. In C they are C, F, and G, and together they harmonize a huge number of songs.",
        "Use the root as home and the third and fifth to move between chords. This is your sandbox: there is no Chord Library on bass because the neck itself is the tool."
    ])
```

- [ ] **Step 3: Build, run, commit**

```bash
git add App/StringTheory/AppModel.swift
git commit -m "content: deep-dives for Chords, guitar and bass"
```

## Task G4: Stage 4 and Stage 5 deep-dives

**Files:**
- Modify: `App/StringTheory/AppModel.swift`

- [ ] **Step 1: Scales & Keys details**

In `scalesAndKeys`, set `detail:` on each lesson:

- L1 "What a scale is":
```swift
detail: LessonDetail(
    heading: "A scale is a filter",
    paragraphs: [
        "A scale is just the set of notes that belong to a key. Play inside it and things sound right; the scale is doing the work of keeping you in tune with the song.",
        "The minor pentatonic is five notes per octave, which is why it feels so forgiving. Fewer notes means fewer ways to sound wrong."
    ])
```

- L2 "The root and the degrees":
```swift
detail: LessonDetail(
    heading: "Numbering the notes",
    paragraphs: [
        "Naming each note by its distance from the root, 1 through 5 here, lets you talk about a scale without naming the key. The same numbers work in every key.",
        "The root, degree 1, is home base. Phrases that start or end on it sound settled, which is your first handle on making a melody resolve."
    ])
```

- L3 "Minor vs major pentatonic":
```swift
detail: LessonDetail(
    heading: "Same notes, different home",
    paragraphs: [
        "Major and minor pentatonic in the same key share a shape but center on a different note. Move the root and the bright sound turns moody, or back again.",
        "Hearing the difference is more useful than memorizing it. Major tends to sound sunny, minor tends to sound serious."
    ])
```

- L4 "Same shape, new key":
```swift
detail: LessonDetail(
    heading: "Movable shapes",
    paragraphs: [
        "Guitar and bass scale shapes have no open strings to tie them down, so the whole pattern slides up or down to change key. One shape covers every key.",
        "Learn where the root sits in the shape and you can drop that scale into any song by sliding to the right fret."
    ])
```

- L5 "Explore on your own":
```swift
detail: LessonDetail(
    heading: "Make it yours",
    paragraphs: [
        "Pick any key and scale and watch the neck redraw. Poking around like this is how the patterns stop being shapes and start being sounds you know.",
        "The Scale Explorer is open ended on purpose. Try a key, hum along, and notice which notes pull at your ear."
    ])
```

- [ ] **Step 2: Improvisation details**

In `improvisation`, set `detail:` on each lesson:

- L1 "Safe notes":
```swift
detail: LessonDetail(
    heading: "A net under your solo",
    paragraphs: [
        "Every lit note fits the backing track, so you cannot land on a wrong one. That is the point of starting with a scale: it frees you to listen instead of worry.",
        "Soloing is not about playing many notes. It is about choosing a few good ones, and the safe-notes net is what lets you choose freely."
    ])
```

- L2 "Hear the backing":
```swift
detail: LessonDetail(
    heading: "Listening to the loop",
    paragraphs: [
        "Four chords cycle under you, and the one playing now lights up with its root pulsing on the neck. Knowing where you are in the loop is half of soloing.",
        "Before you play a note, just listen for a pass or two. Feel where the loop turns around; that is where your phrases will want to breathe."
    ])
```

- L3 "Target the root":
```swift
detail: LessonDetail(
    heading: "Landing in the right place",
    paragraphs: [
        "When you end a phrase on the current chord's root, it sounds resolved no matter what came before. Chasing that pulsing root is the fastest way to sound intentional.",
        "You do not have to play only roots. Aim for them as landing spots and wander in between."
    ])
```

- L4 "Short phrases":
```swift
detail: LessonDetail(
    heading: "Space is part of the music",
    paragraphs: [
        "Three or four notes followed by a rest say more than a constant stream. The silence gives your phrases shape and gives the listener time to catch them.",
        "Think of it like talking: short sentences with pauses, not one breathless run."
    ])
```

- L5 "Take a solo":
```swift
detail: LessonDetail(
    heading: "Putting it together",
    paragraphs: [
        "Press play and improvise over the full loop using only safe notes. Target roots, leave space, and repeat ideas so the solo feels like it is going somewhere.",
        "When you want more room, Solo Practice lets you change key and scale and keep going for as long as you like."
    ])
```

- [ ] **Step 3: Build, run, commit**

```bash
git add App/StringTheory/AppModel.swift
git commit -m "content: deep-dives for Scales and Improvisation"
```

---

# Phase H — Final verification and docs

## Task H1: Full test pass and a manual run-through

- [ ] **Step 1: Core tests**

Run: `swift test --package-path StringTheoryCore`
Expected: PASS, including the new `PitchDetectorTests` and the chord-frequency test.

- [ ] **Step 2: App tests**

Run: `xcodebuild test -project StringTheory.xcodeproj -scheme StringTheory -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: PASS, including the existing onboarding UI smoke test and `AppModelTests`.

- [ ] **Step 3: Manual run-through on the simulator**

Verify each ask end to end:
- Revisit: finish a stage, reopen it from the path, step back and forward, jump with the dots.
- Depth: open Learn more on several lessons across stages; confirm it scrolls and collapses.
- Chord playback: strum in a guitar Chords lesson and in the Chord Library; arpeggiate in a bass Chords lesson.
- Technique: Stage 1 leads with the holding and fretting diagrams; the holding diagram changes for bass.
- Tuner: open from the Path header and from Settings; grant the mic, watch the needle, tap reference tones; leave and confirm playback still works; deny the mic and confirm the reference-only fallback.

- [ ] **Step 4: Update CLAUDE.md**

In the architecture section of `CLAUDE.md`, document: the tuner (core `detectPitchHz`/`centsOff`/`nearestString`, the `TunerEngine` and `MicTunerEngine`, `AppModel.beginTuning`/`endTuning`, `AudioSessionController` as the one session owner), `AudioEngine.playChord` and `AppModel.playChord`/`arpeggiate`, the `.technique` lesson kind and the two diagrams, the `Lesson.detail`/`LessonDetail` deep-dive mechanism, the scrollable lesson layout with fixed-height fretboards, and that completed stages are now reviewable with back/stepper navigation. Keep the prose plain and free of em dashes.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document the tuner, chord playback, technique, depth, and revisiting"
```

---

## Self-review notes

- **Spec coverage:** revisit (D1, D2), depth mechanism (F1) and content (G1-G4), chord playback (A2, A3, C1, C2), technique (E1, E2), tuner (A1, B1-B6). All five asks map to tasks.
- **Type consistency:** `detectPitchHz`, `centsOff`, `nearestString`, `chordVoicingFrequencies`, `TunerReading`, `TunerEngine.start/stop/onReading`, `AudioEngine.playChord(frequencies:strumGap:)`, `AppModel.beginTuning/endTuning/playReferenceTone/playChord/arpeggiate`, `LessonDetail(heading:paragraphs:bullets:)`, `Lesson.detail`, `TechniqueLesson.holding/.fretting`, `LessonKind.technique` are used consistently across tasks.
- **Known accepted effect:** reordering Stage 1 shifts the `"1.x"` completion keys; pre-release, no migration (per the spec's out-of-scope).
- **Audio risk:** the session is owned only by `AppModel` via `AudioSessionController`, and `SynthAudioEngine` refuses to downgrade a live record session; verify by ear that reference tones and playback coexist while tuning (B6 step 3).
