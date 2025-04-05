import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';

class CurrentSelectedNoteProvider extends ChangeNotifier {
  int selectedRow = 0;
  int insertionIndex = 0;
  int selectedIndex = 0;
  bool isBeaming = false;
  bool isSlurring = false;

  final List<List<List<MusicalNote>>> _history = [];

  /// **Updates the cursor & highlights the selected note**
  void updateInsertionPoint(int row, int index) {
    selectedRow = row;
    insertionIndex = index;
    selectedIndex = insertionIndex == 0 ? 0 : insertionIndex - 1;
    notifyListeners();
  }

  /// **Starts "Beam Notes" mode (first note is the selected note)**
  void enableBeaming() {
    isBeaming = true;
    notifyListeners();
  }

  /// **Handles "Beam Notes" when second note is tapped**
  void handleBeamSelection(
      int row, int index, List<List<MusicalNote>> sheetNoteRows) {
    _saveState(sheetNoteRows); // Save for undo

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
          i <= (r == endRow ? endIndex : sheetNoteRows[r].length - 1);
          i++) {
        sheetNoteRows[r][i].isConnected = true;
      }
    }

    // Exit beaming mode
    isBeaming = false;
    notifyListeners();
  }

  /// **Starts "Tie Notes" mode (first note is the selected note)**
  void enableSlurring() {
    isSlurring = true;
    notifyListeners();
  }

  void handleSlurSelection(
      int row, int index, List<List<MusicalNote>> sheetNoteRows) {
    _saveState(sheetNoteRows);

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

  /// **Saves the current state for undo**
  void _saveState(List<List<MusicalNote>> sheetNoteRows) {
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
        for (int j = 0; j < sheetNoteRows[i].length; j++) {
          sheetNoteRows[i][j] = lastState[i][j]; // Restore previous state
        }
      }
      notifyListeners();
    }
  }
}
