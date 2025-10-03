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
  NoteType.accidental: 20.0,
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

  // Otherwise use the width based on note type
  return noteTypeWidths[note.type] ?? 20.0; // Default to 20.0 if type not found
}

/// Calculate the insertion index based on tap position
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

      // Calculate the center position of this note
      //double noteCenter = currentX + (noteWidth / 2);
      double halfRowSpacing = rowSpacing / 2;

      // If tap is before the center of this note, insert before it
      if (tapPositionX > currentX - halfRowSpacing &&
          tapPositionX < currentX + halfRowSpacing) {
        return i;
      }

      // Move to next note position
      currentX += note.type == NoteType.clef ? noteWidth : rowSpacing;
    }
  }

  // If we get here, insert at the end
  return notes.length;
}

/// Calculate the X position for a given index in the row
double calculateXPositionForIndex(
    int index, List<MusicalNote> notes, double rowSpacing) {
  double x = 80.0; // Starting X position

  for (int i = 0; i < index && i < notes.length; i++) {
    final note = notes[i];
    if (note.type != NoteType.space) {
      x += note.type == NoteType.clef ? getNoteWidth(note) : rowSpacing;
    }
  }

  return x;
}
