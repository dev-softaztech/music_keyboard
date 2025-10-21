import 'package:flutter/material.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/row_properties.dart';

class SheetUndoManager extends ChangeNotifier {
  final List<List<SheetRows>> _history = [];
  static const int maxHistorySize = 50;

  bool get canUndo => _history.isNotEmpty;

  /// Save the current state of sheetRows for undo functionality
  void saveState(List<SheetRows> sheetRows) {
    // Create a deep copy of the current state
    List<SheetRows> deepCopy = _deepCopySheetRows(sheetRows);

    // Add to history
    _history.add(deepCopy);

    // Limit history size
    if (_history.length > maxHistorySize) {
      _history.removeAt(0);
    }

    notifyListeners();
  }

  /// Undo the last change and return the previous state
  List<SheetRows>? undo() {
    if (_history.isEmpty) {
      return null;
    }

    // Get the last saved state
    List<SheetRows> lastState = _history.removeLast();
    notifyListeners();

    return lastState;
  }

  /// Clear all undo history
  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  /// Create a deep copy of the sheet rows
  List<SheetRows> _deepCopySheetRows(List<SheetRows> original) {
    return original.map((sheetRow) => _deepCopySheetRow(sheetRow)).toList();
  }

  /// Create a deep copy of a single sheet row
  SheetRows _deepCopySheetRow(SheetRows original) {
    return SheetRows(
      notes: original.notes.map((note) => note.copy()).toList(),
      rowProperties: _deepCopyRowProperties(original.rowProperties),
    );
  }

  /// Create a deep copy of row properties
  RowProperties _deepCopyRowProperties(RowProperties original) {
    return RowProperties(
      tempoNumber: original.tempoNumber,
      swing: original.swing,
      swingText: original.swingText,
    );
  }
}
