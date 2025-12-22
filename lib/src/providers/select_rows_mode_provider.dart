import 'package:flutter/material.dart';

/// Provider to manage the "Select Rows" mode state
class SelectRowsModeProvider extends ChangeNotifier {
  bool _isSelectRowsMode = false;
  final Set<int> _selectedRows = {};

  bool get isSelectRowsMode => _isSelectRowsMode;
  Set<int> get selectedRows => Set.from(_selectedRows);
  int get selectedRowCount => _selectedRows.length;

  /// Enter select rows mode
  void enterSelectRowsMode() {
    _isSelectRowsMode = true;
    _selectedRows.clear();
    notifyListeners();
  }

  /// Exit select rows mode and clear selections
  void exitSelectRowsMode() {
    _isSelectRowsMode = false;
    _selectedRows.clear();
    notifyListeners();
  }

  /// Toggle selection of a specific row
  void toggleRowSelection(int rowIndex) {
    if (_selectedRows.contains(rowIndex)) {
      _selectedRows.remove(rowIndex);
    } else {
      _selectedRows.add(rowIndex);
    }
    notifyListeners();
  }

  /// Check if a specific row is selected
  bool isRowSelected(int rowIndex) {
    return _selectedRows.contains(rowIndex);
  }

  /// Clear all selections without exiting mode
  void clearSelections() {
    _selectedRows.clear();
    notifyListeners();
  }

  /// Get contiguous row groups from selected rows
  /// Returns a list of row range pairs [startRow, endRow]
  List<List<int>> getContiguousGroups() {
    if (_selectedRows.isEmpty) return [];

    final sortedRows = _selectedRows.toList()..sort();
    final List<List<int>> groups = [];

    int groupStart = sortedRows[0];
    int groupEnd = sortedRows[0];

    for (int i = 1; i < sortedRows.length; i++) {
      if (sortedRows[i] == groupEnd + 1) {
        // Contiguous, extend the current group
        groupEnd = sortedRows[i];
      } else {
        // Gap found, save current group and start new one
        groups.add([groupStart, groupEnd]);
        groupStart = sortedRows[i];
        groupEnd = sortedRows[i];
      }
    }

    // Add the last group
    groups.add([groupStart, groupEnd]);

    return groups;
  }
}
