import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:music_keyboard/models/sheet.dart';

class SheetDatabaseHelper {
  static final SheetDatabaseHelper _instance = SheetDatabaseHelper._internal();
  static Database? _database;

  factory SheetDatabaseHelper() {
    return _instance;
  }

  SheetDatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'music_sheets.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
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

    return await db.update(
      'sheets',
      row,
      where: 'id = ?',
      whereArgs: [sheet.id],
    );
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
    return Sheet.fromJson(sheetData);
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
      return Sheet.fromJson(sheetData);
    });
  }

  /// Delete a sheet by its ID
  Future<int> deleteSheet(int id) async {
    final db = await database;
    return await db.delete(
      'sheets',
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
