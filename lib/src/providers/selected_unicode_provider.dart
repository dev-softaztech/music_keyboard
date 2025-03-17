import 'package:flutter/material.dart';

class SelectedUnicodeProvider extends ChangeNotifier {
  String _selectedCharacter = '\ue1d2'; // Default Unicode character

  String get selectedCharacter => _selectedCharacter;

  void updateSelectedCharacter(String character) {
    _selectedCharacter = character;
    notifyListeners(); // Notify listeners about the change
  }
}
