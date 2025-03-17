import 'package:flutter/material.dart';

class SelectedNumberProvider with ChangeNotifier {
  int _selectedNumber = 4; // Default selection

  int get selectedNumber => _selectedNumber;

  void updateSelectedNumber(int value) {
    _selectedNumber = value;
    notifyListeners(); // Notify listeners of the change
  }
}
