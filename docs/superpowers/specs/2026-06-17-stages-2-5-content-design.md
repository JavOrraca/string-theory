# Stages 2-5 lesson content design

Date: 2026-06-17
Status: approved (design), pending implementation plan

## Problem

The learning path in `LearningPath.stages` (in `AppModel.swift`) has five stages.
Stage 1, Fretboard Basics, is real content: three guided tap-to-hear explore
lessons. Stages 2-5 (Tabs, Chords, Scales & Keys, Improvisation) are each a
single stub that reuses one shared interactive riff lesson. This spec defines the
real per-stage content for stages 2-5 and the supporting machinery to render it.

The prototype frames a five-stage journey ("learn the fretboard, read tab, build
chords, then play a solo that always fits the key") but only mocks one
representative screen per stage. The per-stage lessons are not specified anywhere,
so they are designed here.

## Decisions

Settled with the user during brainstorming:

1. **Lesson model: guided lessons that hand off to a tool.** Each stage is a set
   of short guided lessons in the stage-1 style (tap-to-hear, fits one screen
   without scrolling). The last lesson of stages 3-5 points the learner at the
   matching tab (Chord Library, Scale Explorer, Solo Practice) for open practice.
   The tabs stay as the free-play sandbox; lessons do not duplicate them.
2. **Depth: 4-5 lessons per stage.** A fuller curriculum, roughly 20 lessons
   across the four stages on the guitar path, on top of stage 1's existing three.
3. **Bass: dedicated variants where it matters.** Stage 2 (Tabs) and stage 3
   (Chords) get bass-specific content: bass riffs for Tabs, and a root-and-arpeggio
   track for Chords instead of guitar chord shapes. Stage 4 (Scales) and stage 5
   (Improvisation) stay instrument-aware, which they already are by virtue of the
   shared fretboard geometry. The Chord Library stays guitar voicings only, which
   is a locked project decision.

## Approach

Keep the path data-driven. `LearningPath.stages` stays the single content source
and `LessonKind` grows a few interactive cases, each with a focused renderer that
reuses the one `FretboardView` plus tap-to-hear and the existing transport. This
follows the codebase's existing principles: one fretboard renderer, geometry in
the core, the path as data.

The rejected alternative was a fully bespoke view per lesson. It gives more control
but produces a lot of near-duplicate neck-plus-text code that is harder to keep
consistent.

### New lesson kinds

`LessonKind` today is `.fretboardRiff`, `.explore(ExploreLesson)`, `.reading(String)`.
It grows to add:

- `.tab(Riff)` - a fretboard locked to a tab staff for a specific riff. This
  generalizes today's `.fretboardRiff`, which is hardcoded to one riff. The old
  case is replaced by `.tab(.drift)`.
- `.chords([String])` - one or more chord diagrams on the neck, note-labelled,
  tap-to-hear, with a control to step between them (guitar stage 3).
- `.arpeggio(root:isMinor:)` - chord tones (root, third, fifth) one at a time on
  the neck (bass stage 3).
- `.scale(key:type:)` - scale degrees on the neck, root highlighted, tap to hear
  it ascend (stage 4).
- `.backing(key:type:)` - the Play-backing loop with the key's safe notes glowing
  and chord roots pulsing (stage 5).

`.explore` and `.reading` are unchanged.

## Per-stage curriculum

Lesson kind shown in backticks. Every interactive lesson is tap-to-hear.

### Stage 2 - Tabs

Culminates in the riff player. There is no Tabs tab, so the stage is
self-contained and ends on the full riff.

| # | Guitar | Bass | Kind |
|---|--------|------|------|
| 1 | Reading a tab number (lines are strings, numbers are frets) | same, on 4 strings | `.tab` (1-2 notes) |
| 2 | One string, climbing (0-2-3-5 on the low string) | climbing on the bass low string | `.tab` |
| 3 | Crossing strings (low two strings) | across the low three strings | `.tab` |
| 4 | Timing and repeats | locking with the beat (groove) | `.tab` |
| 5 | Play "Drift" (full riff, transport, completes on the repetition goal) | play the full bassline | `.tab` |

### Stage 3 - Chords

Guitar hands off to the Chords tab. Bass has no guitar Chord Library to hand off
to, so the bass track ends on the walking-bass lesson.

| # | Guitar | Bass | Kind |
|---|--------|------|------|
| 1 | How to read a diagram: rings = open, x = mute, labelled notes (E) | On bass you play the root (root of C) | `.chords` / `.arpeggio` |
| 2 | E & Em (the one-finger difference) | Find the root of each chord across the neck | `.chords(["E","Em"])` / `.arpeggio` |
| 3 | A & Am | Root-fifth, the classic bass move | `.chords` / `.arpeggio` |
| 4 | D & Dm | Full arpeggio root-3-5, the third sets major vs minor | `.chords` / `.arpeggio` |
| 5 | G & C, then Open the Chord Library | Walk a I-IV-V with roots | `.chords` + handoff / `.arpeggio` |

F and Bm are not taught as lessons; they live in the Chord Library tab for free
exploration.

### Stage 4 - Scales & Keys

Instrument-aware. Hands off to the Scales tab.

| # | Lesson | Kind |
|---|--------|------|
| 1 | What a scale is (E minor pentatonic, root cyan, degrees) | `.scale(.e, .minorPentatonic)` |
| 2 | The root and the degree numbers | `.scale` |
| 3 | Minor vs major pentatonic in the same key | `.scale(.e, .majorPentatonic)` |
| 4 | Same shape, new key (move the pattern to A) | `.scale(.a, .minorPentatonic)` |
| 5 | Open the Scale Explorer | `.scale` + handoff |

### Stage 5 - Improvisation

Instrument-aware. Hands off to the Solo tab.

| # | Lesson | Kind |
|---|--------|------|
| 1 | Safe notes: any lit note fits the key (static, same markers as the Solo screen) | `.scale(.a, .minorPentatonic)` |
| 2 | Hear the backing (Play backing, chord roots pulse) | `.backing(.a, .minorPentatonic)` |
| 3 | Target the root as chords change (tap safe notes over the loop) | `.backing` |
| 4 | Short phrases, call and response | `.backing` |
| 5 | Take a solo, then Open Solo Practice | `.backing` + handoff |

## Supporting machinery

### Core content (StringTheoryCore)

The package globs its sources, so new files there need no Xcode project changes.

- **Riffs** in `Riff.swift`: keep `drift`; add about three short guitar teaching
  riffs (single-string climb, cross-string) and about four bass riffs (intro,
  climb, cross-string, groove). Each is a `RiffStep` array. A test asserts every
  step's string and fret are valid for the riff's tuning.
- **Arpeggio helper**: the root/third/fifth math is currently inline in
  `SynthAudioEngine.playBacking`. Factor it into a core `chordTones(root:isMinor:)
  -> [Note]` and test it (`chordTones(.c, false) == [.c, .e, .g]`,
  `chordTones(.a, true) == [.a, .c, .e]`). The bass `.arpeggio` lessons and the
  backing voices both use it.
- Scales and progressions already exist; nothing added.

### Lesson renderers (App, existing files only)

New app types go in existing files so `StringTheory.xcodeproj` is untouched
(adding a new app source file requires editing the committed pbxproj).

- Renderers in `LessonView.swift`: generalize today's `RiffLesson` into
  `TabLessonView(riff:)`, and add `ChordsLessonView`, `ArpeggioLessonView`,
  `ScaleLessonView`, `BackingLessonView`. Each reuses the single `FretboardView`.
- **Marker reuse, no second renderer**: scale and solo markers are already core
  functions (`scaleMarkers(...)`). Factor the chord-diagram marker math out of
  `ChordLibraryView` into a core `chordMarkers(...)` so the lessons and the tab
  share one source of truth.
- **Playback**: `AppModel.toggleRiff` is hardcoded to `.drift`. Parameterize it so
  a `.tab` lesson plays its own riff. `.backing` lessons drive the existing backing
  engine for the lesson's key and scale.

### Tool handoff

Add a `selectedTab` to `AppModel`, bound to `MainTabView`'s selection. A handoff
lesson's footer gets an "Open the Chord Library / Scale Explorer / Solo" button
that sets the matching selection (for example the key just learned) and switches
tabs. Self-contained and small.

### Completion

The Next/Finish forward button from the stage-1 work already covers every kind.
Transport lessons (`.tab`, `.backing`) keep Play/Stop alongside it. The "play the
full riff" lessons keep the existing auto-complete-after-repetitions behavior.

## Testing

- Core, TDD: `chordTones`, `chordMarkers`, and a riff-validity test (every step in
  range for its tuning).
- `AppModelTests`: `selectedTab` default, and stage unlock across multi-lesson
  stages (a stage is done only when all its lessons are complete; the next stage
  then activates).
- UI flow test: walk one or two representative new stages end to end (for example
  the Scales stage: open it, step through the lessons, finish, land back on the
  path). Not all twenty lessons, to keep the test non-brittle.
- Build and run on the simulator and exercise the change, per the project rule that
  runtime issues (the audio-thread trap) do not show up at build time.

## Delivery

One spec, built and shipped stage by stage, each its own build/test/commit, in this
order:

1. **Tabs** - lands the shared machinery (new `LessonKind` cases, the `TabLessonView`
   generalization, parameterized riff playback) plus the guitar and bass riffs.
2. **Scales & Keys** - mostly the instrument-aware fretboard with curated scale
   markers, proves the engine quickly.
3. **Improvisation** - the backing engine with safe-note markers and the Solo
   handoff.
4. **Chords** - last, because it carries the most new machinery: guitar diagrams,
   the `chordMarkers` factor-out, the Chord Library handoff, and the separate bass
   arpeggio track.

The `selectedTab` handoff infrastructure lands with the first stage that needs it
(Scales).

## Out of scope

- A dedicated Tabs or Bass-Chords tool tab. Stage 2 ends on the riff player; the
  bass Chords track ends on the walking-bass lesson.
- Teaching F and Bm as lessons. They stay in the Chord Library for exploration.
- New scale types or progressions. The existing four scales and the generated
  backing progression are enough.
- A separate full bass curriculum beyond the stage 2 and 3 variants.
