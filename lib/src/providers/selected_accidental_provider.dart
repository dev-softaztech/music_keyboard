import 'package:flutter/material.dart';

class SelectedAccidentalProvider extends ChangeNotifier {
  String _selectedAccidental = ''; // No default accidental

  String get selectedAccidental => _selectedAccidental;

  void updateSelectedAccidental(String accidental) {
    _selectedAccidental = accidental;
    notifyListeners(); // Notify listeners about the change
  }
}
