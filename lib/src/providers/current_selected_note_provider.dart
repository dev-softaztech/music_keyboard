import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/bar_line_calculator.dart';

class CurrentSelectedNoteProvider extends ChangeNotifier {
  int selectedRow = 0;
  int insertionIndex = 0;
  int selectedIndex = 0;
  bool isBeaming = false;
  bool isSlurring = false;

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
  void addNote(MusicalNote note, List<SheetRows> sheetNoteRows) {
    if (note.type == NoteType.space &&
        sheetNoteRows[selectedRow].notes.isNotEmpty &&
        sheetNoteRows[selectedRow].notes[selectedIndex].type ==
            NoteType.space) {
      return;
    }

    //saveState(sheetNoteRows);

    // Insert the note at the current insertion point
    if (insertionIndex <= sheetNoteRows[selectedRow].notes.length) {
      sheetNoteRows[selectedRow].notes.insert(insertionIndex, note);

      // Adjust indices for dynamics
      for (var n in sheetNoteRows[selectedRow].notes) {
        if (n.crescendoEndIndex != null &&
            n.crescendoEndIndex! >= selectedIndex) {
          n.crescendoEndIndex = n.crescendoEndIndex! + 1;
        }
        if (n.decrescendoEndIndex != null &&
            n.decrescendoEndIndex! >= selectedIndex) {
          n.decrescendoEndIndex = n.decrescendoEndIndex! + 1;
        }
      }

      adjustSlurIndicesForSpaceNote(
          note, sheetNoteRows[selectedRow].notes, insertionIndex, true);

      // Set duration for the new note
      note.duration = BarLineCalculator.noteDurations[note.type] ?? 0.0;

      if (sheetNoteRows[selectedRow].notes[insertionIndex].type ==
              NoteType.space &&
          sheetNoteRows[selectedRow].notes.length > insertionIndex) {
        selectedIndex = selectedIndex + 2;
        insertionIndex = insertionIndex + 2;
      } else {
        selectedIndex++;
        insertionIndex++;
      }

      // Check if we need to add automatic bar lines
      if (_checkForBarLines && note.type != NoteType.bar) {
        _handleAutomaticBarLines(
            sheetNoteRows[selectedRow].notes, sheetNoteRows);
      }

      notifyListeners();
    }
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

  /// **Starts "Beam Notes" mode (first note is the selected note)**
  void enableBeaming() {
    isBeaming = true;
    notifyListeners();
  }

  /// **Handles "Beam Notes" when second note is tapped**
  void handleBeamSelection(int row, int index, List<SheetRows> sheetNoteRows) {
    //saveState(sheetNoteRows); // Save for undo

    int startRow = selectedRow;
    int startIndex = insertionIndex;
    int endRow = row;
    int endIndex = index;

    // Ensure selection is left-to-right
    if (startRow > endRow || (startRow == endRow && startIndex > endIndex)) {
      int tempRow = startRow;
      int tempIndex = startIndex;
      startRow = endRow;
      startIndex = endIndex;
      endRow = tempRow;
      endIndex = tempIndex;
    }

    // Apply beaming to all notes in the range
    for (int r = startRow; r <= endRow; r++) {
      for (int i = (r == startRow ? startIndex : 0);
          i < (r == endRow ? endIndex : sheetNoteRows[r].notes.length - 1);
          i++) {
        sheetNoteRows[r].notes[i].isBeamed = true;
      }
    }

    // Exit beaming mode
    isBeaming = false;
    notifyListeners();
  }

  void beamNotes(
      int row, int startIndex, int endIndex, List<SheetRows> sheetNoteRows) {
    //saveState(sheetNoteRows); // Save for undo

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

  /// **Starts "Tie Notes" mode (first note is the selected note)**
  void enableSlurring() {
    isSlurring = true;
    notifyListeners();
  }

  void handleSlurSelection(int row, int index, List<SheetRows> sheetNoteRows) {
    //saveState(sheetNoteRows);

    int startRow = selectedRow;
    int startIndex = insertionIndex;
    int endRow = row;
    int endIndex = index - 1;

    if (startRow != endRow) {
      isSlurring = false;
      return;
    }

    if (startIndex > endIndex) {
      int tempIndex = startIndex;
      startIndex = endIndex;
      endIndex = tempIndex;
    }

    MusicalNote firstNote = sheetNoteRows[startRow].notes[startIndex];

    if (sheetNoteRows[startRow].notes.length < endIndex) {
      endIndex = sheetNoteRows[startRow].notes.length - 1;
    }

    firstNote.slurEndIndex = endIndex;

    isSlurring = false;
    notifyListeners();
  }

  void slurNotes(
      int row, int startIndex, int endIndex, List<SheetRows> sheetNoteRows) {
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

  void crescendoNotes(
      int row, int startIndex, int endIndex, List<SheetRows> sheetNoteRows) {
    //saveState(sheetNoteRows); // Save for undo

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

  void decrescendoNotes(
      int row, int startIndex, int endIndex, List<SheetRows> sheetNoteRows) {
    //saveState(sheetNoteRows); // Save for undo

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

  /// **Switch beam rotation for the selected beamed group**
  void switchBeamRotation(List<SheetRows> sheetNoteRows) {
    //saveState(sheetNoteRows); // Save for undo

    final row = selectedRow;
    final index = selectedIndex;

    if (index >= 0 && index < sheetNoteRows[row].notes.length) {
      final selectedNote = sheetNoteRows[row].notes[index];

      if (selectedNote.isBeamed) {
        // Get all notes in the beamed group
        List<int> groupIndices =
            getBeamedGroupIndices(index, sheetNoteRows[row].notes);

        if (groupIndices.isNotEmpty) {
          // Get the first note in the group to manage the beam direction
          final firstNote = sheetNoteRows[row].notes[groupIndices.first];

          // Cycle through beam direction states: null -> true -> false -> null
          if (firstNote.beamDirectionLocked == null) {
            // Currently auto, set to force up (true)
            firstNote.beamDirectionLocked = true;
          } else if (firstNote.beamDirectionLocked == true) {
            // Currently force up, set to force down (false)
            firstNote.beamDirectionLocked = false;
          } else {
            // Currently force down, set back to auto (null)
            firstNote.beamDirectionLocked = null;
          }
        }
      }
    }

    notifyListeners();
  }
/*
  /// **Saves the current state for undo**
  void saveState(List<SheetRows> sheetNoteRows) {
    List<SheetRows> deepCopy = sheetNoteRows
        .map((row) => row.map((note) => note.copy()).toList())
        .toList();
    _history.add(deepCopy);
  }

  /// **Undo the last change**
  void undo(List<SheetRows> sheetNoteRows) {
    if (_history.isNotEmpty) {
      List<SheetRows> lastState = _history.removeLast();
      for (int i = 0; i < sheetNoteRows.length; i++) {
        for (int j = 0; j < sheetNoteRows[i].length - 1; j++) {
          sheetNoteRows[i][j] = lastState[i][j]; // Restore previous state
        }
      }
      notifyListeners();
    }
  }*/
}
