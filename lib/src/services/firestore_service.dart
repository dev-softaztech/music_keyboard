import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:music_keyboard/models/sheet.dart';

// Top-level function for parsing sheet in background isolate
Sheet? _parseSheet(Map<String, dynamic> json) {
  try {
    return Sheet.fromJson(json);
  } catch (e) {
    print('Error parsing sheet: $e');
    return null;
  }
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Cleanup threshold: Remove deletion records older than 90 days
  static const int deletionCleanupDays = 90;

  Future<void> addSheet(Sheet sheet, String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('sheets')
        .doc(sheet.id!)
        .set(sheet.toJson());
  }

  Future<void> updateSheet(Sheet sheet, String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('sheets')
        .doc(sheet.id!)
        .update(sheet.toJson());
  }

  Future<void> deleteSheet(String sheetId, String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('sheets')
        .doc(sheetId)
        .delete();
  }

  Future<Sheet?> getSheet(String sheetId, String userId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('sheets')
          .doc(sheetId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (doc.exists) {
        return await compute(_parseSheet, doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting sheet from Firebase: $e');
      return null;
    }
  }

  Stream<List<Sheet>> getSheets(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('sheets')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Sheet.fromJson(doc.data())).toList());
  }

  /// Get sheets once using direct fetch (more reliable for one-time sync)
  /// This forces Firestore to attempt a server fetch instead of returning cached data
  Future<List<Sheet>> getSheetsOnce(String userId) async {
    const int maxRetries = 3;
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        print(
            'FirestoreService: Fetching sheets from server for user $userId (attempt ${attempt + 1})');
        final snapshot = await _db
            .collection('users')
            .doc(userId)
            .collection('sheets')
            .get(const GetOptions(source: Source.server));

        final sheets = snapshot.docs
            .map((doc) {
              try {
                return Sheet.fromJson(doc.data());
              } catch (e) {
                print('Error parsing sheet ${doc.id}: $e');
                return null;
              }
            })
            .whereType<Sheet>()
            .toList();

        print('FirestoreService: Found ${sheets.length} sheets');
        return sheets;
      } catch (e) {
        attempt++;
        print('Error fetching sheets from Firestore (attempt $attempt): $e');

        // Check if it's a retryable error (service unavailable)
        final errorString = e.toString().toLowerCase();
        final isRetryable = errorString.contains('unavailable') ||
            errorString.contains('deadline exceeded') ||
            errorString.contains('cancelled');

        if (attempt < maxRetries && isRetryable) {
          // Exponential backoff: wait 2^attempt seconds
          final delaySeconds = 1 << attempt; // 1, 2, 4 seconds
          print('FirestoreService: Retrying in $delaySeconds seconds...');
          await Future.delayed(Duration(seconds: delaySeconds));
        } else {
          // If not retryable or max retries reached, fall back to cache
          print(
              'FirestoreService: Max retries reached or non-retryable error, falling back to cache');
          try {
            print('FirestoreService: Falling back to cache');
            final snapshot = await _db
                .collection('users')
                .doc(userId)
                .collection('sheets')
                .get();

            final sheets = snapshot.docs
                .map((doc) {
                  try {
                    return Sheet.fromJson(doc.data());
                  } catch (e) {
                    print('Error parsing sheet ${doc.id}: $e');
                    return null;
                  }
                })
                .whereType<Sheet>()
                .toList();

            print('FirestoreService: Found ${sheets.length} sheets from cache');
            return sheets;
          } catch (cacheError) {
            print('Error fetching from cache: $cacheError');
            return [];
          }
        }
      }
    }

    // This should never be reached, but just in case
    return [];
  }

  /// Mark a sheet as deleted by adding its ID to the deletions list
  Future<void> markSheetAsDeleted(String sheetId, String userId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('metadata')
          .doc('deletions')
          .set({
        'deletedSheets': FieldValue.arrayUnion([
          {
            'sheetId': sheetId,
            'deletedAt': Timestamp.now(),
          }
        ]),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error marking sheet as deleted: $e');
    }
  }

  /// Get list of deleted sheet IDs
  Future<List<String>> getDeletedSheetIds(String userId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('metadata')
          .doc('deletions')
          .get();

      if (doc.exists && doc.data() != null) {
        final deletedSheets = doc.data()!['deletedSheets'] as List<dynamic>?;
        if (deletedSheets != null) {
          return deletedSheets
              .map((item) => item['sheetId'] as String)
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getting deleted sheet IDs: $e');
      return [];
    }
  }

  /// Remove deletion records older than 90 days to prevent unbounded growth
  Future<void> cleanupOldDeletions(String userId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('metadata')
          .doc('deletions')
          .get();

      if (!doc.exists || doc.data() == null) return;

      final deletedSheets = doc.data()!['deletedSheets'] as List<dynamic>?;
      if (deletedSheets == null || deletedSheets.isEmpty) return;

      final cutoffDate = DateTime.now()
          .subtract(Duration(days: deletionCleanupDays))
          .millisecondsSinceEpoch;

      final sheetsToRemove = <Map<String, dynamic>>[];

      for (final item in deletedSheets) {
        final deletedAt = item['deletedAt'] as Timestamp?;
        if (deletedAt != null &&
            deletedAt.millisecondsSinceEpoch < cutoffDate) {
          sheetsToRemove.add(item as Map<String, dynamic>);
        }
      }

      if (sheetsToRemove.isNotEmpty) {
        await _db
            .collection('users')
            .doc(userId)
            .collection('metadata')
            .doc('deletions')
            .update({
          'deletedSheets': FieldValue.arrayRemove(sheetsToRemove),
        });
        print('Cleaned up ${sheetsToRemove.length} old deletion records');
      }
    } catch (e) {
      print('Error cleaning up old deletions: $e');
    }
  }

  /// Remove a specific sheet ID from the deletions list
  /// (useful if a sheet with the same ID is being recreated)
  Future<void> removeFromDeletionsList(String sheetId, String userId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('metadata')
          .doc('deletions')
          .get();

      if (!doc.exists || doc.data() == null) return;

      final deletedSheets = doc.data()!['deletedSheets'] as List<dynamic>?;
      if (deletedSheets == null) return;

      final itemToRemove = deletedSheets.firstWhere(
        (item) => item['sheetId'] == sheetId,
        orElse: () => null,
      );

      if (itemToRemove != null) {
        await _db
            .collection('users')
            .doc(userId)
            .collection('metadata')
            .doc('deletions')
            .update({
          'deletedSheets': FieldValue.arrayRemove([itemToRemove]),
        });
      }
    } catch (e) {
      print('Error removing sheet from deletions list: $e');
    }
  }
}
