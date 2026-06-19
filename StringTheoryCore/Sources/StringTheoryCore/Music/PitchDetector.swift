import Foundation

/// Monophonic fundamental-frequency detection by the YIN algorithm
/// (de Cheveigne and Kawahara). Pure and testable: feed it a buffer of mono
/// samples and a sample rate. Returns nil for near-silence or when no clear
/// period is found. The default range spans a bass low E (about 41 Hz) up to
/// just past a high guitar e.
public func detectPitchHz(
    _ samples: [Float],
    sampleRate: Double,
    minHz: Double = 38,
    maxHz: Double = 1350,
    threshold: Double = 0.15
) -> Double? {
    let n = samples.count
    guard n > 2 else { return nil }

    let maxLag = min(n / 2, Int((sampleRate / minHz).rounded(.up)))
    let minLag = max(2, Int((sampleRate / maxHz).rounded(.down)))
    guard maxLag > minLag else { return nil }

    // Near-silence gate so the reading does not chase noise.
    var sumSquares = 0.0
    for s in samples { sumSquares += Double(s) * Double(s) }
    guard (sumSquares / Double(n)).squareRoot() > 0.01 else { return nil }

    // Difference function and its cumulative-mean normalization (CMNDF).
    let window = n - maxLag
    var cmnd = [Double](repeating: 1, count: maxLag + 1)
    var runningSum = 0.0
    for tau in 1...maxLag {
        var diff = 0.0
        for i in 0..<window {
            let delta = Double(samples[i]) - Double(samples[i + tau])
            diff += delta * delta
        }
        runningSum += diff
        cmnd[tau] = runningSum > 0 ? diff * Double(tau) / runningSum : 1
    }

    // First tau in range that dips below the threshold, then descend to its
    // local minimum (YIN's absolute-threshold step). This avoids octave errors.
    var tau = minLag
    while tau <= maxLag {
        if cmnd[tau] < threshold {
            while tau + 1 <= maxLag && cmnd[tau + 1] < cmnd[tau] { tau += 1 }
            break
        }
        tau += 1
    }
    guard tau <= maxLag, cmnd[tau] < threshold else { return nil }

    // Parabolic interpolation around the minimum for sub-sample accuracy.
    let betterTau: Double
    if tau > 1, tau < maxLag {
        let s0 = cmnd[tau - 1], s1 = cmnd[tau], s2 = cmnd[tau + 1]
        let denom = s0 - 2 * s1 + s2
        betterTau = denom != 0 ? Double(tau) + 0.5 * (s0 - s2) / denom : Double(tau)
    } else {
        betterTau = Double(tau)
    }
    return sampleRate / betterTau
}

/// Signed cents from `targetHz` to `hz` (positive = sharp).
public func centsOff(hz: Double, targetHz: Double) -> Double {
    guard hz > 0, targetHz > 0 else { return 0 }
    return 1200 * log2(hz / targetHz)
}

/// The open string in `tuning` closest to `hz` in cents, with the signed cents
/// to it. Closest in cents, so the two E strings are told apart by octave.
public func nearestString(toHz hz: Double, in tuning: Tuning) -> (index: Int, target: OpenString, cents: Double) {
    var bestIndex = 0
    var bestCents = Double.greatestFiniteMagnitude
    for (i, string) in tuning.strings.enumerated() {
        let c = centsOff(hz: hz, targetHz: string.frequency)
        if abs(c) < abs(bestCents) {
            bestCents = c
            bestIndex = i
        }
    }
    return (bestIndex, tuning.strings[bestIndex], bestCents)
}
