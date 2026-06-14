# Screen-build brief (for swarm workers)

You are implementing ONE SwiftUI screen for **String Theory**, a native port of an
HTML prototype. The prototype is the design + behavior spec.

## Hard rules
- Write **only the file(s) you are assigned**. Do not touch any other file.
- **Do NOT** run `xcodebuild`, `swift`, `xcodegen`, or `git`. Do not build. The
  coordinator integrates + builds. (You have no project file anyway.)
- Match the existing screen files' structure and the design-system API below.
- Swift 6 language mode, iOS 17. SwiftUI `View`s are implicitly `@MainActor`.
- Minimum 44pt hit targets; add `.accessibilityLabel`/identifiers on key controls.
- When done, return a short summary + any assumptions or deviations from the prototype.

## Read these first (sources of truth)
- Your screen's markup in `prototype/String Theory.dc.html` (line ranges in your task).
- The shared logic/styles in that same file, **lines 563–1043** (`renderVals`,
  the `_keyChip`/`_typeChip`/`_chordChip`/`_progChip`/`_selCard` style helpers,
  `stageDefs`, `tabRows`, scale/solo/chord data).
- `prototype/music.js` for any behavior; `App/StringTheory/DesignSystem/*.swift`,
  `App/StringTheory/Components/FretboardView.swift`, `App/StringTheory/AppModel.swift`,
  and your current `App/StringTheory/Features/.../<Your>View.swift`.

## Design system API (`App/StringTheory/DesignSystem/`)
- `Theme.Palette`: `.void .panel .panelDeep .phosphor .signalCyan .warning .text .textDim .hairline` (all `Color`).
- `Color(oklchL: Double, c: Double, h: Double, opacity: Double = 1)` — build any prototype OKLCH color.
- `Typography.display(_ size:CGFloat, weight:.bold) / .body(_:weight:.regular) / .mono(_:weight:.medium) -> Font`.
- Modifiers: `.glow(_ color:Color, radius:CGFloat=12)`, `.panel(cornerRadius:CGFloat=16)`, `.sectionLabel()` (mono, uppercased, tracked).
- `AppBackground()` — void + top glow + scanlines. `PrimaryButtonStyle()` — solid phosphor button.

## FretboardView (`Components/FretboardView.swift`)
```swift
FretboardView(
    geometry: FretboardGeometry(stringCount: Int, fretCount: Int, startFret: Int = 0, isLeftHanded: Bool),
    openNotes: [Note],
    markers: [Marker],
    showStringLabels: Bool = true, showFretNumbers: Bool = true, showInlays: Bool = true
).frame(height: 180...210)
```

## Core API (`import StringTheoryCore`)
- `Note` enum: `.c ... .b`, `.name` ("C", "F#"), `Note(name:)`, `Note.allCases` (12, chromatic = the KEYS list).
- `ScaleType`: `.major .majorPentatonic .minorPentatonic .naturalMinor`; `.label`, `.intervals`, `.isMinor`, `.allCases`.
- `Instrument`: `.guitar .bass`, `.stringCount`. `Tuning.guitar/.bass/.standard(for:)`, `.strings` → `[OpenString(note:Note, frequency:Double)]`.
- `Chord`: `Chord.library` (10), `Chord.named("Am")`, `.id .name .quality(.major/.minor) .frets .family(.open/.barre)`.
- `chordMarkers(_ chord:) -> [Marker]`; `chordSpan(_:) -> FretSpan(min,max)`.
- `scaleMap(key:Note, scale:ScaleType) -> [Note: ScaleDegree]` (`.interval`, `.label` like "1","♭3").
- `scaleMarkers(instrument:key:scale:frets:Int=12, startFret:Int=0) -> [Marker]`.
- `backingProgression(key:Note, scale:ScaleType) -> [ProgressionChord]` (`.root`, `.isMinor`, `.name` "Am"/"F").
- `Riff.drift`: `.name`, `.key`, `.scale`, `.steps` → `[RiffStep(string:Int, fret:Int)]`.
- `Marker(string:Int, fret:Int, kind:MarkerKind, note:Note?=nil, label:String?=nil)`; `MarkerKind`: `.root .safe .active .open .muted .ghost`.

## AppModel (shared state — `@Environment(AppModel.self) private var model`)
Mutable: `instrument`, `isLeftHanded`, `hasOnboarded`, `scaleKey:Note`, `scaleType:ScaleType`,
`chordID:String`, `soloKey:Note`, `soloScale:ScaleType`. Derived: `tuning`, `openNotes:[Note]`,
`stringCount`, `selectedChord:Chord`. Assign directly in button actions, e.g. `model.scaleKey = note`.

## Audio is stubbed in Phase 4
Lesson/Solo transports: use a **local** `@State private var isPlaying = false`; the play/stop
button toggles it and updates its label/style. Add `// TODO: wire AudioEngine in Phase 5`.
Do NOT add timers, audio, or real step/chord animation — that's Phase 5.

## Palette / marker reference (from prototype)
Phosphor green = safe/active/key UI; Signal cyan = root note only; Warning red = muted/avoid.
Void `oklch(.12 .012 250)` bg, Panel `.19`, hairline borders `oklch(.5 .03 160 / .18)`.
