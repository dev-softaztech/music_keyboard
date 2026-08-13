import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/models/keyboard_type.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
import 'package:music_keyboard/src/widgets/keyboard/guitar_keyboard_widgets/guitar_keyboard_layout.dart';
import 'package:music_keyboard/src/widgets/keyboard/sheet_keyboard_widgets/notes_keyboard_layout.dart';

Widget buildKeyboardLayout({
  required Sheet sheet,
  required bool showNotesKeyboard,
  required void Function(bool isNotes) onToggleKeyboard,
  required bool Function(MusicalNote note) onKeyPress,
  required void Function(MusicalNote note) onAddToChord,
  required void Function(MusicalNote note) onRemoveFromChord,
  required void Function(MusicalNote note) onConvertToChord,
  required SheetDatabaseHelper dbHelper,
  required void Function(MusicalNote chord) onFavouriteChordTapped,
  required int favouritesVersion,
  required void Function(VoidCallback handler) onRegisterSpaceHandler,
  required void Function(VoidCallback handler) onRegisterResetHandler,
  required VoidCallback onNewRowCreated,
}) {
  switch (sheet.keyboardType) {
    case KeyboardType.sheet:
    case KeyboardType.drumTab:
      return NotesKeyboardLayout(
        sheetNoteRows: sheet.sheetRows,
        showNotesKeyboard: showNotesKeyboard,
        sheetFormat: sheet.format,
        onToggleKeyboard: onToggleKeyboard,
        onKeyPress: onKeyPress,
        onAddToChord: onAddToChord,
        onRemoveFromChord: onRemoveFromChord,
        onConvertToChord: onConvertToChord,
        loadFavourites: dbHelper.getAllFavouriteChords,
        onFavouriteChordTapped: onFavouriteChordTapped,
        onFavouriteChordUsed: dbHelper.touchFavouriteChord,
        favouritesVersion: favouritesVersion,
      );

    case KeyboardType.guitarTab:
      return GuitarKeyboardLayout(
        sheetNoteRows: sheet.sheetRows,
        showNotesKeyboard: showNotesKeyboard,
        sheetFormat: sheet.format,
        onToggleKeyboard: onToggleKeyboard,
        onKeyPress: onKeyPress,
        onRegisterSpaceHandler: onRegisterSpaceHandler,
        onRegisterResetHandler: onRegisterResetHandler,
        onNewRowCreated: onNewRowCreated,
        loadFavourites: () =>
            dbHelper.getFavouriteChordsByKeyboardType('guitarTab'),
        onFavouriteChordTapped: onFavouriteChordTapped,
        onFavouriteChordUsed: dbHelper.touchFavouriteChord,
        favouritesVersion: favouritesVersion,
      );
  }
}
