import 'package:flutter/material.dart';

class SelectedStringProvider extends ChangeNotifier {
  // Currently selected string (0-5 for E, B, G, D, A, E from top to bottom)
  int _selectedStringIndex = 0;

  // String names in order from top to bottom
  final List<String> _stringNames = ['E', 'B', 'G', 'D', 'A', 'E'];

  int get selectedStringIndex => _selectedStringIndex;
  List<String> get stringNames => _stringNames;

  void setSelectedStringIndex(int index) {
    if (index >= 0 && index < _stringNames.length) {
      _selectedStringIndex = index;
      notifyListeners();
    }
  }

  String getSelectedStringName() {
    return _stringNames[_selectedStringIndex];
  }

  // Reset to default string (top E string)
  void resetToDefault() {
    _selectedStringIndex = 0;
    notifyListeners();
  }
}
