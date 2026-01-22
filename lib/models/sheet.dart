import 'package:music_keyboard/models/sheet_properties.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/models/keyboard_type.dart';

class Sheet {
  String? id; // Unique GUID identifier
  String? userId;
  List<SheetRows> sheetRows;
  SheetProperties sheetProperties;
  SheetFormat format;
  KeyboardType keyboardType;
  DateTime createdOn;
  DateTime lastUpdated;

  Sheet({
    this.id,
    this.userId,
    required this.sheetRows,
    required this.sheetProperties,
    this.format = SheetFormat.single,
    this.keyboardType = KeyboardType.sheet,
    DateTime? createdOn,
    DateTime? lastUpdated,
  })  : createdOn = createdOn ?? DateTime.now(),
        lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'sheetRows': sheetRows.map((row) => row.toJson()).toList(),
      'sheetProperties': sheetProperties.toJson(),
      'format': format.toJson(),
      'keyboardType': keyboardType.toJson(),
      'createdOn': createdOn.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory Sheet.fromJson(Map<String, dynamic> json) {
    return Sheet(
      id: json['id'],
      userId: json['userId'],
      sheetRows: (json['sheetRows'] as List<dynamic>?)
              ?.map((rowJson) => SheetRows.fromJson(rowJson))
              .toList() ??
          [],
      sheetProperties: SheetProperties.fromJson(json['sheetProperties'] ?? {}),
      format: SheetFormatExtension.fromJson(json['format'] ?? 'single'),
      keyboardType:
          KeyboardTypeExtension.fromJson(json['keyboardType'] ?? 'sheet'),
      createdOn:
          DateTime.parse(json['createdOn'] ?? DateTime.now().toIso8601String()),
      lastUpdated: DateTime.parse(
          json['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }
}
