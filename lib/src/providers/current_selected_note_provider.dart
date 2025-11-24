import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/bar_line_calculator.dart';
import 'package:music_keyboard/src/providers/undo_manager.dart';
import 'package:provider/provider.dart';

class CurrentSelectedNoteProvider extends ChangeNotifier {
  int selectedRow = 0;
  int insertionIndex = 0;
  int selectedIndex = -1;

  //final List<List<SheetRows>> _history = [];

  // Track if we need to check for automatic bar line placement
  bool _checkForBarLines = false;

  /// **Updates the cursor & highlights the selected note**
  void updateSelectedIndexAndInsertionPoint(int newRow, int newSelectedIndex) {
    selectedRow = newRow;
    selectedIndex = newSelectedIndex;
    insertionIndex = newSelectedIndex + 1;

    // Set flag to check for bar lines on next note addition
    _checkForBarLines = true;

    notifyListeners();
  }

  /// **Add a note to the sheet and handle automatic bar line placement**
  void addNote(
      MusicalNote note, List<SheetRows> sheetNoteRows, BuildContext context) {
    final notes = sheetNoteRows[selectedRow].notes;

    if (note.type == NoteType.space &&
        notes.isNotEmpty &&
        notes[selectedIndex].type == NoteType.space) {
      return;
    }

    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    notes.insert(insertionIndex, note);

    // Adjust indices for dynamics
    for (var n in notes) {
      if (n.crescendoEndIndex != null &&
          n.crescendoEndIndex! >= selectedIndex) {
        n.crescendoEndIndex = n.crescendoEndIndex! + 1;
      }
      if (n.decrescendoEndIndex != null &&
          n.decrescendoEndIndex! >= selectedIndex) {
        n.decrescendoEndIndex = n.decrescendoEndIndex! + 1;
      }
    }

    adjustSlurIndicesForSpaceNote(note, notes, insertionIndex, true);

    note.duration = BarLineCalculator.noteDurations[note.type] ?? 0.0;

    updateSelectedIndexAndInsertionPoint(selectedRow, selectedIndex + 1);

    if (_checkForBarLines && note.type != NoteType.bar) {
      _handleAutomaticBarLines(notes, sheetNoteRows);
    }

    notifyListeners();
  }

  void adjustSlurIndicesForSpaceNote(MusicalNote spaceNote,
      List<MusicalNote> notes, int spaceNoteIndex, bool isAdd) {
    if (spaceNote.type != NoteType.space) return;
    if (spaceNoteIndex < 0 || spaceNoteIndex > notes.length) return;

    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      if (note.slurEndIndex != null) {
        if (i < spaceNoteIndex && note.slurEndIndex! >= spaceNoteIndex) {
          if (isAdd) {
            if (note.slurEndIndex! > notes.length) {
              note.slurEndIndex = notes.length;
            }

            note.slurEndIndex = note.slurEndIndex! + 1;
          } else {
            if (note.slurEndIndex! <= 0) {
              note.slurEndIndex = 0;
            }

            note.slurEndIndex = note.slurEndIndex! - 1;
          }
        }
      }
    }
  }

  /// **Handle automatic bar line placement based on time signature**
  void _handleAutomaticBarLines(List<MusicalNote> notes,
      [List<SheetRows>? allRows]) {
    MusicalNote? timeSignature;

    // First check for time signatures within the current row
    timeSignature = BarLineCalculator.findLastTimeSignature(notes);

    // If no time signature found in current row and allRows is provided, check previous rows
    if (timeSignature == null && allRows != null) {
      int currentRowIndex = -1;

      // Find the current row index
      for (int i = 0; i < allRows.length; i++) {
        if (identical(allRows[i], notes)) {
          currentRowIndex = i;
          break;
        }
      }

      if (currentRowIndex > 0) {
        timeSignature = BarLineCalculator.findLastTimeSignatureAcrossRows(
            allRows, currentRowIndex - 1);
      }
    }

    // Only proceed if we have a time signature (either in this row or from previous rows)
    if (timeSignature != null ||
        notes.any((note) => note.type == NoteType.timeSignature)) {
      // Calculate positions for automatic bar lines
      // This method now handles multiple time signatures within a row
      List<int> barLinePositions =
          BarLineCalculator.calculateBarLinePositions(notes, timeSignature);

      // Add bar lines at calculated positions (in reverse order to maintain correct indices)
      for (int i = barLinePositions.length - 1; i >= 0; i--) {
        int position = barLinePositions[i];

        // Create a bar line note
        MusicalNote barLineNote = MusicalNote(
          pitch: "D",
          octave: 4,
          type: NoteType.bar,
          unicodeCharacter: '\ue030', // Standard bar line
        );

        // Insert the bar line at the calculated position
        if (position < notes.length) {
          notes.insert(position, barLineNote);

          // Adjust insertion point if the bar line was inserted before it
          if (position < insertionIndex) {
            insertionIndex++;
            selectedIndex = insertionIndex - 1;
          }
        }
      }
    }
  }

  void beamNotes(int row, int startIndex, int endIndex,
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
      sheetNoteRows[row].notes[i].isBeamed = true;
    }

    notifyListeners();
  }

  void slurNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    //saveState(sheetNoteRows); // Save for undo

    // Ensure selection is left-to-right
    if (startIndex > endIndex) {
      int tempIndex = startIndex;
      startIndex = endIndex;
      endIndex = tempIndex;
    }

    MusicalNote firstNote = sheetNoteRows[row].notes[startIndex];
    firstNote.slurEndIndex = endIndex;

    notifyListeners();
  }

  void crescendoNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    if (startIndex > endIndex) {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
    }

    // Remove any overlapping dynamics
    for (int i = 0; i < sheetNoteRows[row].notes.length; i++) {
      final note = sheetNoteRows[row].notes[i];
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

    MusicalNote firstNote = sheetNoteRows[row].notes[startIndex];
    firstNote.isCrescendoStart = true;
    firstNote.crescendoEndIndex = endIndex;

    notifyListeners();
  }

  void decrescendoNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    if (startIndex > endIndex) {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
    }

    // Remove any overlapping dynamics
    for (int i = 0; i < sheetNoteRows[row].notes.length; i++) {
      final note = sheetNoteRows[row].notes[i];
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

    MusicalNote firstNote = sheetNoteRows[row].notes[startIndex];
    firstNote.isDecrescendoStart = true;
    firstNote.decrescendoEndIndex = endIndex;

    notifyListeners();
  }

  /// **Get all notes in the same beamed group as the given note**
  List<int> getBeamedGroupIndices(int noteIndex, List<MusicalNote> notes) {
    if (noteIndex < 0 ||
        noteIndex >= notes.length ||
        !notes[noteIndex].isBeamed) {
      return [];
    }

    List<int> groupIndices = [noteIndex];

    // Traverse backwards to find connected beamed notes
    for (int i = noteIndex - 1; i >= 0; i--) {
      if (notes[i].isBeamed &&
          (notes[i].type == NoteType.eighth ||
              notes[i].type == NoteType.sixteenth ||
              notes[i].type == NoteType.thirtySecond ||
              notes[i].type == NoteType.sixtyFourth)) {
        groupIndices.insert(0, i);
      } else {
        break;
      }
    }

    // Traverse forwards to find connected beamed notes
    for (int i = noteIndex + 1; i < notes.length; i++) {
      if (notes[i].isBeamed &&
          (notes[i].type == NoteType.eighth ||
              notes[i].type == NoteType.sixteenth ||
              notes[i].type == NoteType.thirtySecond ||
              notes[i].type == NoteType.sixtyFourth)) {
        groupIndices.add(i);
      } else {
        break;
      }
    }

    return groupIndices;
  }

  void switchBeamRotation(List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    final row = selectedRow;
    final index = selectedIndex;

    if (index >= 0 && index < sheetNoteRows[row].notes.length) {
      final selectedNote = sheetNoteRows[row].notes[index];

      if (selectedNote.isBeamed) {
        List<int> groupIndices =
            getBeamedGroupIndices(index, sheetNoteRows[row].notes);

        if (groupIndices.isNotEmpty) {
          final firstNote = sheetNoteRows[row].notes[groupIndices.first];

          if (firstNote.isUpsideDown == true) {
            firstNote.isUpsideDown = false;
          } else {
            firstNote.isUpsideDown = true;
          }
        }
      }
    }

    notifyListeners();
  }
}
