import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
import 'package:music_keyboard/src/services/firestore_service.dart';

class SyncService {
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> syncSheets(String userId) async {
    try {
      print('=== Starting sync for user: $userId ===');

      // Create database helper with userId context
      final _dbHelper = SheetDatabaseHelper(userId: userId);

      // Get local sheets, remote sheets, and deleted sheet IDs
      final localSheets = await _dbHelper.getAllSheets();
      print('Local sheets: ${localSheets.length}');
      if (localSheets.isNotEmpty) {
        print('Local sheet IDs: ${localSheets.map((s) => s.id).toList()}');
      }

      // Use getSheetsOnce for reliable server fetch
      final remoteSheets = await _firestoreService.getSheetsOnce(userId);
      print('Remote sheets: ${remoteSheets.length}');
      if (remoteSheets.isNotEmpty) {
        print('Remote sheet IDs: ${remoteSheets.map((s) => s.id).toList()}');
      }

      final deletedIds = await _firestoreService.getDeletedSheetIds(userId);
      print('Deleted sheet IDs: ${deletedIds.length}');
      if (deletedIds.isNotEmpty) {
        print('Deleted IDs: $deletedIds');
      }

      print(
          'Syncing: ${localSheets.length} local, ${remoteSheets.length} remote, ${deletedIds.length} deleted');

      // Step 1: Remove locally any sheets that were deleted remotely
      for (final localSheet in localSheets) {
        if (localSheet.id != null && deletedIds.contains(localSheet.id)) {
          print('Removing locally deleted sheet: ${localSheet.id}');
          await _dbHelper.deleteSheet(localSheet.id!);
        }
      }

      // Refresh local sheets list after deletions
      final updatedLocalSheets = await _dbHelper.getAllSheets();

      // Step 2: Upload local sheets that aren't in the deleted list
      for (final localSheet in updatedLocalSheets) {
        if (localSheet.id == null) continue;

        // Skip if this sheet was deleted remotely
        if (deletedIds.contains(localSheet.id)) {
          continue;
        }

        final remoteSheet = remoteSheets.firstWhere(
          (sheet) => sheet.id == localSheet.id,
          orElse: () => Sheet(
            id: null,
            sheetRows: [],
            sheetProperties: localSheet.sheetProperties,
            lastUpdated: DateTime.fromMicrosecondsSinceEpoch(0),
          ),
        );

        if (remoteSheet.id == null) {
          // New local sheet, upload to Firebase
          print('Uploading new local sheet: ${localSheet.id}');
          await _firestoreService.addSheet(localSheet, userId);
        } else if (localSheet.lastUpdated.isAfter(remoteSheet.lastUpdated)) {
          // Local is newer, update Firebase
          print('Updating remote sheet (local newer): ${localSheet.id}');
          await _firestoreService.updateSheet(localSheet, userId);
        }
      }

      // Step 3: Download remote sheets that aren't in the deleted list
      for (final remoteSheet in remoteSheets) {
        if (remoteSheet.id == null) continue;

        // Skip if this sheet is in the deleted list
        if (deletedIds.contains(remoteSheet.id)) {
          continue;
        }

        final localSheet = updatedLocalSheets.firstWhere(
          (sheet) => sheet.id == remoteSheet.id,
          orElse: () => Sheet(
            id: null,
            sheetRows: [],
            sheetProperties: remoteSheet.sheetProperties,
            lastUpdated: DateTime.fromMicrosecondsSinceEpoch(0),
          ),
        );

        if (localSheet.id == null) {
          // New remote sheet, use upsert to safely add it
          print('SyncService: Adding new remote sheet: ${remoteSheet.id}');
          await _dbHelper.upsertSheet(remoteSheet);
        } else if (remoteSheet.lastUpdated.isAfter(localSheet.lastUpdated)) {
          // Remote is newer, update local
          print(
              'SyncService: Updating local sheet (remote newer): ${remoteSheet.id}');
          await _dbHelper.updateSheet(remoteSheet);
        } else {
          print('SyncService: Sheet ${remoteSheet.id} is up to date');
        }
      }

      // Step 4: Cleanup old deletion records (older than 90 days)
      await _firestoreService.cleanupOldDeletions(userId);

      print('Sync completed');
    } catch (e) {
      print('Error during sync: $e');
      // Don't rethrow - sync failures shouldn't prevent app functionality
      // The user can continue using the app normally
    }
  }

  Future<void> uploadLocalSheetsOnLogin(String userId) async {
    final _dbHelper = SheetDatabaseHelper(userId: userId);
    final localSheets = await _dbHelper.getAllSheets();
    for (final sheet in localSheets) {
      sheet.userId = userId;
      await _firestoreService.addSheet(sheet, userId);
    }
  }

  /// Check if there are any local sheets that haven't been synced to Firebase
  Future<bool> hasUnsyncedSheets(String userId) async {
    try {
      final _dbHelper = SheetDatabaseHelper(userId: userId);
      final localSheets = await _dbHelper.getAllSheets();

      if (localSheets.isEmpty) return false;

      final remoteSheets = await _firestoreService.getSheetsOnce(userId);

      // Check if any local sheet is missing from remote or newer than remote
      for (final localSheet in localSheets) {
        if (localSheet.id == null) continue;

        final remoteSheet = remoteSheets.firstWhere(
          (sheet) => sheet.id == localSheet.id,
          orElse: () => Sheet(
            id: null,
            sheetRows: [],
            sheetProperties: localSheet.sheetProperties,
            lastUpdated: DateTime.fromMicrosecondsSinceEpoch(0),
          ),
        );

        if (remoteSheet.id == null ||
            localSheet.lastUpdated.isAfter(remoteSheet.lastUpdated)) {
          return true; // Found an unsynced sheet
        }
      }

      return false;
    } catch (e) {
      print('Error checking for unsynced sheets: $e');
      // If we can't check (no internet), assume there might be unsynced sheets
      return true;
    }
  }
}
