import 'package:music_keyboard/models/sheet_format_config.dart';

enum SheetFormat {
  single, // Current default behavior - independent rows
  piano, // 2 connected rows (treble + bass)
  grand, // Future: 4 connected rows
}

extension SheetFormatExtension on SheetFormat {
  String get displayName {
    switch (this) {
      case SheetFormat.single:
        return 'Single Staff';
      case SheetFormat.piano:
        return 'Piano Music';
      case SheetFormat.grand:
        return 'Grand Staff';
    }
  }

  String get description {
    switch (this) {
      case SheetFormat.single:
        return 'Independent single rows';
      case SheetFormat.piano:
        return 'Connected treble and bass rows';
      case SheetFormat.grand:
        return 'Four connected rows';
    }
  }

  /// Number of rows that should be connected together
  int get rowsPerGroup {
    switch (this) {
      case SheetFormat.single:
        return 1;
      case SheetFormat.piano:
        return 2;
      case SheetFormat.grand:
        return 4;
    }
  }

  /// Default clefs for each row in a group (in order)
  List<String> get defaultClefs {
    switch (this) {
      case SheetFormat.single:
        return ['\uf472']; // Treble clef
      case SheetFormat.piano:
        return ['\uf472', '\uf474']; // Treble, Bass
      case SheetFormat.grand:
        return [
          '\uf472',
          '\uf474',
          '\uf472',
          '\uf474'
        ]; // Treble, Bass, Treble, Bass
    }
  }

  /// Configuration for layout and PDF export settings
  SheetFormatConfig get config {
    switch (this) {
      case SheetFormat.single:
        // Single staff - can fit more rows per page
        return const SheetFormatConfig(
          musicSheetWidth: 1320,
          a4Height: 1700,
          a4ProportionalRatio: 1.7,
          rowsOnFirstPage: 8, // More rows for single staff
          rowsOnFollowingPages: 10,
        );
      case SheetFormat.piano:
        // Piano format (2 connected rows) - current working configuration
        return const SheetFormatConfig(
          musicSheetWidth: 1320,
          a4Height: 1700,
          a4ProportionalRatio: 1.7,
          rowsOnFirstPage: 8,
          rowsOnFollowingPages: 10,
        );
      case SheetFormat.grand:
        // Grand staff (4 connected rows) - fewer rows per page
        return const SheetFormatConfig(
          musicSheetWidth: 1000,
          a4Height: 1700,
          a4ProportionalRatio: 1.7,
          rowsOnFirstPage: 5,
          rowsOnFollowingPages: 10,
        );
    }
  }
}
