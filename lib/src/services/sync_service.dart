import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
import 'package:music_keyboard/src/services/firestore_service.dart';

class SyncService {
  final SheetDatabaseHelper _dbHelper = SheetDatabaseHelper();
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> syncSheets(String userId) async {
    final localSheets = await _dbHelper.getAllSheets();
    final remoteSheets = await _firestoreService.getSheets(userId).first;

    for (final localSheet in localSheets) {
      final remoteSheet = remoteSheets.firstWhere(
        (sheet) => sheet.id == localSheet.id,
        orElse: () => Sheet(
          id: -1,
          sheetRows: [],
          sheetProperties: localSheet.sheetProperties,
          lastUpdated: DateTime.fromMicrosecondsSinceEpoch(0),
        ),
      );

      if (localSheet.lastUpdated.isAfter(remoteSheet.lastUpdated)) {
        await _firestoreService.addSheet(localSheet, userId);
      }
    }

    for (final remoteSheet in remoteSheets) {
      final localSheet = localSheets.firstWhere(
        (sheet) => sheet.id == remoteSheet.id,
        orElse: () => Sheet(
          id: -1,
          sheetRows: [],
          sheetProperties: remoteSheet.sheetProperties,
          lastUpdated: DateTime.fromMicrosecondsSinceEpoch(0),
        ),
      );

      if (remoteSheet.lastUpdated.isAfter(localSheet.lastUpdated)) {
        if (localSheet.id == -1) {
          await _dbHelper.insertSheet(remoteSheet);
        } else {
          await _dbHelper.updateSheet(remoteSheet);
        }
      }
    }
  }

  Future<void> uploadLocalSheetsOnLogin(String userId) async {
    final localSheets = await _dbHelper.getAllSheets();
    for (final sheet in localSheets) {
      sheet.userId = userId;
      await _firestoreService.addSheet(sheet, userId);
    }
  }
}
