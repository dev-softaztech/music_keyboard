import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/row_properties.dart';

class SheetRows {
  List<MusicalNote> notes;
  RowProperties rowProperties;

  SheetRows({required this.notes, required this.rowProperties});

  Map<String, dynamic> toJson() {
    return {
      'notes': notes.map((note) => note.toJson()).toList(),
      'rowProperties': rowProperties.toJson(),
    };
  }

  factory SheetRows.fromJson(Map<String, dynamic> json) {
    return SheetRows(
      notes: (json['notes'] as List<dynamic>?)
              ?.map((noteJson) => MusicalNote.fromJson(noteJson))
              .toList() ??
          [],
      rowProperties: RowProperties.fromJson(json['rowProperties'] ?? {}),
    );
  }
}
