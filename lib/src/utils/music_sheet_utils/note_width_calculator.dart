import 'package:music_keyboard/models/music_note.dart';

/// Map of note types to their widths in pixels
final Map<NoteType, double> noteTypeWidths = {
  NoteType.clef: 26.0,
  NoteType.whole: 20.0,
  NoteType.half: 20.0,
  NoteType.quarter: 20.0,
  NoteType.eighth: 20.0,
  NoteType.sixteenth: 20.0,
  NoteType.thirtySecond: 20.0,
  NoteType.sixtyFourth: 20.0,
  NoteType.rest: 20.0,
  NoteType.accidental: 20.0
};

/// Map of specific unicode characters to their widths (for special cases)
final Map<String, double> unicodeCharacterWidths = {
  // Add specific character widths if needed
  '\uf472': 30.0, // Example: if a specific clef is wider
  '\uf474': 30.0, // Example: if a specific clef is wider
};

/// Get the width of a note based on its type and unicode character
double getNoteWidth(MusicalNote note) {
  // Check if there's a specific width for this unicode character
  if (unicodeCharacterWidths.containsKey(note.unicodeCharacter)) {
    return unicodeCharacterWidths[note.unicodeCharacter]!;
  }

  if (note.type == NoteType.keySignature) {
    return getKeySignatureWidth(note);
  }

  // Otherwise use the width based on note type
  return noteTypeWidths[note.type] ?? 20.0; // Default to 20.0 if type not found
}

/// Calculate the selected note based on tap position
int calculateInsertionIndex(
    double tapPositionX, List<MusicalNote> notes, double rowSpacing) {
  if (notes.isEmpty) {
    return 0;
  }

  double currentX = 80.0; // Starting X position

  for (int i = 0; i < notes.length; i++) {
    final note = notes[i];
    if (note.type != NoteType.space) {
      final noteWidth = getNoteWidth(note);

      if (note.type == NoteType.keySignature) {
        if (tapPositionX > currentX && tapPositionX < currentX + noteWidth) {
          return i;
        }
      } else {
        double halfRowSpacing = rowSpacing / 2;

        if (tapPositionX > currentX - halfRowSpacing &&
            tapPositionX < currentX + halfRowSpacing) {
          return i;
        }
      }

      currentX +=
          note.type == NoteType.clef || note.type == NoteType.keySignature
              ? noteWidth
              : rowSpacing;
    }
  }

  return notes.length - 1;
}

/// Calculate the X position for a given index in the row
double calculateXPositionForIndex(
    int index, List<MusicalNote> notes, double rowSpacing) {
  double x = 80.0; // Starting X position

  for (int i = 0; i < index && i < notes.length; i++) {
    final note = notes[i];
    if (note.type != NoteType.space) {
      x += note.type == NoteType.clef || note.type == NoteType.keySignature
          ? getNoteWidth(note)
          : rowSpacing;
    }
  }

  return x;
}

/// Calculate the width needed for a key signature
double getKeySignatureWidth(MusicalNote note) {
  final keySignatureName = note.keySignatureName;
  if (keySignatureName.isEmpty) return 20.0;

  // Map key signature names to their symbol counts
  final Map<String, int> symbolCounts = {
    'G/Em': 1,
    'D/Bm': 2,
    'A/F#m': 3,
    'E/C#m': 4,
    'B/G#m': 5,
    'F#/D#m': 6,
    'C#/A#m': 7,
    'F/Dm': 1,
    'Bb/Gm': 2,
    'Eb/Cm': 3,
    'Ab/Fm': 4,
    'Db/Bbm': 5,
    'Gb/Ebm': 6,
    'Cb/Abm': 7,
  };

  final int symbolCount = symbolCounts[keySignatureName] ?? 1;
  const double symbolSpacing = 12.0;
  const double baseWidth = 10.0;

  return baseWidth + (symbolCount * symbolSpacing);
}
//next sort out cursor and row length
