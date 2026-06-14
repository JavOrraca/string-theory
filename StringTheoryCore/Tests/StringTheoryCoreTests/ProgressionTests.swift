import Testing
@testable import StringTheoryCore

@Suite("Riff and backing progression")
struct ProgressionTests {

    @Test("The Drift riff is 12 steps in E minor pentatonic")
    func driftRiff() {
        #expect(Riff.drift.key == .e)
        #expect(Riff.drift.scale == .minorPentatonic)
        #expect(Riff.drift.steps.count == 12)
        #expect(Riff.drift.steps.first == RiffStep(string: 0, fret: 0))
        #expect(Riff.drift.steps.last == RiffStep(string: 2, fret: 0))
    }

    @Test("A minor backing loop is Am F C G (i VI III VII)")
    func aMinorProgression() {
        let prog = backingProgression(key: .a, scale: .minorPentatonic)
        #expect(prog.map(\.name) == ["Am", "F", "C", "G"])
        #expect(prog.map(\.isMinor) == [true, false, false, false])
    }

    @Test("E minor backing loop is Em C G D")
    func eMinorProgression() {
        #expect(backingProgression(key: .e, scale: .naturalMinor).map(\.name) == ["Em", "C", "G", "D"])
    }

    @Test("C major backing loop is C G Am F (I V vi IV)")
    func cMajorProgression() {
        let prog = backingProgression(key: .c, scale: .major)
        #expect(prog.map(\.name) == ["C", "G", "Am", "F"])
        #expect(prog.map(\.isMinor) == [false, false, true, false])
    }
}
