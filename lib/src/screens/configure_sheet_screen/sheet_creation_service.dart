import 'package:music_keyboard/models/row_properties.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/models/sheet_properties.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/models/keyboard_type.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
import 'package:music_keyboard/src/services/firestore_service.dart';

class SheetCreationService {
  static Future<Sheet> createSheet({
    required SheetFormat format,
    required KeyboardType keyboardType,
    required String title,
    required String composer,
    required String? userId,
  }) async {
    // Create initial rows based on selected format
    List<SheetRows> initialRows = [];

    for (int i = 0; i < format.rowsPerGroup; i++) {
      final row = SheetRows(
        chords: [],
        rowProperties: RowProperties(tempoNumber: 0),
      );

      if (i < format.defaultClefsFor(keyboardType).length) {
        row.chords.add(MusicalNote(
          pitch: "G",
          octave: 4,
          type: NoteType.clef,
          isBeamed: false,
          unicodeCharacter: format.defaultClefsFor(keyboardType)[i],
          clefType: format.defaultClefsFor(keyboardType)[i],
        ));
      }

      if (keyboardType == KeyboardType.guitarTab) {
        row.chords.add(MusicalNote(
          pitch: 'G',
          octave: 4,
          type: NoteType.fret,
          duration: 0.0,
          childNotes: [],
        ));
      }

      initialRows.add(row);
    }

    final sheetProperties = SheetProperties(
      title: title.trim().isEmpty ? 'Untitled' : title.trim(),
      composer: composer.trim(),
    );

    final initialSheet = Sheet(
      sheetRows: initialRows,
      sheetProperties: sheetProperties,
      format: format,
      keyboardType: keyboardType,
    );

    final dbHelper = SheetDatabaseHelper(userId: userId);
    await dbHelper.insertSheet(initialSheet);

    if (initialSheet.id == null) {
      throw Exception('Sheet was inserted but no ID was assigned');
    }

    if (userId != null) {
      await FirestoreService().addSheet(initialSheet, userId);
    }

    return initialSheet;
  }
}
