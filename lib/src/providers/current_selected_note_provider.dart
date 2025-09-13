import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/bar_line_calculator.dart';

class CurrentSelectedNoteProvider extends ChangeNotifier {
  int selectedRow = 0;
  int insertionIndex = 0;
  int selectedIndex = 0;
  bool isBeaming = false;
  bool isSlurring = false;

  final List<List<List<MusicalNote>>> _history = [];

  // Track if we need to check for automatic bar line placement
  bool _checkForBarLines = false;

  /// **Updates the cursor & highlights the selected note**
  void updateInsertionPoint(int row, int index) {
    selectedRow = row;
    insertionIndex = index;
    selectedIndex = insertionIndex == 0 ? 0 : insertionIndex - 1;

    // Set flag to check for bar lines on next note addition
    _checkForBarLines = true;

    notifyListeners();
  }

  /// **Add a note to the sheet and handle automatic bar line placement**
  void addNote(MusicalNote note, List<List<MusicalNote>> sheetNoteRows) {
    //saveState(sheetNoteRows);

    // Insert the note at the current insertion point
    if (insertionIndex <= sheetNoteRows[selectedRow].length) {
      sheetNoteRows[selectedRow].insert(insertionIndex, note);

      // Adjust indices for dynamics
      for (var n in sheetNoteRows[selectedRow]) {
        if (n.crescendoEndIndex != null &&
            n.crescendoEndIndex! >= insertionIndex - 1) {
          n.crescendoEndIndex = n.crescendoEndIndex! + 1;
        }
        if (n.decrescendoEndIndex != null &&
            n.decrescendoEndIndex! >= insertionIndex - 1) {
          n.decrescendoEndIndex = n.decrescendoEndIndex! + 1;
        }
      }

      // Set duration for the new note
      note.duration = BarLineCalculator.noteDurations[note.type] ?? 0.0;

      // Update insertion point
      insertionIndex++;
      selectedIndex = insertionIndex - 1;

      // Check if we need to add automatic bar lines
      if (_checkForBarLines && note.type != NoteType.bar) {
        _handleAutomaticBarLines(sheetNoteRows[selectedRow], sheetNoteRows);
      }

      notifyListeners();
    }
  }

  /// **Handle automatic bar line placement based on time signature**
  void _handleAutomaticBarLines(List<MusicalNote> notes,
      [List<List<MusicalNote>>? allRows]) {
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
  void handleBeamSelection(
      int row, int index, List<List<MusicalNote>> sheetNoteRows) {
    //saveState(sheetNoteRows); // Save for undo

    int startRow = selectedRow;
    int startIndex = insertionIndex - 1;
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
          i < (r == endRow ? endIndex : sheetNoteRows[r].length - 1);
          i++) {
        sheetNoteRows[r][i].isBeamed = true;
      }
    }

    // Exit beaming mode
    isBeaming = false;
    notifyListeners();
  }

  void beamNotes(int row, int startIndex, int endIndex,
      List<List<MusicalNote>> sheetNoteRows) {
    //saveState(sheetNoteRows); // Save for undo

    // Ensure selection is left-to-right
    if (startIndex > endIndex) {
      int tempIndex = startIndex;
      startIndex = endIndex;
      endIndex = tempIndex;
    }

    // Apply beaming to all notes in the range
    for (int i = startIndex; i <= endIndex; i++) {
      sheetNoteRows[row][i].isBeamed = true;
    }

    notifyListeners();
  }

  /// **Starts "Tie Notes" mode (first note is the selected note)**
  void enableSlurring() {
    isSlurring = true;
    notifyListeners();
  }

  void handleSlurSelection(
      int row, int index, List<List<MusicalNote>> sheetNoteRows) {
    //saveState(sheetNoteRows);

    int startRow = selectedRow;
    int startIndex = insertionIndex == 0 ? insertionIndex : insertionIndex - 1;
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

    MusicalNote firstNote = sheetNoteRows[startRow][startIndex];

    if (sheetNoteRows[startRow].length < endIndex) {
      endIndex = sheetNoteRows[startRow].length - 1;
    }

    firstNote.slurEndIndex = endIndex;

    isSlurring = false;
    notifyListeners();
  }

  void slurNotes(int row, int startIndex, int endIndex,
      List<List<MusicalNote>> sheetNoteRows) {
    //saveState(sheetNoteRows); // Save for undo

    // Ensure selection is left-to-right
    if (startIndex > endIndex) {
      int tempIndex = startIndex;
      startIndex = endIndex;
      endIndex = tempIndex;
    }

    MusicalNote firstNote = sheetNoteRows[row][startIndex];
    firstNote.slurEndIndex = endIndex;

    notifyListeners();
  }

  void crescendoNotes(int row, int startIndex, int endIndex,
      List<List<MusicalNote>> sheetNoteRows) {
    //saveState(sheetNoteRows); // Save for undo

    if (startIndex > endIndex) {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
    }

    // Remove any overlapping dynamics
    for (int i = 0; i < sheetNoteRows[row].length; i++) {
      final note = sheetNoteRows[row][i];
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

    MusicalNote firstNote = sheetNoteRows[row][startIndex];
    firstNote.isCrescendoStart = true;
    firstNote.crescendoEndIndex = endIndex;

    notifyListeners();
  }

  void decrescendoNotes(int row, int startIndex, int endIndex,
      List<List<MusicalNote>> sheetNoteRows) {
    //saveState(sheetNoteRows); // Save for undo

    if (startIndex > endIndex) {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
    }

    // Remove any overlapping dynamics
    for (int i = 0; i < sheetNoteRows[row].length; i++) {
      final note = sheetNoteRows[row][i];
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

    MusicalNote firstNote = sheetNoteRows[row][startIndex];
    firstNote.isDecrescendoStart = true;
    firstNote.decrescendoEndIndex = endIndex;

    notifyListeners();
  }
/*
  /// **Saves the current state for undo**
  void saveState(List<List<MusicalNote>> sheetNoteRows) {
    List<List<MusicalNote>> deepCopy = sheetNoteRows
        .map((row) => row.map((note) => note.copy()).toList())
        .toList();
    _history.add(deepCopy);
  }

  /// **Undo the last change**
  void undo(List<List<MusicalNote>> sheetNoteRows) {
    if (_history.isNotEmpty) {
      List<List<MusicalNote>> lastState = _history.removeLast();
      for (int i = 0; i < sheetNoteRows.length; i++) {
        for (int j = 0; j < sheetNoteRows[i].length - 1; j++) {
          sheetNoteRows[i][j] = lastState[i][j]; // Restore previous state
        }
      }
      notifyListeners();
    }
  }*/
}
