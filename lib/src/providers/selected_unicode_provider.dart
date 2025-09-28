import 'package:flutter/material.dart';
import 'package:music_keyboard/models/note_unicode_characters.dart';

class SelectedUnicodeProvider extends ChangeNotifier {
  NoteUnicodeCharacters _selectedCharacter = NoteUnicodeCharacters(
      normal: '\ue1d2', upsideDown: '\ue1d2'); // Default Unicode character

  NoteUnicodeCharacters get selectedCharacter => _selectedCharacter;

  void updateSelectedCharacter(NoteUnicodeCharacters character) {
    _selectedCharacter = character;
    notifyListeners(); // Notify listeners about the change
  }
}
