import Testing
@testable import StringTheoryCore

@Suite("Scales, degrees, and scale markers")
struct ScaleTests {

    @Test("Scale intervals match music.js")
    func intervals() {
        #expect(ScaleType.major.intervals == [0, 2, 4, 5, 7, 9, 11])
        #expect(ScaleType.majorPentatonic.intervals == [0, 2, 4, 7, 9])
        #expect(ScaleType.minorPentatonic.intervals == [0, 3, 5, 7, 10])
        #expect(ScaleType.naturalMinor.intervals == [0, 2, 3, 5, 7, 8, 10])
    }

    @Test("Minor scales report as minor; major scales do not")
    func tonality() {
        #expect(ScaleType.minorPentatonic.isMinor)
        #expect(ScaleType.naturalMinor.isMinor)
        #expect(!ScaleType.major.isMinor)
        #expect(!ScaleType.majorPentatonic.isMinor)
    }

    @Test("Degree labels use flats for the altered tones")
    func degreeLabels() {
        #expect(Scale.degreeLabel(forInterval: 0) == "1")
        #expect(Scale.degreeLabel(forInterval: 3) == "♭3")
        #expect(Scale.degreeLabel(forInterval: 5) == "4")
        #expect(Scale.degreeLabel(forInterval: 7) == "5")
        #expect(Scale.degreeLabel(forInterval: 10) == "♭7")
        #expect(Scale.degreeLabel(forInterval: 11) == "7")
    }

    @Test("E minor pentatonic is E G A B D with degrees 1 ♭3 4 5 ♭7")
    func eMinorPentatonic() {
        let map = scaleMap(key: .e, scale: .minorPentatonic)
        #expect(Set(map.keys) == [.e, .g, .a, .b, .d])
        #expect(map[.e]?.label == "1")
        #expect(map[.g]?.label == "♭3")
        #expect(map[.a]?.label == "4")
        #expect(map[.b]?.label == "5")
        #expect(map[.d]?.label == "♭7")
    }

    @Test("C major is the natural notes C D E F G A B")
    func cMajor() {
        let map = scaleMap(key: .c, scale: .major)
        #expect(Set(map.keys) == [.c, .d, .e, .f, .g, .a, .b])
        #expect(map[.c]?.label == "1")
        #expect(map[.g]?.label == "5")
        #expect(map[.b]?.label == "7")
    }

    @Test("A natural minor is A B C D E F G")
    func aNaturalMinor() {
        let map = scaleMap(key: .a, scale: .naturalMinor)
        #expect(Set(map.keys) == [.a, .b, .c, .d, .e, .f, .g])
        #expect(map[.a]?.label == "1")
        #expect(map[.c]?.label == "♭3")
    }

    @Test("Scale markers tag the tonic as root, other tones as safe")
    func scaleMarkersRootAndSafe() {
        let markers = scaleMarkers(instrument: .guitar, key: .e, scale: .minorPentatonic)
        // Open low E (string 0, fret 0) is the tonic.
        let openLowE = markers.first { $0.string == 0 && $0.fret == 0 }
        #expect(openLowE?.kind == .root)
        #expect(openLowE?.note == .e)
        #expect(openLowE?.label == "1")
        // 3rd fret of low E = G, an in-scale safe tone.
        let g = markers.first { $0.string == 0 && $0.fret == 3 }
        #expect(g?.kind == .safe)
        #expect(g?.note == .g)
        // A marker is `.root` exactly when its note is the key.
        #expect(markers.allSatisfy { ($0.kind == .root) == ($0.note == .e) })
        // Inclusive 0...12 window includes both the open string and the 12th fret.
        #expect(markers.contains { $0.string == 0 && $0.fret == 12 && $0.note == .e })
    }
}
