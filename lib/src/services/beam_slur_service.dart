import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/src/providers/undo_manager.dart';
import 'package:provider/provider.dart';

/// Beam, slur, crescendo and decrescendo mutators.
///
/// Stateless — operates on the [sheetNoteRows] passed in. Callers (the
/// selected-note provider) are responsible for calling `notifyListeners()`
/// after invoking these.
class BeamSlurService {
  static void beamNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    // Ensure selection is left-to-right
    if (startIndex > endIndex) {
      int tempIndex = startIndex;
      startIndex = endIndex;
      endIndex = tempIndex;
    }

    // Apply beaming to all notes in the range
    for (int i = startIndex; i <= endIndex; i++) {
      sheetNoteRows[row].chords[i].isBeamed = true;
    }
  }

  static void slurNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    //saveState(sheetNoteRows); // Save for undo

    // Ensure selection is left-to-right
    if (startIndex > endIndex) {
      int tempIndex = startIndex;
      startIndex = endIndex;
      endIndex = tempIndex;
    }

    MusicalNote firstNote = sheetNoteRows[row].chords[startIndex];
    firstNote.slurEndIndex = endIndex;
  }

  static void crescendoNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    if (startIndex > endIndex) {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
    }

    // Remove any overlapping dynamics
    for (int i = 0; i < sheetNoteRows[row].chords.length; i++) {
      final note = sheetNoteRows[row].chords[i];
      if (note.isCrescendoStart && note.crescendoEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.crescendoEndIndex! >= startIndex &&
                note.crescendoEndIndex! <= endIndex)) {
          note.isCrescendoStart = false;
          note.crescendoEndIndex = null;
        }
      }
      if (note.isDecrescendoStart && note.decrescendoEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.decrescendoEndIndex! >= startIndex &&
                note.decrescendoEndIndex! <= endIndex)) {
          note.isDecrescendoStart = false;
          note.decrescendoEndIndex = null;
        }
      }
    }

    MusicalNote firstNote = sheetNoteRows[row].chords[startIndex];
    firstNote.isCrescendoStart = true;
    firstNote.crescendoEndIndex = endIndex;
  }

  static void decrescendoNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    if (startIndex > endIndex) {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
    }

    // Remove any overlapping dynamics
    for (int i = 0; i < sheetNoteRows[row].chords.length; i++) {
      final note = sheetNoteRows[row].chords[i];
      if (note.isCrescendoStart && note.crescendoEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.crescendoEndIndex! >= startIndex &&
                note.crescendoEndIndex! <= endIndex)) {
          note.isCrescendoStart = false;
          note.crescendoEndIndex = null;
        }
      }
      if (note.isDecrescendoStart && note.decrescendoEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.decrescendoEndIndex! >= startIndex &&
                note.decrescendoEndIndex! <= endIndex)) {
          note.isDecrescendoStart = false;
          note.decrescendoEndIndex = null;
        }
      }
    }

    MusicalNote firstNote = sheetNoteRows[row].chords[startIndex];
    firstNote.isDecrescendoStart = true;
    firstNote.decrescendoEndIndex = endIndex;
  }

  /// **Get all notes in the same beamed group as the given note.**
  ///
  /// Recognises both regular beamable note types (eighth, sixteenth,
  /// thirtySecond, sixtyFourth) *and* [NoteType.chord] parents whose
  /// [MusicalNote.isBeamed] flag is true and whose [MusicalNote.childNotes]
  /// contain at least one beamable type.
  static List<int> getBeamedGroupIndices(
      int noteIndex, List<MusicalNote> notes) {
    if (noteIndex < 0 ||
        noteIndex >= notes.length ||
        !notes[noteIndex].isBeamed) {
      return [];
    }

    // Returns true if a note is part of a beamed group (regular or chord).
    bool isBeamable(MusicalNote n) {
      if (!n.isBeamed) return false;
      if (n.type == NoteType.chord) {
        // A chord with isBeamed=true but no children yet (user set beam before
        // adding child notes) is still considered beamable so callers never
        // receive an empty list for a note whose isBeamed flag is true.
        final children = n.childNotes;
        if (children == null || children.isEmpty) return true;
        return children.any((c) =>
            c.type == NoteType.eighth ||
            c.type == NoteType.sixteenth ||
            c.type == NoteType.thirtySecond ||
            c.type == NoteType.sixtyFourth);
      }
      return n.type == NoteType.eighth ||
          n.type == NoteType.sixteenth ||
          n.type == NoteType.thirtySecond ||
          n.type == NoteType.sixtyFourth;
    }

    if (!isBeamable(notes[noteIndex])) return [];

    List<int> groupIndices = [noteIndex];

    // Traverse backwards to find connected beamed notes
    for (int i = noteIndex - 1; i >= 0; i--) {
      if (isBeamable(notes[i])) {
        groupIndices.insert(0, i);
      } else {
        break;
      }
    }

    // Traverse forwards to find connected beamed notes
    for (int i = noteIndex + 1; i < notes.length; i++) {
      if (isBeamable(notes[i])) {
        groupIndices.add(i);
      } else {
        break;
      }
    }

    return groupIndices;
  }

  static void switchBeamRotation(int selectedRow, int selectedIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    final row = selectedRow;
    final index = selectedIndex;

    if (index >= 0 && index < sheetNoteRows[row].chords.length) {
      final selectedNote = sheetNoteRows[row].chords[index];

      if (selectedNote.isBeamed) {
        List<int> groupIndices =
            getBeamedGroupIndices(index, sheetNoteRows[row].chords);

        if (groupIndices.isNotEmpty) {
          final firstNote = sheetNoteRows[row].chords[groupIndices.first];

          // Toggle — derive the new state from the current first-note value.
          final bool newState = firstNote.isUpsideDown != true;

          // Apply to every note in the group.  For chord parents, also apply
          // to all of their child notes so they stay visually consistent.
          for (final idx in groupIndices) {
            final note = sheetNoteRows[row].chords[idx];
            note.isUpsideDown = newState;
            if (note.type == NoteType.chord && note.childNotes != null) {
              for (var child in note.childNotes!) {
                child.isUpsideDown = newState;
              }
            }
          }
        }
      }
    }
  }
}
