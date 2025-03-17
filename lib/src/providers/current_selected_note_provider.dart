import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';

class CurrentSelectedNoteProvider extends ChangeNotifier {
  int selectedRow = 0;
  int selectedIndex = 0;
  bool isBeaming = false;
  int? firstBeamRow;
  int? firstBeamIndex;
  bool isTying = false; // ✅ New mode for tying notes
  int? firstTieRow;
  int? firstTieIndex;

  final List<List<List<MusicalNote>>> _history = [];

  void updateInsertionPoint(int row, int index) {
    selectedRow = row;
    selectedIndex = index;
    notifyListeners();
  }

  void enableBeaming() {
    isBeaming = true;
    firstBeamRow = null;
    firstBeamIndex = null;
    notifyListeners();
  }

  void handleBeamSelection(
      int row, int index, List<List<MusicalNote>> sheetNoteRows) {
    if (firstBeamRow == null) {
      // ✅ First note selected
      firstBeamRow = row;
      firstBeamIndex = index;
    } else {
      _saveState(sheetNoteRows);

      // ✅ Second note selected, beam all notes in between
      int startRow = firstBeamRow!;
      int startIndex = firstBeamIndex!;
      int endRow = row;
      int endIndex = index;

      // ✅ Ensure selection goes left to right
      if (startRow > endRow || (startRow == endRow && startIndex > endIndex)) {
        int tempRow = startRow;
        int tempIndex = startIndex;
        startRow = endRow;
        startIndex = endIndex;
        endRow = tempRow;
        endIndex = tempIndex;
      }

      // ✅ Apply beaming
      for (int r = startRow; r <= endRow; r++) {
        for (int i = (r == startRow ? startIndex : 0);
            i <= (r == endRow ? endIndex : sheetNoteRows[r].length - 1);
            i++) {
          sheetNoteRows[r][i].isConnected = true;
        }
      }

      // ✅ Reset beam mode
      isBeaming = false;
      firstBeamRow = null;
      firstBeamIndex = null;
      notifyListeners();
    }
  }

  void enableTying() {
    isTying = true;
    firstTieRow = null;
    firstTieIndex = null;
    notifyListeners();
  }

  void handleTieSelection(
      int row, int index, List<List<MusicalNote>> sheetNoteRows) {
    if (firstTieRow == null) {
      // ✅ First note selected
      firstTieRow = row;
      firstTieIndex = index;
    } else {
      // ✅ Second note selected, apply tie

      // ✅ Save current state before modifying (for undo)
      _saveState(sheetNoteRows);

      int startRow = firstTieRow!;
      int startIndex = firstTieIndex!;
      int endRow = row;
      int endIndex = index;

      // ✅ Ensure left-to-right selection
      if (startRow > endRow || (startRow == endRow && startIndex > endIndex)) {
        int tempRow = startRow;
        int tempIndex = startIndex;
        startRow = endRow;
        startIndex = endIndex;
        endRow = tempRow;
        endIndex = tempIndex;
      }

      // ✅ Check that both notes have the same pitch
      MusicalNote firstNote = sheetNoteRows[startRow][startIndex - 1];
      MusicalNote secondNote = sheetNoteRows[endRow][endIndex - 1];

      if (firstNote.pitch == secondNote.pitch) {
        firstNote.isTiedToNext = true;
      } //thi makes it so it only draws tie if second note is same pitch/vertical position

      // ✅ Reset tie mode
      isTying = false;
      firstTieRow = null;
      firstTieIndex = null;
      notifyListeners();
    }
  }

  void _saveState(List<List<MusicalNote>> sheetNoteRows) {
    List<List<MusicalNote>> deepCopy = sheetNoteRows
        .map((row) => row.map((note) => note.copy()).toList())
        .toList();

    _history.add(deepCopy);
  }

  // ✅ Undo the last change
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
