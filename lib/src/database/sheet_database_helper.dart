import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/models/clipboard_item.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/src/services/firestore_service.dart';

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
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sheets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
  }

  /// Insert a new sheet into the database
  Future<int> insertSheet(Sheet sheet) async {
    final db = await database;
    final now = DateTime.now();

    // Update timestamps
    sheet.createdOn = now;
    sheet.lastUpdated = now;

    final Map<String, dynamic> row = {
      'sheet_data': jsonEncode(sheet.toJson()),
      'created_on': now.toIso8601String(),
      'last_updated': now.toIso8601String(),
    };

    final id = await db.insert('sheets', row);
    sheet.id = id;

    if (_userId != null && _firestoreService != null) {
      await _firestoreService!.addSheet(sheet, _userId!);
    }

    return id;
  }

  /// Update an existing sheet in the database
  Future<int> updateSheet(Sheet sheet) async {
    final db = await database;
    sheet.lastUpdated = DateTime.now();

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
  Future<Sheet?> getSheet(int id) async {
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
  Future<int> deleteSheet(int id) async {
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
