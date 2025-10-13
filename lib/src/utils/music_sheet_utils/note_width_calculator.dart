import 'package:music_keyboard/models/music_note.dart';

/// Get the width of a note based on its type and unicode character
double getNoteWidth(MusicalNote note) {
  // Check if there's a specific width for this unicode character
  if (note.type == NoteType.clef || note.type == NoteType.timeSignature) {
    return 30.0;
  }

  if (note.type == NoteType.keySignature) {
    return getKeySignatureWidth(note);
  }

  return 20.0;
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

      double halfRowSpacing = rowSpacing / 2;

      if (note.type == NoteType.keySignature) {
        if (tapPositionX > currentX - halfRowSpacing &&
            tapPositionX < currentX + noteWidth) {
          return i;
        }
      } else {
        if (tapPositionX > currentX - halfRowSpacing &&
            tapPositionX < currentX + halfRowSpacing) {
          return i;
        }
      }

      currentX +=
          note.type == NoteType.clef || note.type == NoteType.timeSignature
              ? noteWidth
              : note.type == NoteType.keySignature
                  ? noteWidth + 10
                  : rowSpacing;
    }
  }

  return notes.length - 1;
}

/// Calculate the X position for a given index in the row
double calculateXPositionForIndex(int index, List<MusicalNote> notes,
    double rowSpacing, bool isNoteStartXForHighlight) {
  double x = 80.0; // Starting X position

  for (int i = 0; i < index && i < notes.length; i++) {
    final note = notes[i];
    if (note.type != NoteType.space) {
      x += note.type == NoteType.clef || note.type == NoteType.timeSignature
          ? getNoteWidth(note)
          : note.type == NoteType.keySignature
              ? getNoteWidth(note) + 10
              : rowSpacing;
    }
  }

  if (!isNoteStartXForHighlight && notes[index].type == NoteType.keySignature) {
    x += getNoteWidth(notes[index]);
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

  return (symbolCount * symbolSpacing) + 10;
}
