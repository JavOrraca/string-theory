# String Theory

An iOS app that teaches guitar and bass, from naming open strings to improvising in key. It is free: no in-app purchases, no ads, no analytics.

This is a native SwiftUI port of an HTML/JS prototype. The prototype still lives in `prototype/` and is the reference for design and behavior.

## Layout

- `StringTheoryCore/` is a Swift package with the music-theory engine and the fretboard geometry. No UIKit or SwiftUI, so it runs under `swift test` on its own.
- `App/StringTheory/` is the iOS app: SwiftUI views, an `@Observable` state model, the design system, and the audio engine.
- `project.yml` is the XcodeGen spec. The `.xcodeproj` is generated from it and is not committed.
- `prototype/` holds the original HTML/JS files used as the spec.
- `docs/` has the architecture notes and the App Store checklist.

## Requirements

- Xcode 26 or newer (Swift 6, iOS 17 deployment target).
- XcodeGen: `brew install xcodegen`.

## Run

```sh
xcodegen generate
open StringTheory.xcodeproj
```

Pick the StringTheory scheme and an iPhone simulator, then run.

## Test

Core package, fast and no simulator:

```sh
swift test --package-path StringTheoryCore
```

App, including the onboarding UI smoke test:

```sh
xcodebuild test \
  -project StringTheory.xcodeproj \
  -scheme StringTheory \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

CI runs both on every pull request. See `.github/workflows/ci.yml`.

## Architecture

The full version is in `docs/Architecture.md`. The short version: the core package holds everything testable and platform free (notes, tunings, scales, chords, the riff, backing progressions, and the fretboard layout math). The app depends on the core and adds the SwiftUI screens, the shared state model, and an `AVAudioEngine` synth. One fretboard view renders every diagram from the core geometry.

## Screens

Onboarding (instrument and handedness), Home (the five-stage Signal Path), Lesson (fretboard locked to a tab staff), Chord Library, Scale Explorer, and Solo Practice. A Settings sheet changes instrument and handedness after onboarding.

## Shipping

The app collects no data. The privacy manifest is at `App/StringTheory/Resources/PrivacyInfo.xcprivacy`, and the release checklist is in `docs/AppStoreReadiness.md`. The app icon is a generated placeholder; you can regenerate it with `swift tools/make-app-icon.swift <path>`.
