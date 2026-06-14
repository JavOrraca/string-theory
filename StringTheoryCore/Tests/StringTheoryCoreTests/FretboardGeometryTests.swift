import Testing
@testable import StringTheoryCore

@Suite("Fretboard geometry")
struct FretboardGeometryTests {
    let g6 = FretboardGeometry(stringCount: 6, fretCount: 5)                       // right-handed, open
    let g6L = FretboardGeometry(stringCount: 6, fretCount: 5, isLeftHanded: true)  // mirrored

    @Test("Low string sits at the bottom, high string at the top")
    func stringYPositions() {
        #expect(abs(g6.stringY(0) - 87) < 0.001)    // low E at the bottom
        #expect(abs(g6.stringY(5) - 13) < 0.001)    // high e at the top
        #expect(abs(g6.stringY(2) - 57.4) < 0.001)
    }

    @Test("Fret lines: column 0 is the nut, evenly spaced to the right margin")
    func fretLines() {
        #expect(g6.isNut(column: 0))
        #expect(!g6.isNut(column: 1))
        #expect(abs(g6.span - 84) < 0.001)
        #expect(abs(g6.fretLineX(column: 0) - 13) < 0.001)
        #expect(abs(g6.fretLineX(column: 5) - 97) < 0.001)
    }

    @Test("Fret centers and the open-string zone")
    func fretCentersAndGutter() {
        #expect(abs(g6.fretCenterX(column: 1) - 21.4) < 0.001)
        #expect(abs(g6.fretCenterX(column: 3) - 55) < 0.001)
        #expect(abs(g6.openStringX - 5.85) < 0.001)
    }

    @Test("Markers map to the right (string, fret): open in the gutter, fretted at fret-center")
    func markerPositions() {
        let open = g6.position(for: Marker(string: 0, fret: 0, kind: .open))
        #expect(abs(open.x - 5.85) < 0.001)
        #expect(abs(open.y - 87) < 0.001)

        let g = g6.position(for: Marker(string: 0, fret: 3, kind: .safe))
        #expect(abs(g.x - 55) < 0.001)   // fretCenterX(3)
        #expect(abs(g.y - 87) < 0.001)
    }

    @Test("Left-handed layout is the exact horizontal mirror of right-handed")
    func leftyMirror() {
        for string in 0..<6 {
            for fret in 0...5 {
                let m = Marker(string: string, fret: fret, kind: .safe)
                let r = g6.position(for: m)
                let l = g6L.position(for: m)
                #expect(abs(l.x - (100 - r.x)) < 0.0001)   // mirrored across the centerline
                #expect(abs(l.y - r.y) < 0.0001)           // vertical position unchanged
            }
        }
    }

    @Test("Inlay dots: singles at 3 5 7 9…, doubles at the 12th and 24th frets")
    func inlays() {
        #expect(FretboardGeometry.inlay(forAbsoluteFret: 3) == .single)
        #expect(FretboardGeometry.inlay(forAbsoluteFret: 5) == .single)
        #expect(FretboardGeometry.inlay(forAbsoluteFret: 12) == .double)
        #expect(FretboardGeometry.inlay(forAbsoluteFret: 24) == .double)
        #expect(FretboardGeometry.inlay(forAbsoluteFret: 4) == nil)
        #expect(FretboardGeometry.inlay(forAbsoluteFret: 0) == nil)
    }
}
