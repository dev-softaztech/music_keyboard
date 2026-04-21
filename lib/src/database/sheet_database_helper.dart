import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/models/clipboard_item.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/src/services/firestore_service.dart';
import 'package:uuid/uuid.dart';

class SheetDatabaseHelper {
  static Database? _database;
  final FirestoreService? _firestoreService;
  final String? _userId;
  final String? _ownerName;

  SheetDatabaseHelper(
      {String? userId, String? ownerName, FirestoreService? firestoreService})
      : _userId = userId,
        _ownerName = ownerName,
        _firestoreService = firestoreService;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'music_sheets.db');
    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sheets(
        id TEXT PRIMARY KEY,
        sheet_data TEXT NOT NULL,
        created_on TEXT NOT NULL,
        last_updated TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE clipboard(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        date_copied TEXT NOT NULL,
        rows_data TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE favourite_chords(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chord_data TEXT NOT NULL,
        date_added TEXT NOT NULL,
        keyboard_type TEXT NOT NULL DEFAULT 'sheetMusic'
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE clipboard(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          date_copied TEXT NOT NULL,
          rows_data TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 4) {
      // Migration from integer IDs to GUID-based IDs
      await _migrateToGuidIds(db);
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS favourite_chords(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          chord_data TEXT NOT NULL,
          date_added TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 6) {
      await db.execute(
        "ALTER TABLE favourite_chords ADD COLUMN keyboard_type TEXT NOT NULL DEFAULT 'sheetMusic'",
      );
    }
  }

  Future<void> _migrateToGuidIds(Database db) async {
    const uuid = Uuid();

    // Create new table with TEXT id
    await db.execute('''
      CREATE TABLE sheets_new(
        id TEXT PRIMARY KEY,
        sheet_data TEXT NOT NULL,
        created_on TEXT NOT NULL,
        last_updated TEXT NOT NULL
      )
    ''');

    // Get all existing sheets
    final List<Map<String, dynamic>> oldSheets = await db.query('sheets');

    // Migrate each sheet with a new GUID
    for (final oldSheet in oldSheets) {
      final String newId = uuid.v4();
      final sheetData = jsonDecode(oldSheet['sheet_data']);

      // Update the ID in the sheet data
      sheetData['id'] = newId;

      await db.insert('sheets_new', {
        'id': newId,
        'sheet_data': jsonEncode(sheetData),
        'created_on': oldSheet['created_on'],
        'last_updated': oldSheet['last_updated'],
      });
    }

    // Drop old table and rename new table
    await db.execute('DROP TABLE IF EXISTS sheets');
    await db.execute('ALTER TABLE sheets_new RENAME TO sheets');
  }

  /// Insert a new sheet into the database
  Future<String> insertSheet(Sheet sheet) async {
    final db = await database;
    final now = DateTime.now();
    const uuid = Uuid();

    // Generate GUID if not already set
    if (sheet.id == null || sheet.id!.isEmpty) {
      sheet.id = uuid.v4();
    }

    // Set userId and ownerName if available
    if (_userId != null) {
      sheet.userId = _userId;
    }
    if (_ownerName != null) {
      sheet.ownerName = _ownerName;
    }

    // Update timestamps
    sheet.createdOn = now;
    sheet.lastUpdated = now;

    final Map<String, dynamic> row = {
      'id': sheet.id,
      'sheet_data': jsonEncode(sheet.toJson()),
      'created_on': now.toIso8601String(),
      'last_updated': now.toIso8601String(),
    };

    await db.insert('sheets', row);

    if (_userId != null && _firestoreService != null) {
      await _firestoreService!.addSheet(sheet, _userId!);
    }

    return sheet.id!;
  }

  /// Upsert a sheet (insert if new, update if exists)
  /// This is specifically for sync operations where we might receive
  /// a sheet that already exists locally
  Future<String> upsertSheet(Sheet sheet) async {
    if (sheet.id == null || sheet.id!.isEmpty) {
      // No ID means it's a new sheet, use insert
      return await insertSheet(sheet);
    }

    // Check if sheet exists
    final existingSheet = await getSheet(sheet.id!);

    if (existingSheet == null) {
      // Sheet doesn't exist, insert it (preserving its timestamps and userId from remote)
      // Note: sheet.userId should already be set from Firebase, but ensure it's not overwritten
      final db = await database;
      final Map<String, dynamic> row = {
        'id': sheet.id,
        'sheet_data': jsonEncode(sheet.toJson()),
        'created_on': sheet.createdOn.toIso8601String(),
        'last_updated': sheet.lastUpdated.toIso8601String(),
      };

      // Use ConflictAlgorithm.replace to handle any existing sheets with the same ID
      // This prevents UNIQUE constraint errors during re-sync after sign out/sign in
      await db.insert('sheets', row,
          conflictAlgorithm: ConflictAlgorithm.replace);
      print(
          'SheetDatabaseHelper: Inserted new sheet ${sheet.id} with userId ${sheet.userId}');

      // Note: Don't sync to Firestore here - this is called during sync FROM Firestore
      return sheet.id!;
    } else {
      // Sheet exists, update it (preserve userId from remote if available)
      final db = await database;
      final Map<String, dynamic> row = {
        'sheet_data': jsonEncode(sheet.toJson()),
        'last_updated': sheet.lastUpdated.toIso8601String(),
      };

      await db.update(
        'sheets',
        row,
        where: 'id = ?',
        whereArgs: [sheet.id],
      );
      print('SheetDatabaseHelper: Updated existing sheet ${sheet.id}');

      // Note: Don't sync to Firestore here - this is called during sync FROM Firestore
      return sheet.id!;
    }
  }

  /// Update an existing sheet in the database
  Future<int> updateSheet(Sheet sheet) async {
    final db = await database;
    sheet.lastUpdated = DateTime.now();

    // Set userId and ownerName if available
    if (_userId != null) {
      sheet.userId = _userId;
    }
    if (_ownerName != null) {
      sheet.ownerName = _ownerName;
    }

    final Map<String, dynamic> row = {
      'sheet_data': jsonEncode(sheet.toJson()),
      'last_updated': sheet.lastUpdated.toIso8601String(),
    };

    final result = await db.update(
      'sheets',
      row,
      where: 'id = ?',
      whereArgs: [sheet.id],
    );

    if (_userId != null && _firestoreService != null) {
      await _firestoreService!.updateSheet(sheet, _userId!);
    }

    return result;
  }

  /// Get a sheet by its ID
  Future<Sheet?> getSheet(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sheets',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final sheetData = jsonDecode(maps[0]['sheet_data']);
    final sheet = Sheet.fromJson(sheetData);
    sheet.id = maps[0]['id']; // Set the ID from the database
    sheet.createdOn = DateTime.parse(maps[0]['created_on']);
    sheet.lastUpdated = DateTime.parse(maps[0]['last_updated']);
    return sheet;
  }

  /// Get all sheets ordered by last updated (most recent first)
  Future<List<Sheet>> getAllSheets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sheets',
      orderBy: 'last_updated DESC',
    );

    return List.generate(maps.length, (i) {
      final sheetData = jsonDecode(maps[i]['sheet_data']);
      final sheet = Sheet.fromJson(sheetData);
      sheet.id = maps[i]['id']; // Set the ID from the database
      sheet.createdOn = DateTime.parse(maps[i]['created_on']);
      sheet.lastUpdated = DateTime.parse(maps[i]['last_updated']);
      return sheet;
    });
  }

  /// Delete a sheet by its ID
  Future<int> deleteSheet(String id) async {
    final db = await database;
    final result = await db.delete(
      'sheets',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (_userId != null && _firestoreService != null) {
      await _firestoreService!.deleteSheet(id, _userId!);
    }

    return result;
  }

  /// Delete all sheets from the local database
  Future<int> deleteAllSheets() async {
    final db = await database;
    // The delete operation automatically commits in sqflite
    // ConflictAlgorithm.replace in upsertSheet() handles any edge cases
    return await db.delete('sheets');
  }

  /// Insert a new clipboard item into the database
  Future<int> insertClipboardItem(ClipboardItem item) async {
    final db = await database;

    final Map<String, dynamic> row = {
      'name': item.name,
      'date_copied': item.dateCopied.toIso8601String(),
      'rows_data': jsonEncode(item.rows.map((row) => row.toJson()).toList()),
    };

    final id = await db.insert('clipboard', row);
    item.id = id;
    return id;
  }

  /// Get all clipboard items ordered by date copied (most recent first)
  Future<List<ClipboardItem>> getAllClipboardItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clipboard',
      orderBy: 'date_copied DESC',
    );

    return List.generate(maps.length, (i) {
      final rowsData = jsonDecode(maps[i]['rows_data']) as List<dynamic>;
      final rows =
          rowsData.map((rowJson) => SheetRows.fromJson(rowJson)).toList();

      return ClipboardItem(
        id: maps[i]['id'],
        name: maps[i]['name'],
        dateCopied: DateTime.parse(maps[i]['date_copied']),
        rows: rows,
      );
    });
  }

  /// Update an existing clipboard item in the database
  Future<int> updateClipboardItem(ClipboardItem item) async {
    final db = await database;

    final Map<String, dynamic> row = {
      'name': item.name,
      'date_copied': item.dateCopied.toIso8601String(),
      'rows_data': jsonEncode(item.rows.map((row) => row.toJson()).toList()),
    };

    return await db.update(
      'clipboard',
      row,
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// Delete a clipboard item by its ID
  Future<int> deleteClipboardItem(int id) async {
    final db = await database;
    return await db.delete(
      'clipboard',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Add a chord note to the favourites table. Returns the inserted row id.
  Future<int> insertFavouriteChord(MusicalNote chord,
      {String keyboardType = 'sheetMusic'}) async {
    final db = await database;
    return await db.insert('favourite_chords', {
      'chord_data': jsonEncode(chord.toJson()),
      'date_added': DateTime.now().toIso8601String(),
      'keyboard_type': keyboardType,
    });
  }

  /// Update the last-used timestamp of a favourite chord so it sorts first.
  Future<void> touchFavouriteChord(int id) async {
    final db = await database;
    await db.update(
      'favourite_chords',
      {'date_added': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Remove a favourite chord by its database id.
  Future<void> deleteFavouriteChord(int id) async {
    final db = await database;
    await db.delete('favourite_chords', where: 'id = ?', whereArgs: [id]);
  }

  /// Return all favourite chords ordered most-recent first.
  Future<List<({int id, MusicalNote chord})>> getAllFavouriteChords() async {
    final db = await database;
    final rows = await db.query('favourite_chords', orderBy: 'date_added DESC');
    return rows.map((row) {
      final note = MusicalNote.fromJson(
          jsonDecode(row['chord_data'] as String) as Map<String, dynamic>);
      return (id: row['id'] as int, chord: note);
    }).toList();
  }

  /// Return favourite chords for a specific keyboard type, ordered most-recent first.
  Future<List<({int id, MusicalNote chord})>> getFavouriteChordsByKeyboardType(
      String keyboardType) async {
    final db = await database;
    final rows = await db.query(
      'favourite_chords',
      where: 'keyboard_type = ?',
      whereArgs: [keyboardType],
      orderBy: 'date_added DESC',
    );
    return rows.map((row) {
      final note = MusicalNote.fromJson(
          jsonDecode(row['chord_data'] as String) as Map<String, dynamic>);
      return (id: row['id'] as int, chord: note);
    }).toList();
  }

  /// Find the database id of a stored favourite chord that matches [chord] by
  /// its child-note pitches/octaves. Returns null if no match is found.
  Future<int?> findMatchingFavouriteChordId(MusicalNote chord) async {
    final all = await getAllFavouriteChords();
    final childPitches = (chord.childNotes ?? [])
        .map((n) => '${n.pitch}${n.octave}')
        .toSet();
    for (final fav in all) {
      final favPitches = (fav.chord.childNotes ?? [])
          .map((n) => '${n.pitch}${n.octave}')
          .toSet();
      if (childPitches.length == favPitches.length &&
          childPitches.containsAll(favPitches)) {
        return fav.id;
      }
    }
    return null;
  }

  /// Close the database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
