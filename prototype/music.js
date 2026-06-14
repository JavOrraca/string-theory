// String Theory — music theory engine (pure data + helpers)

export const NOTES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

// Standard tunings, stored LOW string -> HIGH string.
// Each entry: open note name + base frequency (Hz) of the open string.
export const TUNINGS = {
  guitar: [
    { note: 'E', freq: 82.41 },   // string 6 (low E, thickest)
    { note: 'A', freq: 110.0 },   // string 5
    { note: 'D', freq: 146.83 },  // string 4
    { note: 'G', freq: 196.0 },   // string 3
    { note: 'B', freq: 246.94 },  // string 2
    { note: 'E', freq: 329.63 },  // string 1 (high e)
  ],
  bass: [
    { note: 'E', freq: 41.20 },
    { note: 'A', freq: 55.0 },
    { note: 'D', freq: 73.42 },
    { note: 'G', freq: 98.0 },
  ],
};

export const KEYS = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

export const SCALES = {
  major:       { label: 'Major',           intervals: [0, 2, 4, 5, 7, 9, 11] },
  majorPent:   { label: 'Major Pentatonic', intervals: [0, 2, 4, 7, 9] },
  minorPent:   { label: 'Minor Pentatonic', intervals: [0, 3, 5, 7, 10] },
  naturalMin:  { label: 'Natural Minor',    intervals: [0, 2, 3, 5, 7, 8, 10] },
};

const DEGREE = {
  0: '1', 1: '♭2', 2: '2', 3: '♭3', 4: '3', 5: '4',
  6: '♭5', 7: '5', 8: '♭6', 9: '6', 10: '♭7', 11: '7',
};

export function noteAt(openNote, fret) {
  const i = NOTES.indexOf(openNote);
  return NOTES[(i + fret) % 12];
}

export function freqAt(baseFreq, fret) {
  return baseFreq * Math.pow(2, fret / 12);
}

// Returns map noteName -> { degree, interval } for a given key+scale.
export function scaleMap(key, scaleType) {
  const root = NOTES.indexOf(key);
  const intervals = (SCALES[scaleType] || SCALES.majorPent).intervals;
  const map = {};
  for (const iv of intervals) {
    const n = NOTES[(root + iv) % 12];
    map[n] = { degree: DEGREE[iv], interval: iv };
  }
  return map;
}

// Build fretboard markers for a scale across [startFret..startFret+count].
// kind: 'root' for the tonic, 'safe' for other scale tones.
export function scaleMarkers(instrument, key, scaleType, count = 12, startFret = 0) {
  const tuning = TUNINGS[instrument] || TUNINGS.guitar;
  const map = scaleMap(key, scaleType);
  const out = [];
  tuning.forEach((str, sIdx) => {
    for (let f = startFret; f <= startFret + count; f++) {
      const n = noteAt(str.note, f);
      if (map[n]) {
        out.push({
          string: sIdx,
          fret: f,
          label: map[n].degree,
          note: n,
          kind: n === key ? 'root' : 'safe',
        });
      }
    }
  });
  return out;
}

// ── Chord library (guitar, low->high string order). -1 = muted, 0 = open. ──
export const CHORDS = [
  { id: 'C',  name: 'C',  quality: 'major', frets: [-1, 3, 2, 0, 1, 0], family: 'Open' },
  { id: 'A',  name: 'A',  quality: 'major', frets: [-1, 0, 2, 2, 2, 0], family: 'Open' },
  { id: 'G',  name: 'G',  quality: 'major', frets: [3, 2, 0, 0, 0, 3],  family: 'Open' },
  { id: 'E',  name: 'E',  quality: 'major', frets: [0, 2, 2, 1, 0, 0],  family: 'Open' },
  { id: 'D',  name: 'D',  quality: 'major', frets: [-1, -1, 0, 2, 3, 2], family: 'Open' },
  { id: 'Am', name: 'Am', quality: 'minor', frets: [-1, 0, 2, 2, 1, 0], family: 'Open' },
  { id: 'Em', name: 'Em', quality: 'minor', frets: [0, 2, 2, 0, 0, 0],  family: 'Open' },
  { id: 'Dm', name: 'Dm', quality: 'minor', frets: [-1, -1, 0, 2, 3, 1], family: 'Open' },
  { id: 'F',  name: 'F',  quality: 'major', frets: [1, 3, 3, 2, 1, 1],  family: 'Barre' },
  { id: 'Bm', name: 'Bm', quality: 'minor', frets: [-1, 2, 4, 4, 3, 2], family: 'Barre' },
];

// Build markers for a chord diagram, including open (ring) and muted (X) indicators.
export function chordMarkers(chord) {
  const tuning = TUNINGS.guitar;
  const out = [];
  chord.frets.forEach((f, sIdx) => {
    const open = tuning[sIdx].note;
    if (f === -1) {
      out.push({ string: sIdx, fret: 0, kind: 'muted' });
    } else if (f === 0) {
      out.push({ string: sIdx, fret: 0, kind: 'open', note: open, label: open });
    } else {
      out.push({ string: sIdx, fret: f, kind: 'safe', note: noteAt(open, f), label: noteAt(open, f) });
    }
  });
  return out;
}

export function chordSpan(chord) {
  const fretted = chord.frets.filter((f) => f > 0);
  if (!fretted.length) return { min: 0, max: 4 };
  return { min: Math.min(...fretted), max: Math.max(...fretted) };
}

// ── A short original riff for the Tabs lesson (E minor pentatonic territory). ──
// Each step: string index (low->high), fret. Played left to right.
export const RIFF = {
  name: 'Riff 01 — “Drift”',
  key: 'E',
  scaleType: 'minorPent',
  steps: [
    { string: 0, fret: 0 }, { string: 0, fret: 3 }, { string: 1, fret: 0 },
    { string: 0, fret: 0 }, { string: 0, fret: 3 }, { string: 1, fret: 2 },
    { string: 1, fret: 0 }, { string: 0, fret: 3 }, { string: 0, fret: 0 },
    { string: 1, fret: 0 }, { string: 1, fret: 2 }, { string: 2, fret: 0 },
  ],
};

// Diatonic backing-track chord loops per key (simple I–V–vi–IV-ish in minor: i–VI–III–VII).
export function backingProgression(key, scaleType) {
  const root = NOTES.indexOf(key);
  const minor = scaleType.toLowerCase().includes('min');
  // scale-degree semitone offsets for the loop
  const degMinor = [0, 8, 3, 10];   // i, VI, III, VII
  const degMajor = [0, 7, 9, 5];    // I, V, vi, IV
  const degs = minor ? degMinor : degMajor;
  return degs.map((d, i) => {
    const rn = NOTES[(root + d) % 12];
    const isMinorChord = minor ? [true, false, false, false][i] : [false, false, true, false][i];
    return { root: rn, minor: isMinorChord, freq: 0 };
  });
}
