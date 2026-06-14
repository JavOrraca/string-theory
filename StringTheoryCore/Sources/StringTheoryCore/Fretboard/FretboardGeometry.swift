/// A normalized point on the fretboard — percentages in `0...100` of the board's
/// width (`x`) and height (`y`). The renderer scales these into pixels.
public struct GridPoint: Sendable, Hashable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Pure, view-independent fretboard layout math — the port of the geometry in
/// `Fretboard.dc.html`. Every output is a percentage of the board rectangle, so
/// the renderer only multiplies by its pixel size.
///
/// Strings are indexed `0` = lowest-pitched (drawn at the bottom). Left-handed
/// layout is an exact horizontal mirror (`x → 100 - x`).
public struct FretboardGeometry: Sendable, Hashable {
    public let stringCount: Int
    /// Number of frets visible in the window.
    public let fretCount: Int
    /// First fret shown (`0` = open position, where the nut is drawn).
    public let startFret: Int
    public let isLeftHanded: Bool

    /// Open-string zone before the nut, percent of width (prototype `GUT`).
    public var gutter: Double
    /// Right margin, percent of width (prototype `RM`).
    public var rightMargin: Double
    /// Top/bottom string inset, percent of height (prototype `PAD`).
    public var verticalPadding: Double

    public init(
        stringCount: Int,
        fretCount: Int,
        startFret: Int = 0,
        isLeftHanded: Bool = false,
        gutter: Double = 13,
        rightMargin: Double = 3,
        verticalPadding: Double = 13
    ) {
        self.stringCount = stringCount
        self.fretCount = fretCount
        self.startFret = startFret
        self.isLeftHanded = isLeftHanded
        self.gutter = gutter
        self.rightMargin = rightMargin
        self.verticalPadding = verticalPadding
    }
}

public extension FretboardGeometry {
    /// Inlay marker kind for an absolute fret number.
    enum Inlay: Sendable, Hashable { case single, double }

    /// Horizontal extent available for the fretted area (prototype `_span`).
    var span: Double { 100 - gutter - rightMargin }

    /// Apply left-handed mirroring to an x percentage.
    func mirror(_ x: Double) -> Double { isLeftHanded ? 100 - x : x }

    /// Whether the given fret-line column is the nut (column 0 in open position).
    func isNut(column: Int) -> Bool { column == 0 && startFret == 0 }

    /// The inlay dot(s) for an absolute fret number, if any.
    static func inlay(forAbsoluteFret fret: Int) -> Inlay? {
        if fret == 12 || fret == 24 { return .double }
        if [3, 5, 7, 9, 15, 17, 19, 21].contains(fret) { return .single }
        return nil
    }

    /// Center Y% of a string. Index 0 = lowest-pitched, drawn at the bottom.
    func stringY(_ index: Int) -> Double {
        let divisor = Double(max(1, stringCount - 1))
        return verticalPadding
            + (Double(stringCount - 1 - index) / divisor) * (100 - 2 * verticalPadding)
    }

    /// X% of a fret line. Column 0 = nut.
    func fretLineX(column: Int) -> Double {
        mirror(gutter + (Double(column) / Double(fretCount)) * span)
    }

    /// X% of the center of a visible fret column (1-based within the window).
    func fretCenterX(column: Int) -> Double {
        mirror(gutter + ((Double(column) - 0.5) / Double(fretCount)) * span)
    }

    /// X% of the open-string zone, where open/muted markers sit.
    var openStringX: Double {
        mirror(gutter * 0.45)
    }

    /// The normalized point at which to draw `marker`. Open and muted markers
    /// (`fret <= 0`) sit in the gutter; fretted markers sit at the fret center,
    /// offset by `startFret` so a scrolled window lines up.
    func position(for marker: Marker) -> GridPoint {
        let y = stringY(marker.string)
        let x = marker.fret <= 0 ? openStringX : fretCenterX(column: marker.fret - startFret)
        return GridPoint(x: x, y: y)
    }
}
