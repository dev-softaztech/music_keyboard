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
    double tapPositionX, List<MusicalNote> notes, double rowSpacing,
    {double startingX = 85.0}) {
  if (notes.isEmpty) {
    return 0;
  }

  double currentX = startingX; // Starting X position
  double halfRowSpacing = rowSpacing / 2;

  for (int i = 0; i < notes.length; i++) {
    final note = notes[i];

    if (i == 0 && tapPositionX < (currentX - halfRowSpacing)) {
      return -1;
    }

    // Calculate spacing for space notes
    double spaceNoteSpacing = 0;
    if (note.type == NoteType.space && i > 0) {
      // Check if previous note is also a space note
      bool prevIsSpace = notes[i - 1].type == NoteType.space;
      // First space note in sequence: no spacing, subsequent: full spacing
      spaceNoteSpacing = prevIsSpace ? rowSpacing : 0;
    }

    if (note.type != NoteType.space) {
      final noteWidth = getNoteWidth(note);

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
    } else {
      // Handle space note tap detection
      if (spaceNoteSpacing > 0) {
        // For subsequent space notes with spacing, check if tap is in their range
        if (tapPositionX > currentX - halfRowSpacing &&
            tapPositionX < currentX + halfRowSpacing) {
          return i;
        }
      }
      currentX += spaceNoteSpacing;
    }
  }

  return notes.length - 1;
}

/// Calculate the X position for a given index in the row
double calculateXPositionForIndex(int index, List<MusicalNote> notes,
    double rowSpacing, bool isNoteStartXForHighlight,
    {double startingX = 85.0}) {
  double x = startingX;

  if (index == -1) {
    return 70;
  }

  for (int i = 0; i < index && i < notes.length; i++) {
    final note = notes[i];

    // Calculate spacing for space notes
    double spaceNoteSpacing = 0;
    if (note.type == NoteType.space && i > 0) {
      // Check if previous note is also a space note
      bool prevIsSpace = notes[i - 1].type == NoteType.space;
      // First space note in sequence: no spacing, subsequent: full spacing
      spaceNoteSpacing = prevIsSpace ? rowSpacing : 0;
    }

    if (note.type != NoteType.space) {
      x += note.type == NoteType.clef || note.type == NoteType.timeSignature
          ? getNoteWidth(note)
          : note.type == NoteType.keySignature
              ? getNoteWidth(note) + 10
              : rowSpacing;
    } else {
      x += spaceNoteSpacing;
    }
  }

  if (index != -1 &&
      index < notes.length &&
      !isNoteStartXForHighlight &&
      notes[index].type == NoteType.keySignature) {
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
