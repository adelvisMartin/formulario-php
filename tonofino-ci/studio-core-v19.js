const NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

export const SCALE_PATTERNS = {
  major: { name: 'Mayor', intervals: [0, 2, 4, 5, 7, 9, 11] },
  minor: { name: 'Menor natural', intervals: [0, 2, 3, 5, 7, 8, 10] },
  pentatonicMajor: { name: 'Pentatónica mayor', intervals: [0, 2, 4, 7, 9] },
  pentatonicMinor: { name: 'Pentatónica menor', intervals: [0, 3, 5, 7, 10] },
  blues: { name: 'Blues', intervals: [0, 3, 5, 6, 7, 10] },
  dorian: { name: 'Dórica', intervals: [0, 2, 3, 5, 7, 9, 10] },
  mixolydian: { name: 'Mixolidia', intervals: [0, 2, 4, 5, 7, 9, 10] }
};

export const CHORD_PATTERNS = {
  major: { name: 'Mayor', intervals: [0, 4, 7] },
  minor: { name: 'Menor', intervals: [0, 3, 7] },
  seventh: { name: 'Séptima', intervals: [0, 4, 7, 10] },
  majorSeventh: { name: 'Mayor 7', intervals: [0, 4, 7, 11] },
  minorSeventh: { name: 'Menor 7', intervals: [0, 3, 7, 10] },
  sus2: { name: 'Sus2', intervals: [0, 2, 7] },
  sus4: { name: 'Sus4', intervals: [0, 5, 7] }
};

export function clamp(value, min, max) {
  return Math.max(min, Math.min(max, Number(value)));
}

export function calculateTapTempo(timestamps, { min = 30, max = 300, maxAgeMs = 3000 } = {}) {
  if (!Array.isArray(timestamps) || timestamps.length < 2) return null;
  const newest = Number(timestamps[timestamps.length - 1]);
  const recent = timestamps.map(Number).filter(value => Number.isFinite(value) && newest - value <= maxAgeMs).slice(-8);
  if (recent.length < 2) return null;
  const intervals = recent.slice(1).map((value, index) => value - recent[index]).filter(value => value >= 120 && value <= 2200);
  if (!intervals.length) return null;
  const sorted = [...intervals].sort((a, b) => a - b);
  const median = sorted[Math.floor(sorted.length / 2)];
  const filtered = intervals.filter(value => Math.abs(value - median) <= Math.max(90, median * 0.28));
  const average = (filtered.length ? filtered : intervals).reduce((sum, value) => sum + value, 0) / (filtered.length || intervals.length);
  return Math.round(clamp(60000 / average, min, max));
}

export function centsBetween(frequency, targetFrequency) {
  if (!Number.isFinite(Number(frequency)) || !Number.isFinite(Number(targetFrequency)) || frequency <= 0 || targetFrequency <= 0) return 0;
  return Math.round(1200 * Math.log2(Number(frequency) / Number(targetFrequency)));
}

export function guidedSampleState({ frequency, targetFrequency, stability = 0, tolerance = 3, stableSince = 0, now = performance.now(), holdMs = 700 } = {}) {
  const cents = centsBetween(frequency, targetFrequency);
  const candidate = Number(frequency) > 0 && Math.abs(cents) <= Number(tolerance) && Number(stability) >= 0.55;
  if (!candidate) return { cents, stableSince: 0, progress: 0, tuned: false };
  const since = stableSince || now;
  const progress = clamp(((now - since) / holdMs) * 100, 0, 100);
  return { cents, stableSince: since, progress, tuned: progress >= 100 };
}

export function noteIndex(noteName) {
  const normalized = String(noteName || '').replace(/\d/g, '').replace('♯', '#').replace('♭', 'b');
  if (/^[A-G]b$/.test(normalized)) {
    const base = NOTE_NAMES.indexOf(normalized[0]);
    return (base + 11) % 12;
  }
  return NOTE_NAMES.indexOf(normalized.toUpperCase());
}

export function noteAtFret(openNote, fret) {
  const openMatch = String(openNote).match(/^([A-G](?:#|b)?)(-?\d)$/i);
  if (!openMatch) return { name: 'C', octave: 4, midi: 60, label: 'C4' };
  const index = noteIndex(openMatch[1]);
  const octave = Number(openMatch[2]);
  const midi = (octave + 1) * 12 + index + Number(fret || 0);
  const name = NOTE_NAMES[((midi % 12) + 12) % 12];
  const resolvedOctave = Math.floor(midi / 12) - 1;
  return { name, octave: resolvedOctave, midi, label: `${name}${resolvedOctave}` };
}

export function patternNoteNames(root, intervals) {
  const rootIndex = noteIndex(root);
  if (rootIndex < 0) return [];
  return intervals.map(interval => NOTE_NAMES[(rootIndex + interval) % 12]);
}

export function fretboardModel({ tuning = ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'], frets = 12, root = 'C', intervals = SCALE_PATTERNS.major.intervals, leftHanded = false } = {}) {
  const activeNotes = new Set(patternNoteNames(root, intervals));
  const strings = tuning.map((openNote, stringIndex) => ({
    openNote,
    stringIndex,
    cells: Array.from({ length: frets + 1 }, (_, fret) => {
      const note = noteAtFret(openNote, fret);
      return { ...note, fret, isActive: activeNotes.has(note.name), isRoot: note.name === root };
    })
  }));
  return leftHanded
    ? strings.map(string => ({ ...string, cells: [...string.cells].reverse() }))
    : strings;
}

export function tempoName(bpm) {
  const value = Number(bpm);
  if (value < 40) return 'Grave';
  if (value < 60) return 'Largo';
  if (value < 76) return 'Adagio';
  if (value < 108) return 'Andante';
  if (value < 120) return 'Moderato';
  if (value < 168) return 'Allegro';
  if (value < 200) return 'Presto';
  return 'Prestissimo';
}

export function loadStudioPrefs(storage = null) {
  const defaults = {
    metronome: { bpm: 92, beats: 4, beatUnit: 4, subdivision: 1, volume: 0.12, accent: true, visualFlash: true, vibrate: false },
    tone: { note: 'A', octave: 4, frequency: 440, wave: 'sine', volume: 0.08, playing: false },
    fretboard: { root: 'C', mode: 'scale', pattern: 'major', frets: 12, leftHanded: false }
  };
  try {
    const target = storage || globalThis.localStorage;
    const stored = JSON.parse(target?.getItem?.('tonofino:studio-prefs:v19') || '{}');
    return {
      metronome: { ...defaults.metronome, ...(stored.metronome || {}) },
      tone: { ...defaults.tone, ...(stored.tone || {}), playing: false },
      fretboard: { ...defaults.fretboard, ...(stored.fretboard || {}) }
    };
  } catch {
    return structuredClone(defaults);
  }
}

export function saveStudioPrefs(prefs, storage = null) {
  try {
    const target = storage || globalThis.localStorage;
    target?.setItem?.('tonofino:studio-prefs:v19', JSON.stringify({
      metronome: prefs.metronome,
      tone: { ...prefs.tone, playing: false },
      fretboard: prefs.fretboard
    }));
  } catch {}
}
