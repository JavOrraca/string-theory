import Testing
import Foundation
@testable import StringTheoryCore

@Suite("Pitch detection")
struct PitchDetectorTests {

    /// A pure sine of `hz` for `seconds` at `sampleRate`, amplitude 0.5.
    private func sine(hz: Double, seconds: Double, sampleRate: Double = 44_100) -> [Float] {
        let n = Int(seconds * sampleRate)
        return (0..<n).map { i in
            Float(0.5 * sin(2 * .pi * hz * Double(i) / sampleRate))
        }
    }

    @Test("detects mid-range guitar A (110 Hz)")
    func detectsA() {
        let hz = detectPitchHz(sine(hz: 110, seconds: 0.2), sampleRate: 44_100)
        #expect(hz != nil)
        #expect(abs(hz! - 110) < 110 * 0.01)   // within 1 percent
    }

    @Test("detects guitar low E (82.41 Hz)")
    func detectsLowE() {
        let hz = detectPitchHz(sine(hz: 82.41, seconds: 0.25), sampleRate: 44_100)
        #expect(hz != nil)
        #expect(abs(hz! - 82.41) < 82.41 * 0.01)
    }

    @Test("detects bass low E (41.20 Hz) with a longer window")
    func detectsBassLowE() {
        let hz = detectPitchHz(sine(hz: 41.20, seconds: 0.35), sampleRate: 44_100)
        #expect(hz != nil)
        #expect(abs(hz! - 41.20) < 41.20 * 0.015)
    }

    @Test("returns nil for silence")
    func silenceIsNil() {
        let quiet = [Float](repeating: 0, count: 4096)
        #expect(detectPitchHz(quiet, sampleRate: 44_100) == nil)
    }

    @Test("cents offset is signed and symmetric")
    func cents() {
        #expect(abs(centsOff(hz: 440, targetHz: 440)) < 0.001)
        #expect(centsOff(hz: 466.16, targetHz: 440) > 99)     // ~+100 cents (a semitone)
        #expect(centsOff(hz: 415.30, targetHz: 440) < -99)    // ~-100 cents
    }

    @Test("nearest string maps a slightly sharp A to the A string")
    func nearest() {
        let result = nearestString(toHz: 112, in: .guitar)
        #expect(result.target.note == .a)
        #expect(result.cents > 0)
    }

    @Test("nearest string tells low E from high e by octave")
    func nearestOctave() {
        #expect(nearestString(toHz: 84, in: .guitar).index == 0)    // low E string
        #expect(nearestString(toHz: 320, in: .guitar).index == 5)   // high e string
    }
}
