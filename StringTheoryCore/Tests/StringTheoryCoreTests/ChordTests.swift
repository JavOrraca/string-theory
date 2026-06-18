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

    @Test("Chord tones are root, major or minor third, and perfect fifth")
    func chordTonesMajorAndMinor() {
        #expect(chordTones(root: .c, isMinor: false) == [.c, .e, .g])
        #expect(chordTones(root: .a, isMinor: true) == [.a, .c, .e])
        #expect(chordTones(root: .g, isMinor: false) == [.g, .b, .d])
    }

    @Test("Arpeggio markers label root, third, and fifth across the bass neck")
    func arpeggioMarkersLabelRootThirdFifth() {
        let markers = arpeggioMarkers(instrument: .bass, root: .c, isMinor: false, frets: 12)
        #expect(!markers.isEmpty)
        // Every marker sounds one of the three chord tones.
        let tones: Set<Note> = [.c, .e, .g]
        #expect(markers.allSatisfy { ($0.note.map(tones.contains)) ?? false })
        // Roots glow (kind .root), are the C, and are labelled "R".
        let roots = markers.filter { $0.kind == .root }
        #expect(!roots.isEmpty)
        #expect(roots.allSatisfy { $0.note == .c && $0.label == "R" })
        // The C on the bass A string (string index 1, fret 3) is a labelled root.
        #expect(markers.contains { $0.string == 1 && $0.fret == 3 && $0.kind == .root && $0.label == "R" })
        // Third and fifth are present and labelled.
        #expect(markers.contains { $0.note == .e && $0.kind == .safe && $0.label == "3" })
        #expect(markers.contains { $0.note == .g && $0.kind == .safe && $0.label == "5" })
    }

    @Test("Arpeggio markers place tones on a guitar neck too")
    func arpeggioMarkersOnGuitar() {
        let markers = arpeggioMarkers(instrument: .guitar, root: .c, isMinor: false, frets: 12)
        #expect(!markers.isEmpty)
        // C on the guitar A string (index 1, fret 3) is a labelled root.
        #expect(markers.contains { $0.string == 1 && $0.fret == 3 && $0.kind == .root && $0.label == "R" })
        // G, the fifth, on the D string (index 2, fret 5).
        #expect(markers.contains { $0.string == 2 && $0.fret == 5 && $0.note == .g && $0.label == "5" })
    }
}
