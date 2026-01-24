import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/models/clipboard_item.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/src/services/firestore_service.dart';
import 'package:uuid/uuid.dart';

class SheetDatabaseHelper {
  static Database? _database;
  final FirestoreService? _firestoreService;
  final String? _userId;

  SheetDatabaseHelper({String? userId, FirestoreService? firestoreService})
      : _userId = userId,
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
      version: 4,
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

    // Set userId if available
    if (_userId != null) {
      sheet.userId = _userId;
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

      await db.insert('sheets', row);
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

    // Set userId if available
    if (_userId != null) {
      sheet.userId = _userId;
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

  /// Close the database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
