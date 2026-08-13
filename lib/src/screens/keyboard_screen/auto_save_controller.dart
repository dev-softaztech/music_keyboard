import 'dart:async';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
import 'package:music_keyboard/src/services/firestore_service.dart';

abstract class AutoSaveHost {
  Sheet get sheet;
  SheetDatabaseHelper get dbHelper;
  FirestoreService get firestoreService;
  String? get syncUserId;
}

class AutoSaveController {
  AutoSaveController({required this.host});

  final AutoSaveHost host;

  bool hasUnsavedChanges = false;
  Timer? _autoSaveTimer;

  void markAsChanged() {
    hasUnsavedChanges = true;
  }

  Future<void> saveSheetToDatabase() async {
    if (!hasUnsavedChanges || host.sheet.id == null) return;

    try {
      print('DEBUG: Saving sheet with id ${host.sheet.id}');
      print('DEBUG: Sheet has ${host.sheet.sheetRows.length} rows');
      if (host.sheet.sheetRows.isNotEmpty) {
        print(
            'DEBUG: First row has ${host.sheet.sheetRows[0].chords.length} notes');
      }
      await host.dbHelper.updateSheet(host.sheet);
      if (host.syncUserId != null) {
        await host.firestoreService.updateSheet(host.sheet, host.syncUserId!);
      }
      hasUnsavedChanges = false;
      print('DEBUG: Sheet saved successfully');
    } catch (e) {
      print('Error saving sheet to database: $e');
    }
  }

  void initializeAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      saveSheetToDatabase();
    });
  }

  void dispose() {
    _autoSaveTimer?.cancel();
  }
}
