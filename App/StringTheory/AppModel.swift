import AVFoundation
import Foundation
import Observation
import StringTheoryCore

/// The single shared state object. Holds instrument, handedness, the current
/// key/scale/chord, tempo, playback state, and the learning-path progress.
///
/// Onboarding, instrument, handedness, tempo, and completed lessons are persisted
/// in `UserDefaults`, so the app remembers them across launches. The Scale,
/// Chord, and Solo selections are session-only, like the prototype.
@MainActor
@Observable
final class AppModel {
    // Persisted. Mutated through the methods below so the writes also hit storage.
    private(set) var hasOnboarded: Bool
    private(set) var instrument: Instrument
    private(set) var isLeftHanded: Bool
    private(set) var tempo: Int                       // BPM for the riff and backing loop
    private(set) var completedLessons: Set<String>    // keys of finished lessons

    // Session-only exploration state.
    /// Which tab is showing. Session-only. A lesson handoff sets this to send the
    /// learner into the matching tool tab.
    var selectedTab: MainTab = .path
    var scaleKey: Note = .e
    var scaleType: ScaleType = .minorPentatonic
    var chordID: String = "C"
    var soloKey: Note = .a
    var soloScale: ScaleType = .minorPentatonic

    // Playback, driven by the audio engine.
    private(set) var isPlayingRiff = false
    private(set) var riffStep: Int?
    private(set) var riffRepetitions = 0
    private(set) var isPlayingBacking = false
    private(set) var backingChordIndex: Int?

    // Tuner. Session-only; owned here so the one session owner is the one
    // publisher of tuner data.
    private(set) var isTuning = false
    private(set) var tunerReading: TunerReading = .idle
    /// nil until the mic has been asked for; then true (granted) or false (denied).
    private(set) var micGranted: Bool?

    /// How many full passes of the riff count as "practiced enough" for a lesson.
    let riffRepetitionGoal = 2
    var riffGoalReached: Bool { riffRepetitions >= riffRepetitionGoal }

    /// Allowed tempo range in BPM. 110 is the prototype's default.
    let tempoRange = 60...160
    static let defaultTempo = 110

    @ObservationIgnored private let audio: AudioEngine = SynthAudioEngine()
    @ObservationIgnored private let tuner: TunerEngine
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasOnboarded = defaults.bool(forKey: Keys.hasOnboarded)
        instrument = defaults.string(forKey: Keys.instrument).flatMap(Instrument.init(rawValue:)) ?? .guitar
        isLeftHanded = defaults.bool(forKey: Keys.isLeftHanded)
        tempo = (defaults.object(forKey: Keys.tempo) as? Int) ?? Self.defaultTempo
        completedLessons = Set(defaults.stringArray(forKey: Keys.completedLessons) ?? [])
        tuner = MicTunerEngine()

        audio.onRiffStep = { [weak self] step in
            guard let self else { return }
            if let previous = self.riffStep, step < previous { self.riffRepetitions += 1 }
            self.riffStep = step
        }
        audio.onBackingChord = { [weak self] index in self?.backingChordIndex = index }
        tuner.onReading = { [weak self] reading in self?.tunerReading = reading }
    }

    // MARK: Setup (persisted)

    func setInstrument(_ value: Instrument) {
        instrument = value
        defaults.set(value.rawValue, forKey: Keys.instrument)
    }

    func setLeftHanded(_ value: Bool) {
        isLeftHanded = value
        defaults.set(value, forKey: Keys.isLeftHanded)
    }

    func completeOnboarding() {
        hasOnboarded = true
        defaults.set(true, forKey: Keys.hasOnboarded)
    }

    /// Sets the tempo (clamped to `tempoRange`). Takes effect the next time the
    /// riff or backing loop is started.
    func setTempo(_ bpm: Int) {
        let clamped = min(max(bpm, tempoRange.lowerBound), tempoRange.upperBound)
        guard clamped != tempo else { return }
        tempo = clamped
        defaults.set(clamped, forKey: Keys.tempo)
    }

    // MARK: Derived state

    var tuning: Tuning { .standard(for: instrument) }

    /// The learning path for the current instrument.
    var stages: [LearningStage] { LearningPath.stages(for: instrument) }

    var openNotes: [Note] { tuning.strings.map(\.note) }
    var stringCount: Int { tuning.stringCount }
    var selectedChord: Chord { Chord.named(chordID) ?? Chord.library[0] }

    /// Riff step / backing bar durations, scaled from the default 110 BPM.
    private var riffStepDuration: Double { 0.30 * Double(Self.defaultTempo) / Double(tempo) }
    private var backingBarDuration: Double { 1.7 * Double(Self.defaultTempo) / Double(tempo) }

    /// Root note of the chord currently sounding in the backing loop, if any.
    var activeBackingRoot: Note? {
        guard let index = backingChordIndex else { return nil }
        let progression = backingProgression(key: soloKey, scale: soloScale)
        guard progression.indices.contains(index) else { return nil }
        return progression[index].root
    }

    /// Plays the note at (string, fret) on the current instrument's tuning (tap-to-hear).
    func playNote(string: Int, fret: Int) {
        guard tuning.strings.indices.contains(string) else { return }
        audio.playNote(frequency: freqAt(base: tuning.strings[string].frequency, fret: fret))
    }

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

    // MARK: Learning path (persisted progress)

    func isLessonComplete(stageID: Int, lessonID: Int) -> Bool {
        completedLessons.contains(Self.lessonKey(stageID, lessonID))
    }

    func markLessonComplete(stageID: Int, lessonID: Int) {
        if completedLessons.insert(Self.lessonKey(stageID, lessonID)).inserted {
            defaults.set(Array(completedLessons), forKey: Keys.completedLessons)
        }
    }

    /// Completion fraction (0...1) for a stage: finished lessons over total.
    func progress(for stage: LearningStage) -> Double {
        guard !stage.lessons.isEmpty else { return 0 }
        let done = stage.lessons.reduce(0) { $0 + (isLessonComplete(stageID: stage.id, lessonID: $1.id) ? 1 : 0) }
        return Double(done) / Double(stage.lessons.count)
    }

    /// `done` once a stage is finished, `active` for the first unfinished stage,
    /// `locked` for everything after it.
    func status(for stage: LearningStage) -> StageStatus {
        if progress(for: stage) >= 1 { return .done }
        let current = stages.first { progress(for: $0) < 1 }
        return stage.id == current?.id ? .active : .locked
    }

    var overallPercent: Int {
        guard !stages.isEmpty else { return 0 }
        let total = stages.reduce(0.0) { $0 + progress(for: $1) }
        return Int((total / Double(stages.count) * 100).rounded())
    }

    // MARK: Lesson transport

    func toggleRiff(_ riff: Riff = .drift) {
        if isPlayingRiff {
            stopRiff()
        } else {
            stopBacking()
            riffRepetitions = 0
            audio.playRiff(riff, tuning: tuning, stepDuration: riffStepDuration)
            isPlayingRiff = true
        }
    }

    func stopRiff() {
        audio.stopRiff()
        isPlayingRiff = false
        riffStep = nil
    }

    // MARK: Solo transport

    func toggleBacking() {
        if isPlayingBacking {
            stopBacking()
        } else {
            stopRiff()
            audio.playBacking(key: soloKey, scale: soloScale, barDuration: backingBarDuration)
            isPlayingBacking = true
        }
    }

    /// Stops the backing loop. Public so a `.backing` lesson can stop it when the
    /// learner advances or leaves the stage, the way `stopRiff` works for tabs.
    func stopBacking() {
        audio.stopBacking()
        isPlayingBacking = false
        backingChordIndex = nil
    }

    /// Changing key or scale stops the backing loop (mirrors the prototype).
    func setSoloKey(_ note: Note) {
        stopBacking()
        soloKey = note
    }

    func setSoloScale(_ scale: ScaleType) {
        stopBacking()
        soloScale = scale
    }

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
        if granted { tuner.start(tuning: tuning) }
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

    // MARK: Persistence

    private enum Keys {
        static let hasOnboarded = "hasOnboarded"
        static let instrument = "instrument"
        static let isLeftHanded = "isLeftHanded"
        static let tempo = "tempo"
        static let completedLessons = "completedLessons"
    }

    private static func lessonKey(_ stageID: Int, _ lessonID: Int) -> String {
        "\(stageID).\(lessonID)"
    }
}

// MARK: - Learning path content

/// The four tabs in the main shell. Drives `TabView` selection so a lesson can
/// hand off to a tool tab.
enum MainTab: Hashable {
    case path, chords, scales, solo
}

enum StageStatus {
    case done, active, locked
}

/// What a lesson presents. `tab` plays any riff on the learner's own tuning;
/// `reading` is a short text lesson (used as real per-stage content lands);
/// `scale` shows a scale on the neck, tap-to-hear, with `showDegrees` choosing
/// whether each tone is labelled with its degree or left as a plain dot;
/// `backing` is the Solo screen's neck driven by the backing loop, tap-to-hear;
/// `chords` shows one or more guitar chord diagrams (stepped) tap-to-hear;
/// `arpeggio` shows a chord's root/third/fifth across the neck, tap-to-hear.
enum LessonKind: Hashable {
    case tab(Riff)
    case reading(String)
    case explore(ExploreLesson)
    case scale(key: Note, type: ScaleType, showDegrees: Bool)
    case backing(key: Note, type: ScaleType)
    case chords([String])
    case arpeggio(root: Note, isMinor: Bool)
    case technique(TechniqueLesson)
}

/// A guided fretboard exploration used by the Fretboard Basics lessons.
enum ExploreLesson: Hashable {
    case openStrings
    case fretNumbers
    case findNote(Note)
}

/// A beginner technique screen in Fretboard Basics, drawn as a SwiftUI diagram.
enum TechniqueLesson: Hashable {
    case holding   // how the instrument sits and where the hands go
    case fretting  // pressing a string with the fingertip just behind the fret
}

/// An expandable "Learn more" deep-dive attached to a lesson: a heading, a few
/// short paragraphs, and optional bullet cues. Plain data, rendered by the lesson.
struct LessonDetail: Hashable {
    let heading: String
    let paragraphs: [String]
    var bullets: [String] = []
}

struct Lesson: Identifiable, Hashable {
    let id: Int            // unique within its stage
    let title: String
    let subtitle: String
    let kind: LessonKind
    /// When set, this lesson's forward button opens the named tool tab instead
    /// of just advancing or dismissing.
    var handoff: MainTab? = nil
    /// An optional "Learn more" deep-dive shown under the interactive area.
    var detail: LessonDetail? = nil
}

struct LearningStage: Identifiable, Hashable {
    let id: Int
    let number: String     // "01" ... "05"
    let title: String
    let subtitle: String
    let lessons: [Lesson]
}

enum LearningPath {
    /// The five stages, resolved for the chosen instrument. Stage 2 (Tabs) and
    /// stage 3 (Chords) differ by instrument; the rest are the same and adapt
    /// through the shared fretboard geometry.
    static func stages(for instrument: Instrument) -> [LearningStage] {
        [fretboardBasics, tabs(for: instrument), chords(for: instrument), scalesAndKeys, improvisation]
    }

    private static let fretboardBasics = LearningStage(
        id: 1, number: "01", title: "Fretboard Basics",
        subtitle: "Holding the instrument · fretting · string names · note positions",
        lessons: [
            Lesson(id: 1, title: "Holding the instrument",
                   subtitle: "Before any notes, get comfortable. Here is how the instrument sits and where your hands go.",
                   kind: .technique(.holding),
                   detail: LessonDetail(
                       heading: "Why posture matters",
                       paragraphs: [
                           "Good posture is not about looking right, it is about lasting. A bent wrist or a hunched back tires you out in minutes and is where most beginners quietly give up.",
                           "Keep the instrument pulled in against your body so it does not slide, and let the neck ride a little up and out. That angle is what lets your fretting wrist stay straight instead of cranked."
                       ],
                       bullets: [
                           "If your wrist aches, raise the neck angle before you blame your hand.",
                           "A strap, even sitting down, takes the weight off your fretting hand."
                       ])),
            Lesson(id: 2, title: "Fretting a note",
                   subtitle: "Press the string against the fret with your fingertip, just hard enough to ring clean.",
                   kind: .technique(.fretting),
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
                       ])),
            Lesson(id: 3, title: "Open strings",
                   subtitle: "These are your open strings, low to high. Tap each one to hear it.",
                   kind: .explore(.openStrings),
                   detail: LessonDetail(
                       heading: "Why these notes",
                       paragraphs: [
                           "Standard tuning, low to high, is E A D G B E on guitar and E A D G on bass. Most neighboring strings are a fourth apart, which keeps shapes compact and repeatable up the neck.",
                           "On guitar the one exception is G to B, a third, which is why a few chord shapes feel different on the top strings. Learning the open-string names cold pays off the moment you start naming frets."
                       ],
                       bullets: [
                           "A common memory hook: Eddie Ate Dynamite, Good Bye Eddie.",
                           "The lowest and highest guitar strings are both E, two octaves apart."
                       ])),
            Lesson(id: 4, title: "Fret numbers",
                   subtitle: "Frets count up from the nut, each one a semitone higher. Tap a fret to hear it.",
                   kind: .explore(.fretNumbers),
                   detail: LessonDetail(
                       heading: "Frets are semitones",
                       paragraphs: [
                           "Each fret raises the pitch by one semitone, the smallest step in Western music. Twelve frets up and you are back to the same note one octave higher.",
                           "That is the whole logic of the neck: it is the same twelve notes repeating. Once you can count semitones from an open string, you can name any fret without memorizing them one by one."
                       ],
                       bullets: [
                           "The dots on the neck mark frets 3, 5, 7, 9, and a double dot at 12.",
                           "Fret 12 is the octave, where the pattern starts over."
                       ])),
            Lesson(id: 5, title: "Find a note",
                   subtitle: "The same note lives in many places. Here is every A in the first few frets. Tap any to hear it.",
                   kind: .explore(.findNote(.a)),
                   detail: LessonDetail(
                       heading: "One note, many places",
                       paragraphs: [
                           "The same pitch shows up in several spots because the strings overlap in range. That is not clutter, it is choice: you can play a phrase where your hand already is instead of jumping around.",
                           "Seeing every A at once trains the map in your head. Later, finding the nearest root under your fingers is what makes scales and chords feel reachable instead of memorized."
                       ])),
        ])

    private static func tabs(for instrument: Instrument) -> LearningStage {
        let lessons: [Lesson]
        switch instrument {
        case .guitar:
            lessons = [
                Lesson(id: 1, title: "Reading a tab number",
                       subtitle: "The lines are your strings, lowest at the bottom. A number is the fret to press on that string. Tap a number to hear it.",
                       kind: .tab(.tabReadGuitar),
                       detail: LessonDetail(
                           heading: "What tab does and does not tell you",
                           paragraphs: [
                               "Tab is a map of where to put your fingers: which string, which fret. It is fast to read and needs no theory, which is why so much guitar and bass music is shared this way.",
                               "What plain tab leaves out is rhythm. It shows you the notes in order but not how long each lasts, so you still need to know the tune in your ear or hear it played."
                           ],
                           bullets: [
                               "0 means play the open string; a number means fret that number.",
                               "Bottom line is the lowest string, which trips up readers who expect the opposite."
                           ])),
                Lesson(id: 2, title: "One string, climbing",
                       subtitle: "Same string, higher frets, higher pitch. Tap each note, then press Play.",
                       kind: .tab(.tabClimbGuitar),
                       detail: LessonDetail(
                           heading: "Pitch and fret distance",
                           paragraphs: [
                               "Moving up the same string is the clearest way to feel that higher fret equals higher pitch. Each step is one semitone, and twelve of them is an octave.",
                               "Notice the frets get physically closer together as you climb. The spacing is not even on purpose; it is what keeps every step the same musical distance."
                           ])),
                Lesson(id: 3, title: "Crossing strings",
                       subtitle: "Now the riff jumps between the low two strings. Watch the neck light up as it plays.",
                       kind: .tab(.tabCrossGuitar),
                       detail: LessonDetail(
                           heading: "Same note, two strings",
                           paragraphs: [
                               "Jumping between strings lets you reach notes without sliding your whole hand. A phrase that would be a big stretch on one string sits under four fingers when you use two.",
                               "The fifth fret of a lower string is usually the same pitch as the next string open. That overlap is the trick behind playing in one comfortable position."
                           ])),
                Lesson(id: 4, title: "Timing and repeats",
                       subtitle: "A short pattern that loops. Press Play and let it come around a few times.",
                       kind: .tab(.tabGrooveGuitar),
                       detail: LessonDetail(
                           heading: "Loops and feel",
                           paragraphs: [
                               "Most parts are short patterns that repeat. Once a loop is under your fingers, your attention is free for timing and tone instead of the next note.",
                               "Play it slow until it is even, then let it come around a few times before you speed up. Steady and slow beats fast and ragged every time."
                           ])),
                Lesson(id: 5, title: "Play \u{201C}Drift\u{201D}",
                       subtitle: "Your first full riff. Press Play and follow the neck until it feels locked in.",
                       kind: .tab(.drift),
                       detail: LessonDetail(
                           heading: "Putting it together",
                           paragraphs: [
                               "A full riff strings the moves you just practiced into one phrase: climbing, crossing, and repeating. Follow the lit note on the neck and let your hand learn the path.",
                               "Lock it in slowly. The goal is not speed, it is that the riff plays itself while you listen."
                           ])),
            ]
        case .bass:
            lessons = [
                Lesson(id: 1, title: "Reading a tab number",
                       subtitle: "The lines are your four strings, lowest at the bottom. A number is the fret to press. Tap a number to hear it.",
                       kind: .tab(.tabReadBass),
                       detail: LessonDetail(
                           heading: "Bass tab, four lines",
                           paragraphs: [
                               "Bass tab works the same as guitar tab with four lines instead of six. The bottom line is your low E, the thickest string, and a number is the fret to press.",
                               "Bass usually carries one note at a time, so reading it is mostly about which string and when. Rhythm still lives in your ear, not on the page."
                           ])),
                Lesson(id: 2, title: "One string, climbing",
                       subtitle: "Same string, higher frets, higher pitch. Tap each note, then press Play.",
                       kind: .tab(.tabClimbBass),
                       detail: LessonDetail(
                           heading: "Feeling the low end",
                           paragraphs: [
                               "Climbing one string on bass makes the octave obvious because the low notes are so physical. Twelve frets up is the same note, one octave higher.",
                               "Let each note ring its full length. On bass, how long a note sustains is as much the part as the note itself."
                           ])),
                Lesson(id: 3, title: "Crossing strings",
                       subtitle: "Now the line moves across the low three strings. Watch the neck as it plays.",
                       kind: .tab(.tabCrossBass),
                       detail: LessonDetail(
                           heading: "Staying in position",
                           paragraphs: [
                               "Moving across the low strings keeps your hand in one place while the line jumps around. That economy is what lets bass lines stay relaxed at speed.",
                               "A note on a lower string at the fifth fret matches the next string open. Use that to find the easiest path, not the obvious one."
                           ])),
                Lesson(id: 4, title: "Locking with the beat",
                       subtitle: "A repeating groove. Press Play and feel where the notes land.",
                       kind: .tab(.tabGrooveBass),
                       detail: LessonDetail(
                           heading: "Where the note lands",
                           paragraphs: [
                               "Bass is a rhythm instrument as much as a pitched one. A groove is about exactly when each note hits, not just which note it is.",
                               "Play with the kick drum in mind. Landing right on the beat, or just behind it, is what makes a line feel solid."
                           ])),
                Lesson(id: 5, title: "Play the bassline",
                       subtitle: "Your first full bassline. Press Play and follow the neck until it feels locked in.",
                       kind: .tab(.bassline),
                       detail: LessonDetail(
                           heading: "Holding it down",
                           paragraphs: [
                               "A full bassline is your first taste of the job: keep time, outline the chord, leave space. Follow the neck and let the pattern settle into your hand.",
                               "Once it loops without thought, try locking even tighter to the beat. That pocket is the whole point of the instrument."
                           ])),
            ]
        }
        return LearningStage(
            id: 2, number: "02", title: "Tabs",
            subtitle: "Read tablature as fretboard positions · short riffs",
            lessons: lessons)
    }

    private static func chords(for instrument: Instrument) -> LearningStage {
        let lessons: [Lesson]
        switch instrument {
        case .guitar:
            lessons = [
                Lesson(id: 1, title: "Reading a chord diagram",
                       subtitle: "A chord diagram is the neck seen head on. A ring is an open string, an x is a string you do not play, and a dot is a finger. This is E major. Tap a dot to hear its note.",
                       kind: .chords(["E"]),
                       detail: LessonDetail(
                           heading: "The diagram is the neck head on",
                           paragraphs: [
                               "Turn the neck to face you and that is the diagram. Vertical lines are strings, horizontal lines are frets, and a dot is a finger pressing there.",
                               "A ring above a string means play it open, an x means do not play it at all. Reading those three marks is most of what you need to learn any new shape."
                           ],
                           bullets: [
                               "Now you can hear the whole shape: press Play chord to strum it.",
                               "The numbers off the diagram, when shown, tell you which finger to use."
                           ])),
                Lesson(id: 2, title: "E and Em",
                       subtitle: "Lift one finger off E and it becomes E minor. Step between them and listen to the third drop.",
                       kind: .chords(["E", "Em"]),
                       detail: LessonDetail(
                           heading: "What makes a chord minor",
                           paragraphs: [
                               "Major and minor differ by one note, the third. Lower the third by a semitone and a bright major chord turns into a darker minor one.",
                               "E to E minor is the clearest example because you only lift a single finger. Strum both and the drop in mood is the third moving down."
                           ])),
                Lesson(id: 3, title: "A and Am",
                       subtitle: "The A shape, major and minor. The lowered third is again what turns major into minor.",
                       kind: .chords(["A", "Am"]),
                       detail: LessonDetail(
                           heading: "The same move, a new shape",
                           paragraphs: [
                               "A to A minor is the same idea as E to E minor: the third drops a semitone. Different shape, identical logic.",
                               "Once you hear that the lowered third is what makes minor, you can find it in any chord instead of memorizing each pair separately."
                           ])),
                Lesson(id: 4, title: "D and Dm",
                       subtitle: "The D shape. Three strings carry the chord and the low two stay muted.",
                       kind: .chords(["D", "Dm"]),
                       detail: LessonDetail(
                           heading: "Partial chords",
                           paragraphs: [
                               "The D shapes only use the top four strings. The low two are left out on purpose, marked with an x, because they are not part of this voicing.",
                               "Muting strings you do not want is a real skill. Resting a spare finger lightly against them keeps the chord clean."
                           ])),
                Lesson(id: 5, title: "G and C",
                       subtitle: "Two open staples. When you are ready, open the Chord Library to explore every shape, including F and Bm.",
                       kind: .chords(["G", "C"]),
                       handoff: .chords,
                       detail: LessonDetail(
                           heading: "Workhorse chords",
                           paragraphs: [
                               "G and C show up in a huge share of songs, often right next to each other. Getting a clean change between them unlocks a lot of music.",
                               "When these feel steady, the Chord Library has every other shape, including the barre chords F and B minor that let you move a shape anywhere."
                           ],
                           bullets: ["Open the Chord Library to strum and explore every voicing."])),
            ]
        case .bass:
            lessons = [
                Lesson(id: 1, title: "Play the root",
                       subtitle: "On bass you anchor a chord by playing its root. This is a C chord: the cyan notes are the root, and the dots marked 3 and 5 fill it out. For now, find the cyan roots and tap them.",
                       kind: .arpeggio(root: .c, isMinor: false),
                       detail: LessonDetail(
                           heading: "The root is your anchor",
                           paragraphs: [
                               "Bass rarely plays full chords. Instead you play the chord's root, the note it is named after, and that single note tells the ear which chord it is.",
                               "Get comfortable finding the root fast. Almost everything else on bass is built out from it."
                           ],
                           bullets: ["Press Play root, 3, 5 to hear the chord spelled out one note at a time."])),
                Lesson(id: 2, title: "Find every root",
                       subtitle: "Move to G. The cyan root repeats up the neck and across strings. Find each cyan G and tap it. The dots marked 3 and 5 are the rest of the chord, coming up next.",
                       kind: .arpeggio(root: .g, isMinor: false),
                       detail: LessonDetail(
                           heading: "Roots repeat all over the neck",
                           paragraphs: [
                               "Every note exists in several places, so each root sits under your hand in more than one spot. Knowing the nearest one keeps your playing smooth.",
                               "Same note, an octave up, is a common bass move: it adds energy without changing the harmony."
                           ])),
                Lesson(id: 3, title: "Root and fifth",
                       subtitle: "Root to fifth is the classic bass move. Play the cyan root, then the note marked 5, and back.",
                       kind: .arpeggio(root: .c, isMinor: false),
                       detail: LessonDetail(
                           heading: "The strongest pair",
                           paragraphs: [
                               "Root to fifth is the most stable jump in music and the backbone of countless basslines. The fifth supports the root without coloring the chord major or minor.",
                               "On the neck the fifth usually sits right next door, one string up and a couple of frets over. That shape stays the same wherever you move it."
                           ])),
                Lesson(id: 4, title: "Add the third",
                       subtitle: "The third spells the rest of the chord. This is A minor, and the note marked 3 is the flattened third that makes it minor. Walk root, 3, 5.",
                       kind: .arpeggio(root: .a, isMinor: true),
                       detail: LessonDetail(
                           heading: "The third sets the mood",
                           paragraphs: [
                               "The third is the note that makes a chord major or minor. A flattened third is what gives this A minor its darker color.",
                               "Walking root, third, fifth spells the whole chord with your bass alone. It is the seed of basslines that move instead of just holding the root."
                           ])),
                Lesson(id: 5, title: "Walk a I-IV-V",
                       subtitle: "This is C, the I chord, with its third and fifth marked. In C the IV and V are F and G. Use the cyan root as home and explore. There is no Chord Library on bass, so this is your sandbox.",
                       kind: .arpeggio(root: .c, isMinor: false),
                       detail: LessonDetail(
                           heading: "Three chords, one key",
                           paragraphs: [
                               "The I, IV, and V chords are the three most common in any key. In C they are C, F, and G, and together they harmonize a huge number of songs.",
                               "Use the root as home and the third and fifth to move between chords. This is your sandbox: there is no Chord Library on bass because the neck itself is the tool."
                           ])),
            ]
        }
        return LearningStage(
            id: 3, number: "03", title: "Chords",
            subtitle: "Chord shapes on guitar, root and arpeggio moves on bass",
            lessons: lessons)
    }

    private static let scalesAndKeys = LearningStage(
        id: 4, number: "04", title: "Scales & Keys",
        subtitle: "Major & pentatonic patterns across the neck",
        lessons: [
            Lesson(id: 1, title: "What a scale is",
                   subtitle: "A scale is the set of notes that fit a key. This is E minor pentatonic. The cyan note is the root. Tap any note to hear it.",
                   kind: .scale(key: .e, type: .minorPentatonic, showDegrees: false)),
            Lesson(id: 2, title: "The root and the degrees",
                   subtitle: "Every note shows its scale degree, and the root is 1. Tap up from the root to hear the degrees climb.",
                   kind: .scale(key: .e, type: .minorPentatonic, showDegrees: true)),
            Lesson(id: 3, title: "Minor vs major pentatonic",
                   subtitle: "Same key, brighter sound. This is E major pentatonic. Compare it to the minor shape you just saw.",
                   kind: .scale(key: .e, type: .majorPentatonic, showDegrees: true)),
            Lesson(id: 4, title: "Same shape, new key",
                   subtitle: "Move the whole pattern up and the key changes with it. This is A minor pentatonic: same shape, new root.",
                   kind: .scale(key: .a, type: .minorPentatonic, showDegrees: true)),
            Lesson(id: 5, title: "Explore on your own",
                   subtitle: "Now pick any key and scale yourself and watch the whole neck redraw.",
                   kind: .scale(key: .a, type: .minorPentatonic, showDegrees: true),
                   handoff: .scales),
        ])

    private static let improvisation = LearningStage(
        id: 5, number: "05", title: "Improvisation",
        subtitle: "Solo over a backing track using only safe notes",
        lessons: [
            Lesson(id: 1, title: "Safe notes",
                   subtitle: "Stage 4's scale is now your safety net. Every lit note in A minor pentatonic fits this backing track. Tap any one to hear it.",
                   kind: .scale(key: .a, type: .minorPentatonic, showDegrees: true)),
            Lesson(id: 2, title: "Hear the backing",
                   subtitle: "Press Play backing. Four chords loop, the one playing now lights up, and its root pulses on the neck.",
                   kind: .backing(key: .a, type: .minorPentatonic)),
            Lesson(id: 3, title: "Target the root",
                   subtitle: "As each chord comes around, find its pulsing root and tap it. Landing on the root always sounds resolved.",
                   kind: .backing(key: .a, type: .minorPentatonic)),
            Lesson(id: 4, title: "Short phrases",
                   subtitle: "Play three or four safe notes, then leave space. Short phrases with rests say more than a long scramble.",
                   kind: .backing(key: .a, type: .minorPentatonic)),
            Lesson(id: 5, title: "Take a solo",
                   subtitle: "Press Play backing and improvise over a full loop using only safe notes. When you are ready, open Solo Practice to keep going.",
                   kind: .backing(key: .a, type: .minorPentatonic),
                   handoff: .solo),
        ])
}
