import Testing
@testable import StringTheoryCore

@Suite("Note & pitch math")
struct NoteTests {

    @Test("The 12 pitch classes are sharp-spelled, C-indexed, matching music.js NOTES")
    func chromaticNames() {
        #expect(Note.allCases.map(\.name) == [
            "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B",
        ])
        #expect(Note(name: "F#") == .fSharp)
        #expect(Note(name: "H") == nil)
    }

    @Test("noteAt advances by frets and wraps around the octave")
    func noteAtWraps() {
        #expect(noteAt(open: .e, fret: 0) == .e)   // open low E
        #expect(noteAt(open: .e, fret: 1) == .f)   // one semitone up
        #expect(noteAt(open: .e, fret: 5) == .a)   // 5th fret of E = A
        #expect(noteAt(open: .b, fret: 1) == .c)   // wraps B -> C
        #expect(noteAt(open: .a, fret: 12) == .a)  // up an octave = same pitch class
    }

    @Test("freqAt doubles every 12 frets (equal temperament)")
    func freqDoublesPerOctave() {
        #expect(freqAt(base: 110.0, fret: 12) == 220.0)        // A2 -> A3
        #expect(freqAt(base: 82.41, fret: 0) == 82.41)         // open low E unchanged
        #expect(abs(freqAt(base: 82.41, fret: 12) - 164.82) < 0.001) // E2 -> E3
        #expect(abs(freqAt(base: 110.0, fret: 7) - 164.81) < 0.01)   // A2 + 7 semis ≈ E3
    }

    @Test("frequency(octave:) is MIDI concert pitch with A4 = 440")
    func concertPitch() {
        #expect(Note.a.frequency(octave: 4) == 440)
        #expect(Note.a.frequency(octave: 2) == 110)
        #expect(abs(Note.e.frequency(octave: 2) - 82.41) < 0.01)   // open low E
        #expect(abs(Note.c.frequency(octave: 4) - 261.63) < 0.01)  // middle C
    }
}
