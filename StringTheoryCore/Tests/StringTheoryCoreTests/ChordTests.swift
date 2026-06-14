import Testing
@testable import StringTheoryCore

@Suite("Chord library and chord markers")
struct ChordTests {

    /// Unique notes that actually sound (everything except muted strings).
    private func sounded(_ chord: Chord) -> Set<Note> {
        Set(chordMarkers(chord).filter { $0.kind != .muted }.compactMap(\.note))
    }

    @Test("Library has the 10 starter voicings in order")
    func library() {
        #expect(Chord.library.count == 10)
        #expect(Chord.library.map(\.id) == ["C", "A", "G", "E", "D", "Am", "Em", "Dm", "F", "Bm"])
        #expect(Chord.named("F")?.family == .barre)
        #expect(Chord.named("Am")?.quality == .minor)
    }

    @Test("C major: low string muted, open G and high-E strings, sounds C E G")
    func cMajor() {
        let m = chordMarkers(Chord.named("C")!)
        #expect(m[0].kind == .muted)                       // low E not played
        #expect(m[3].kind == .open && m[3].note == .g)     // open G string
        #expect(m[5].kind == .open && m[5].note == .e)     // open high e
        #expect(m[1].kind == .safe && m[1].note == .c && m[1].fret == 3)
        #expect(m[1].label == "C")
        #expect(sounded(Chord.named("C")!) == [.c, .e, .g])
    }

    @Test("G major sounds G B D")
    func gMajor() {
        #expect(sounded(Chord.named("G")!) == [.g, .b, .d])
    }

    @Test("A minor: low string muted, sounds A C E")
    func aMinor() {
        let m = chordMarkers(Chord.named("Am")!)
        #expect(m[0].kind == .muted)
        #expect(sounded(Chord.named("Am")!) == [.a, .c, .e])
    }

    @Test("F barre: all six strings fretted, sounds F A C, spans frets 1–3")
    func fBarre() {
        let f = Chord.named("F")!
        let m = chordMarkers(f)
        #expect(m.allSatisfy { $0.kind == .safe })   // no open or muted strings
        #expect(sounded(f) == [.f, .a, .c])
        #expect(chordSpan(f) == FretSpan(min: 1, max: 3))
    }
}
