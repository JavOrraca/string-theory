# Lessons depth, revisiting, chord playback, technique, and a tuner

Date: 2026-06-18
Status: approved design, pending implementation plan

## Goal

Five changes to String Theory, all driven from one user request:

1. Let learners revisit completed lessons (today they cannot go back).
2. Give the lessons more depth (the content feels topical).
3. Let learners hear a whole chord, not only single tapped notes.
4. Teach absolute beginners how to hold the instrument and how to fret a note
   with the fingertip, in the Fretboard Basics stage only.
5. Add a built-in tuner for guitar and bass, reached from the Setup sheet.

The app stays free, collects no data, keeps dependencies near zero, and prefers
Apple frameworks. New pure logic goes in `StringTheoryCore`; the app layer keeps
its single state object (`AppModel`), its one fretboard renderer, the OKLCH
palette, and the protocol-backed audio engine.

## Decisions already made

- Tuner is live microphone detection plus reference tones (tap a string to hear
  its target pitch).
- Depth is delivered as an expandable "Learn more" deep-dive per lesson plus a
  few richer multi-step lessons, not a wall of text.
- Technique guidance uses SwiftUI-drawn diagrams (no image assets).
- The tuner lives behind a row in the Setup sheet, with a shortcut button added
  to the Path header.

## Architecture decisions (internal, flagged in design review)

- **Pitch detection is normalized autocorrelation**, implemented as pure Swift in
  the core package so it is unit-testable. Autocorrelation is robust for a single
  low string; bass low E is about 41 Hz, so the analysis window must hold at least
  two periods (a 4096-sample window at 44.1 kHz is about 93 ms, enough down to
  roughly 21 Hz).
- **`AppModel` is the single owner of `AVAudioSession`.** It already owns the
  audio engine, so it also owns the tuner engine. The tuner needs the
  `.playAndRecord` category (so reference tones still play while the mic is live);
  `AppModel.beginTuning()` switches to it and `endTuning()` restores `.playback`.
  Two objects poking the session independently is the exact runtime crash this
  codebase already warns about, so there is one owner.
- **The lesson content area becomes scrollable.** An expanded deep-dive needs room,
  so the fretboard takes a sensible min-height instead of greedily filling, and the
  content scrolls. Collapsed, a lesson still looks like today's single screen.

## Components and changes

### Shared core (StringTheoryCore, pure, TDD first)

- `Music/PitchDetector.swift`
  - `func detectPitchHz(_ samples: [Float], sampleRate: Double) -> Double?`
    Normalized autocorrelation. Returns nil when the signal is too quiet or has no
    clear period.
  - `func centsOff(hz: Double, targetHz: Double) -> Double` (1200 * log2(hz/target)).
  - `func nearestString(toHz hz: Double, in tuning: Tuning) -> (index: Int, target: OpenString, cents: Double)`
    Picks the open string whose frequency is closest in cents.
- `Music/Chord.swift` (extend)
  - `func chordVoicingFrequencies(_ chord: Chord, tuning: Tuning = .guitar) -> [Double]`
    Sounding Hz for each non-muted string, low to high, for strum ordering.
    Reuses `chordMarkers` / `freqAt` so it stays consistent with the diagram.

Tests: feed synthesized sine samples at known pitches (including 41.2 Hz and
82.41 Hz) and assert detected Hz within a small tolerance; assert cents math and
nearest-string mapping; assert chord voicing frequencies for a known voicing.

### App audio (Audio/)

- `AudioEngine` protocol gains `func playChord(frequencies: [Double], strumGap: Double)`.
  - `NoopAudioEngine`: empty.
  - `SynthAudioEngine`: adds a pluck voice per frequency, staggered by `strumGap`
    (about 0.025 s) on a short main-actor Task so it sounds like a downstrum. The
    voices themselves are the existing `.pluck`.
- New `Audio/TunerEngine.swift`
  - `protocol TunerEngine: AnyObject` with `var onReading: (@MainActor (TunerReading) -> Void)?`,
    `func start()`, `func stop()`.
  - `TunerReading` value type: detected Hz, nearest string index, cents offset,
    and a confidence/voiced flag.
  - `NoopTunerEngine` for previews and tests.
  - `MicTunerEngine` taps `AVAudioEngine.inputNode`, accumulates samples into a
    ring buffer, runs the core `detectPitchHz` off the main actor, and publishes
    readings on the main actor. The tap closure is `nonisolated` and never reads
    main-actor state, matching the existing render-block rule.

### AppModel (single source of truth)

- Owns a `TunerEngine` alongside the audio engine.
- `beginTuning()` / `endTuning()` manage the `AVAudioSession` category and start
  or stop the tuner. Publishes the latest `TunerReading` for `TunerView`.
- `playChord(for chord: Chord)` and `strum`/`arpeggiate` helpers that compute
  frequencies (via the core) and call the engine. For bass arpeggio lessons,
  `arpeggiate(root:isMinor:)` sounds root, third, fifth in sequence.
- Tuner active state and the current reading live here so the one owner of the
  session is also the one publisher of tuner data. `TunerView` reads them.

### 1. Revisit completed lessons

- `HomeView`: `.done` stage cards become `NavigationLink`s into `StageLessonsView`
  (same destination the active stage uses). `.locked` stays a plain, dimmed card.
  Accessibility label for a done card gains "Tap to review."
- `StageLessonsView`:
  - The `LESSON x / n` indicator becomes a tappable dot stepper; tapping a dot
    jumps to that lesson. A Back chevron steps to the previous lesson.
  - Free movement among lessons the learner has reached. Forward past the last
    lesson still finishes and dismisses.
  - On appear for a fully completed stage, start at lesson 1 (review from the top)
    rather than the first-unfinished jump used for in-progress stages.
  - Revisiting never clears completion.

### 2. Lesson depth

- `Lesson` gains `var detail: LessonDetail? = nil`.
  - `LessonDetail`: a heading plus a body. The body is a small structured type so
    it can render short paragraphs and optional bullet sections in the app's
    typography, not a single blob.
- `StageLessonsView` renders the deep-dive as a collapsed disclosure ("Learn more")
  under the interactive area. The content area is wrapped so expansion scrolls.
- Author deep-dive content for every lesson across all five stages, plus a small
  number of targeted new multi-step lessons where they add the most. Content is
  plain data, so this authoring is delegated to a cheaper model during execution,
  then reviewed.

### 3. Play the chords

- Guitar Chords lessons (`ChordsLessonView`) and the Chord Library diagram card get
  a "Play chord" button that strums the shown voicing via `AppModel.playChord`.
- Bass arpeggio lessons (`ArpeggioLessonView`) get a "Play" that arpeggiates
  root, third, fifth.
- Tap-to-hear single notes is unchanged.

### 4. Technique lessons (Fretboard Basics only)

- `LessonKind` gains `case technique(TechniqueLesson)` with `.holding` and
  `.fretting`.
- A new private view renders each with a SwiftUI `Canvas`/`Path` diagram in the
  phosphor/cyan theme. `.holding` adapts slightly for guitar versus bass (neck
  angle and body size). `.fretting` shows the fingertip pressing just behind the
  fret, knuckle bent, with guidance to press only until the note rings clean and
  not to squeeze.
- These become lessons 1 and 2 of Stage 1, ahead of Open strings, Fret numbers,
  Find a note. Footer is the forward button only (like `.reading`). They can carry
  a deep-dive detail too.
- Pre-release, so no UserDefaults migration for the renumbered Stage 1 lesson keys.
  Noted as a known, accepted effect.

### 5. Built-in tuner

- `Features/Tuner/TunerView.swift`
  - A flat-to-sharp needle for the detected pitch, the detected note name and cents
    offset, and a strip of the instrument's open strings (E A D G B E for guitar,
    E A D G for bass). Tapping a string plays its reference tone; the string the
    learner is closest to is highlighted live.
  - Requests mic permission on first appearance. If denied, it degrades to
    reference-tones-only and shows a prompt to enable the mic in iOS Settings.
  - `onAppear` calls `model.beginTuning()`, `onDisappear` calls `model.endTuning()`.
- `SettingsView`: a new "TOOLS" group with a "Tuner" row that pushes `TunerView`.
- `HomeView` header: a tuning-fork button next to the existing Setup gear that opens
  the tuner.
- `Info.plist`: add `NSMicrophoneUsageDescription` ("String Theory uses the
  microphone only to detect the pitch of your strings for tuning. Audio is never
  recorded, stored, or sent.").
- `PrivacyInfo.xcprivacy` stays no-collection (on-device processing, nothing stored
  or sent). Update `docs/AppStoreReadiness.md` with the tuner, the mic usage string,
  and the App Store privacy answer.

## Data flow

- Tuner: mic input -> `MicTunerEngine` tap (nonisolated) -> ring buffer ->
  `detectPitchHz` (off main) -> `nearestString` -> `TunerReading` published on main
  -> `AppModel` -> `TunerView` needle and highlight. Reference tone: tap a string ->
  `AppModel.playNote` -> existing synth.
- Chord playback: button -> `AppModel.playChord(for:)` -> core
  `chordVoicingFrequencies` -> `AudioEngine.playChord` -> staggered pluck voices.
- Revisit: `HomeView` link -> `StageLessonsView(stage:)` -> stepper/back drive the
  lesson index; completion comes from the existing `AppModel.isLessonComplete`.
- Depth: `Lesson.detail` data -> disclosure view; no model or audio involvement.

## Error handling

- Pitch detector returns nil for quiet or aperiodic input; the needle shows an
  idle state, not a jittering false reading.
- Mic permission denied: tuner stays usable as reference tones only, with a clear
  prompt; no crash, no silent failure.
- `AVAudioSession` category changes are wrapped and logged like the existing
  `startIfNeeded`; a failure leaves playback working and surfaces in the log.
- `endTuning()` always restores `.playback` and stops the tap, including on view
  disappearance, so leaving the tuner never leaves the mic running.

## Testing

- Core, TDD first: pitch detection on synthesized sines (guitar and bass open
  strings, plus a few cents off), cents math, nearest-string mapping, chord voicing
  frequencies. These run under `swift test` in milliseconds.
- App: a smoke test that opens the tuner and the revisit flow; the existing
  onboarding UI test stays green. Run on the simulator, not only build, because the
  audio-session and mic paths only fail at runtime.

## Build order

1. Core DSP and the audio protocol change (pitch detector, chord voicing
   frequencies, `playChord`). TDD.
2. Tuner engine, `AppModel` session ownership, `TunerView`, Setup row, Path button,
   Info.plist, privacy doc.
3. Chord playback buttons.
4. Revisit navigation.
5. Technique lessons (new kind plus the two diagrams) at the front of Stage 1.
6. Deep-dive content for every lesson plus the targeted new multi-step lessons,
   authored with a cheaper model and reviewed.

## Out of scope

- No polyphonic chord detection in the tuner (single-string monophonic only).
- No alternate tunings or a chromatic free mode beyond standard guitar and bass.
- No UserDefaults migration for renumbered Stage 1 lesson keys (pre-release).
- No image or audio sample assets; synthesis and vector drawing only.
