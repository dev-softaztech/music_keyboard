import 'package:flutter/material.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
import 'package:music_keyboard/src/services/firestore_service.dart';
import 'package:music_keyboard/src/services/sync_service.dart';

abstract class HomeScreenHost {
  BuildContext get context;
  bool get mounted;
  String? get userId;

  void onSheetsLoaded(List<Sheet> sheets);
  void onLoadingChanged(bool isLoading);
  void onSyncErrorChanged(String? message);
}

class HomeScreenController {
  HomeScreenController({required this.host});

  final HomeScreenHost host;

  bool _isSyncing = false;

  Future<void> loadSavedSheets() async {
    if (_isSyncing) {
      print('HomeScreen: Sync already in progress, skipping...');
      return;
    }

    try {
      _isSyncing = true;
      host.onLoadingChanged(true);

      final userId = host.userId;

      // If user is logged in, sync sheets from Firebase first
      if (userId != null) {
        print('HomeScreen: User logged in, starting sync...');
        final syncService = SyncService();
        await syncService.syncSheets(userId);
        print('HomeScreen: Sync completed, loading sheets from database...');
      }

      final dbHelper = SheetDatabaseHelper(userId: userId);
      final sheets = await dbHelper.getAllSheets();
      print('HomeScreen: Loaded ${sheets.length} sheets from database');
      for (var sheet in sheets) {
        print(
            'HomeScreen: Sheet ${sheet.id} has ${sheet.sheetRows.length} rows');
        if (sheet.sheetRows.isNotEmpty) {
          print(
              'HomeScreen: First row has ${sheet.sheetRows[0].chords.length} notes');
        }
      }

      // Force UI refresh with new data
      if (host.mounted) {
        host.onSheetsLoaded(sheets);
        host.onLoadingChanged(false);
        print('HomeScreen: UI updated with ${sheets.length} sheets');
      }
    } catch (e) {
      print('HomeScreen: Error loading sheets: $e');
      if (host.mounted) {
        host.onLoadingChanged(false);
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Handle pull-to-refresh action
  Future<void> handleRefresh() async {
    host.onSyncErrorChanged(null);

    final userId = host.userId;

    if (userId == null) {
      host.onSyncErrorChanged('Unable to sync');
      return;
    }

    if (_isSyncing) {
      print('HomeScreen: Sync already in progress, skipping...');
      return;
    }

    try {
      _isSyncing = true;
      print('HomeScreen: Manual refresh triggered, starting sync...');

      final syncService = SyncService();
      await syncService.syncSheets(userId);

      final dbHelper = SheetDatabaseHelper(userId: userId);
      final sheets = await dbHelper.getAllSheets();
      print(
          'HomeScreen: Manual refresh completed with ${sheets.length} sheets');

      if (host.mounted) {
        host.onSheetsLoaded(sheets);
        host.onSyncErrorChanged(null); // Clear error on success
      }
    } catch (e) {
      print('HomeScreen: Error during manual refresh: $e');
      if (host.mounted) {
        host.onSyncErrorChanged('Unable to sync');
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> deleteSheets(Set<String> sheetIds) async {
    if (sheetIds.isEmpty) return;

    final userId = host.userId;
    final dbHelper = SheetDatabaseHelper(userId: userId);
    final firestoreService = FirestoreService();

    for (final sheetId in sheetIds) {
      // Delete from local database
      await dbHelper.deleteSheet(sheetId);

      // If user is logged in, delete from Firebase and mark as deleted
      if (userId != null) {
        await firestoreService.deleteSheet(sheetId, userId);
        await firestoreService.markSheetAsDeleted(sheetId, userId);
      }
    }

    await loadSavedSheets();
  }
}
