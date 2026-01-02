import 'package:music_keyboard/models/sheet_rows.dart';

class ClipboardItem {
  int? id;
  String name;
  DateTime dateCopied;
  List<SheetRows> rows;

  ClipboardItem({
    this.id,
    this.name = 'Untitled',
    required this.dateCopied,
    required this.rows,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dateCopied': dateCopied.toIso8601String(),
      'rows': rows.map((row) => row.toJson()).toList(),
    };
  }

  factory ClipboardItem.fromJson(Map<String, dynamic> json) {
    return ClipboardItem(
      id: json['id'],
      name: json['name'] ?? 'Untitled',
      dateCopied: DateTime.parse(json['dateCopied']),
      rows: (json['rows'] as List<dynamic>?)
              ?.map((rowJson) => SheetRows.fromJson(rowJson))
              .toList() ??
          [],
    );
  }
}
