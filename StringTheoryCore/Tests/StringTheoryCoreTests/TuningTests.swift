import Testing
@testable import StringTheoryCore

@Suite("Tunings")
struct TuningTests {

    @Test("Guitar is 6 strings — E A D G B E, low to high — with standard frequencies")
    func guitar() {
        #expect(Tuning.guitar.strings.map(\.note) == [.e, .a, .d, .g, .b, .e])
        #expect(Tuning.guitar.stringCount == 6)
        #expect(Tuning.guitar.strings.first?.frequency == 82.41)
        #expect(Tuning.guitar.strings.last?.frequency == 329.63)
    }

    @Test("Bass is 4 strings — E A D G, low to high")
    func bass() {
        #expect(Tuning.bass.strings.map(\.note) == [.e, .a, .d, .g])
        #expect(Tuning.bass.stringCount == 4)
        #expect(Tuning.bass.strings.first?.frequency == 41.20)
    }

    @Test("Instrument exposes its standard string count")
    func instrumentStringCounts() {
        #expect(Instrument.guitar.stringCount == 6)
        #expect(Instrument.bass.stringCount == 4)
    }
}
