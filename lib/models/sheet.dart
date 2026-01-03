import 'package:music_keyboard/models/sheet_properties.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';

class Sheet {
  int? id; // Database primary key
  List<SheetRows> sheetRows;
  SheetProperties sheetProperties;
  SheetFormat format;
  DateTime createdOn;
  DateTime lastUpdated;

  Sheet({
    this.id,
    required this.sheetRows,
    required this.sheetProperties,
    this.format = SheetFormat.single,
    DateTime? createdOn,
    DateTime? lastUpdated,
  })  : createdOn = createdOn ?? DateTime.now(),
        lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'sheetRows': sheetRows.map((row) => row.toJson()).toList(),
      'sheetProperties': sheetProperties.toJson(),
      'format': format.toJson(),
      'createdOn': createdOn.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory Sheet.fromJson(Map<String, dynamic> json) {
    return Sheet(
      id: json['id'],
      sheetRows: (json['sheetRows'] as List<dynamic>?)
              ?.map((rowJson) => SheetRows.fromJson(rowJson))
              .toList() ??
          [],
      sheetProperties: SheetProperties.fromJson(json['sheetProperties'] ?? {}),
      format: SheetFormatExtension.fromJson(json['format'] ?? 'single'),
      createdOn:
          DateTime.parse(json['createdOn'] ?? DateTime.now().toIso8601String()),
      lastUpdated: DateTime.parse(
          json['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }
}
