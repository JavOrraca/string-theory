# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

String Theory is a native SwiftUI iOS app that teaches guitar and bass. It is a port of the HTML/JS prototype in `prototype/`, which stays in the repo as the reference for design and behavior. The app is free: no in-app purchases, ads, or third-party analytics. Keep dependencies near zero and prefer Apple frameworks.

## The Xcode project

`StringTheory.xcodeproj` is committed and opened directly in Xcode. Add files, change build settings, and manage signing in Xcode. `App/StringTheory/Info.plist` is committed too; it holds the launch screen, the portrait orientation, and the `UIAppFonts` registration.

`project.yml` is kept only as a record of the original XcodeGen setup. Do not run `xcodegen generate` against this repo: it overwrites the committed project and wipes the signing and anything else set in Xcode. If you regenerate on purpose, re-commit the result.

## Commands

Core package, pure logic, no simulator, runs in milliseconds:

    swift test --package-path StringTheoryCore
    swift test --package-path StringTheoryCore --filter ScaleTests    # one suite

App build plus tests (this also runs the onboarding UI smoke test):

    xcodebuild test -project StringTheory.xcodeproj -scheme StringTheory \
      -destination 'platform=iOS Simulator,name=iPhone 16'
    # one test: add -only-testing:StringTheoryTests/AppModelTests

Prefer the xclaude Xcode MCP tools (`xcode_build`, `xcode_test`, `simulator_*` under the `xc-all` server) over raw `xcodebuild` when they are available. Fall back to raw `xcodebuild` only if they are not.

Regenerate the placeholder app icon:

    swift tools/make-app-icon.swift \
      App/StringTheory/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png

## Architecture

Two layers, split deliberately.

- `StringTheoryCore/` is a Swift package with no UIKit or SwiftUI import. It holds the music engine (`Note`, `Tuning`, `Scale`, `Chord`, `Riff`, `Progression`, `Marker`) and the fretboard geometry (`FretboardGeometry`). With no UI dependency it tests under `swift test` on the Mac host. This is where the `prototype/music.js` and `prototype/Fretboard.dc.html` logic was ported. Put new pure logic here, not in the app.
- `App/StringTheory/` is the iOS app (iOS 17, Swift 6). It depends on the core package and adds the SwiftUI views, one state model, the design system, and the audio engine.

Key seams to understand before changing things:

- **Single source of truth.** `AppModel` is one `@MainActor @Observable` object holding instrument, handedness, the selected key/scale/chord, plus playback and learning-path state. Changing instrument or handedness re-renders every diagram, the same way the prototype works. `AppModel` owns the audio engine. Onboarding completion, instrument, handedness, and completed lessons persist in `UserDefaults`; mutate them through `AppModel`'s `setInstrument` / `setLeftHanded` / `completeOnboarding` / `markLessonComplete` methods, which also write to storage. Scale, Chord, and Solo selections are session-only.
- **One fretboard renderer.** `Components/FretboardView.swift` is the only neck view. It draws with a SwiftUI `Canvas` and positions every marker from `FretboardGeometry`, so string count (4 or 6), handedness mirroring, and the fret window are all decided by pure core math. Every diagram screen reuses it. Do not add a second fretboard renderer; extend this view and the geometry.
- **Geometry is in percentages.** `FretboardGeometry` returns points in 0 to 100 percent of the board as a plain `GridPoint`, not `CGPoint`, which keeps the core platform free. The view multiplies by its pixel size.
- **Colors are OKLCH.** The palette is authored in OKLCH (the prototype's exact CSS values) and converted to sRGB at runtime in `DesignSystem/Theme.swift` through `Color(oklchL:c:h:)`. Add colors the same way rather than hardcoding sRGB.
- **Audio behind a protocol.** `Audio/AudioEngine.swift` is the protocol, with a `NoopAudioEngine` for previews and tests. `Audio/SynthAudioEngine.swift` is the real backend: an `AVAudioSourceNode` mixes pluck, pad, and kick voices, and two Task-based schedulers run the riff and the four-bar backing loop. They publish the current step and chord, which the Lesson and Solo screens read to highlight the neck and tab in time.
- **Learning path is data-driven.** `LearningPath.stages` (in `AppModel.swift`) is the content: each stage has an ordered list of `Lesson`s. `AppModel` persists completed lessons and derives each stage's done/active/locked status and the overall percent, so a new user starts at 0% with stage 1 active, and finishing a stage's lessons unlocks the next. `StageLessonsView` (in `LessonView.swift`) plays a stage's lessons, one screen each, with a Completed state and Next / Back to Main; a `fretboardRiff` lesson completes after `riffRepetitionGoal` passes. Lesson content is still mostly stubbed: each stage currently has one shared interactive fretboard/riff lesson, and `markLessonComplete(stageID:lessonID:)` is the hook real lessons call.

## Conventions and gotchas

- **TDD for the core.** The prototype is the oracle. Write a failing Swift Testing case with the expected value, watch it fail, then implement. The existing core tests double as the spec.
- **Swift 6 audio thread isolation.** A render block formed inside a `@MainActor` context is treated as main-actor isolated and traps when the audio thread invokes it (EXC_BREAKPOINT on `AURemoteIO::IOThread`). `SynthAudioEngine` builds its `AVAudioSourceNode` in a `nonisolated` static factory to avoid this. Keep any audio-thread closure nonisolated and never read `@MainActor` state from it.
- **Run it, do not just build it.** The audio crash above compiled cleanly and only appeared at runtime. Launch the app on the simulator and exercise the change.
- **Chord Library is always guitar voicings**, even when the selected instrument is bass. This matches the prototype. Keep it.
- **Fonts are bundled variable OFL fonts** (Space Grotesk, Hanken Grotesk, JetBrains Mono) in `App/StringTheory/Resources/Fonts/`, registered through `UIAppFonts` in the committed `App/StringTheory/Info.plist`. `Typography` applies weight through the font descriptor rather than `Font.weight` because the fonts are variable. Use `Typography.display`, `Typography.body`, and `Typography.mono`, not `.system`.
- **Do not port** `prototype/ios-frame.jsx` or `prototype/support.js`. They are prototype scaffolding only.

## Writing style for docs and prose

Write like a working engineer. Do not use the em dash. Cut AI-slop filler (seamless, robust, comprehensive, leverage, delve, and the like). Be plain and concrete.

## Shipping

The app collects no data. `App/StringTheory/Resources/PrivacyInfo.xcprivacy` declares no collection and no tracking; keep it in sync with the App Store privacy answers. The release checklist is in `docs/AppStoreReadiness.md`. The bundle id is `com.javierorraca.stringtheory`. Signing uses Xcode automatic signing, so set your team in the StringTheory target's Signing and Capabilities for device or TestFlight builds.
