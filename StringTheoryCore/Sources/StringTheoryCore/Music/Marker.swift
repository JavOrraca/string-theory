/// What a fretboard dot means — the five kinds from the prototype palette, plus
/// the small `ghost` hint used to suggest nearby positions.
public enum MarkerKind: String, Sendable, Hashable, CaseIterable {
    case root    // the tonic — cyan
    case safe    // any other in-key / in-chord tone — green outline
    case active  // currently sounding — green fill
    case open    // an open string — green ring
    case muted   // do not play — red ×
    case ghost   // dim positional hint
}

/// A single dot to draw on the fretboard. Pure data — the view turns this into
/// pixels (see `FretboardView`), the geometry turns it into a point (see
/// `FretboardGeometry`).
public struct Marker: Sendable, Hashable {
    /// 0 = lowest-pitched string (low E on guitar/bass).
    public var string: Int
    /// 0 = open string / nut.
    public var fret: Int
    public var kind: MarkerKind
    /// The pitch this dot sounds, when known.
    public var note: Note?
    /// Text drawn on the dot — a scale-degree number or a note name.
    public var label: String?

    public init(string: Int, fret: Int, kind: MarkerKind, note: Note? = nil, label: String? = nil) {
        self.string = string
        self.fret = fret
        self.kind = kind
        self.note = note
        self.label = label
    }
}
