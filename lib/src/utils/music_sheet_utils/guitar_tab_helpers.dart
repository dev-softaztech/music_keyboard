import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';

class GuitarTabHelpers {
  // String names in order from top to bottom
  static final List<String> _stringNames = ['E', 'B', 'G', 'D', 'A', 'E'];

  /// Helper: Get current chord being edited
  static MusicalNote? getCurrentChord(
      List<SheetRows> sheetNoteRows, int selectedRow, int selectedNoteIndex) {
    if (sheetNoteRows.isEmpty) return null;
    if (selectedRow >= sheetNoteRows.length) return null;
    if (sheetNoteRows[selectedRow].chords.isEmpty) return null;
    if (selectedNoteIndex < 0 ||
        selectedNoteIndex >= sheetNoteRows[selectedRow].chords.length) {
      return null;
    }
    return sheetNoteRows[selectedRow].chords[selectedNoteIndex];
  }

  /// Helper: Get fret number for a specific string in current chord
  static String? getFretForString(MusicalNote? chord, int stringIndex) {
    if (chord?.childNotes == null) return null;

    for (var childNote in chord!.childNotes!) {
      if (childNote.octave == stringIndex) {
        return childNote.unicodeCharacter;
      }
    }
    return null;
  }

  /// Helper: Update fret for a specific string
  static MusicalNote updateFretForString(List<SheetRows> sheetNoteRows,
      int selectedRow, int selectedNoteIndex, int stringIndex, int fretNumber,
      {bool goToNextString = true}) {
    final chord =
        getCurrentChord(sheetNoteRows, selectedRow, selectedNoteIndex);

    if (chord == null) {
      // No chord exists at this position, cannot update
      return MusicalNote(pitch: "", octave: 0, type: NoteType.space);
    }

    // Initialize childNotes if null
    chord.childNotes ??= [];

    bool fretWasAdded = false;

    // Find existing childNote for this string or create new one
    bool found = false;
    for (int i = 0; i < chord.childNotes!.length; i++) {
      if (chord.childNotes![i].octave == stringIndex) {
        found = true;

        if (fretNumber.toString() == chord.childNotes![i].unicodeCharacter) {
          chord.childNotes!.removeAt(i);
          break;
        }

        chord.childNotes![i] = MusicalNote(
          pitch: _stringNames[stringIndex],
          octave: stringIndex,
          type: NoteType.fret,
          unicodeCharacter: fretNumber.toString(),
          duration: 0.0,
          isBendStart: chord.childNotes![i].isBendStart,
          isPreBendStart: chord.childNotes![i].isPreBendStart,
          isBendReleaseStart: chord.childNotes![i].isBendReleaseStart,
          isPreBendReleaseStart: chord.childNotes![i].isPreBendReleaseStart,
          bendEndIndex: chord.childNotes![i].bendEndIndex,
          preBendEndIndex: chord.childNotes![i].preBendEndIndex,
          bendReleaseEndIndex: chord.childNotes![i].bendReleaseEndIndex,
          preBendReleaseEndIndex: chord.childNotes![i].preBendReleaseEndIndex,
        );
        fretWasAdded = true;
        break;
      }
    }

    var newChildNote = MusicalNote(
      pitch: _stringNames[stringIndex],
      octave: stringIndex,
      type: NoteType.fret,
      unicodeCharacter: fretNumber == 0 ? "" : fretNumber.toString(),
      duration: 0.0,
    );

    if (!found) {
      chord.childNotes!.add(newChildNote);
      fretWasAdded = true;
    }

    return newChildNote;
  }
}
