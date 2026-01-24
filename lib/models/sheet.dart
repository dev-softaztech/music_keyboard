import 'package:music_keyboard/models/sheet_properties.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/models/keyboard_type.dart';

class Sheet {
  String? id; // Unique GUID identifier
  String? userId;
  String? ownerName; // Display name of the sheet owner
  List<SheetRows> sheetRows;
  SheetProperties sheetProperties;
  SheetFormat format;
  KeyboardType keyboardType;
  DateTime createdOn;
  DateTime lastUpdated;

  Sheet({
    this.id,
    this.userId,
    this.ownerName,
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
      'ownerName': ownerName,
      'sheetRows': sheetRows.map((row) => row.toJson()).toList(),
      'sheetProperties': sheetProperties.toJson(),
      'format': format.toJson(),
      'keyboardType': keyboardType.toJson(),
      'createdOn': createdOn.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory Sheet.fromJson(Map<String, dynamic> json) {
    // Ensure ID is always a string, even if stored as a number
    String? id;
    if (json['id'] != null) {
      id = json['id'].toString();
    }

    // Ensure userId is always a string if present
    String? userId;
    if (json['userId'] != null) {
      userId = json['userId'].toString();
    }

    return Sheet(
      id: id,
      userId: userId,
      ownerName: json['ownerName']?.toString(),
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
