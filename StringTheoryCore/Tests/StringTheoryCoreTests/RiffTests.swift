import Testing
@testable import StringTheoryCore

@Suite("Tab teaching riffs")
struct RiffTests {

    private func expectValid(_ riff: Riff, on tuning: Tuning) {
        for step in riff.steps {
            #expect(step.string >= 0)
            #expect(step.string < tuning.stringCount)
            #expect(step.fret >= 0)
            #expect(step.fret <= 12)
        }
    }

    @Test("Drift fits the guitar neck")
    func drift() {
        expectValid(.drift, on: .guitar)
    }

    @Test("Guitar teaching riffs fit the guitar neck")
    func guitarRiffs() {
        for riff in [Riff.tabReadGuitar, .tabClimbGuitar, .tabCrossGuitar, .tabGrooveGuitar] {
            expectValid(riff, on: .guitar)
        }
    }

    @Test("Bass teaching riffs fit the bass neck")
    func bassRiffs() {
        for riff in [Riff.tabReadBass, .tabClimbBass, .tabCrossBass, .tabGrooveBass, .bassline] {
            expectValid(riff, on: .bass)
        }
    }
}
