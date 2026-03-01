import 'package:music_keyboard/models/keyboard_type.dart';
import 'package:music_keyboard/models/sheet_format_config.dart';

enum SheetFormat {
  single, // Current default behavior - independent rows
  twoRows, // 2 connected rows (treble + bass)
  threeRows,
  fourRows,
  fiveRows
}

extension SheetFormatExtension on SheetFormat {
  String get displayName {
    switch (this) {
      case SheetFormat.single:
        return 'Single Stave';
      case SheetFormat.twoRows:
        return 'Two Staves';
      case SheetFormat.threeRows:
        return 'Three Staves';
      case SheetFormat.fourRows:
        return 'Four Staves';
      case SheetFormat.fiveRows:
        return 'Five Staves';
    }
  }

  String get description {
    switch (this) {
      case SheetFormat.single:
        return 'Independent single rows';
      case SheetFormat.twoRows:
        return 'Two connected treble and bass rows e.g. Piano';
      case SheetFormat.threeRows:
        return 'Three connected treble and bass rows e.g. Organ';
      case SheetFormat.fourRows:
        return 'Four connected rows for multiple instruments';
      case SheetFormat.fiveRows:
        return 'Five connected rows for multiple instruments';
    }
  }

  /// Number of rows that should be connected together
  int get rowsPerGroup {
    switch (this) {
      case SheetFormat.single:
        return 1;
      case SheetFormat.twoRows:
        return 2;
      case SheetFormat.threeRows:
        return 3;
      case SheetFormat.fourRows:
        return 4;
      case SheetFormat.fiveRows:
        return 5;
    }
  }

  /// Default clefs for each row in a group (in order) for the given keyboard type
  List<String> defaultClefsFor(KeyboardType keyboardType) {
    switch (this) {
      case SheetFormat.single:
        switch (keyboardType) {
          case KeyboardType.sheet:
            return ['\uf472']; // Treble clef
          case KeyboardType.drumTab:
            return ['\uf472']; // Treble clef
          case KeyboardType.guitarTab:
            return []; // Tab clef
        }
      case SheetFormat.twoRows:
        switch (keyboardType) {
          case KeyboardType.sheet:
            return ['\uf472', '\uf474']; // Treble, Bass
          case KeyboardType.drumTab:
            return ['\uf472', '\uf474']; // Treble, Bass
          case KeyboardType.guitarTab:
            return ['\uf472', '\uf474']; // Treble, Bass
        }
      case SheetFormat.threeRows:
        switch (keyboardType) {
          case KeyboardType.sheet:
            return ['\uf472', '\uf472', '\uf474']; // Treble, Treble, Bass
          case KeyboardType.drumTab:
            return ['\uf472', '\uf472', '\uf474']; // Treble, Treble, Bass
          case KeyboardType.guitarTab:
            return ['\uf472', '\uf472', '\uf474']; // Treble, Treble, Bass
        }
      case SheetFormat.fourRows:
        switch (keyboardType) {
          case KeyboardType.sheet:
            return [
              '\uf472',
              '\uf472',
              '\uf472',
              '\uf474'
            ]; // Treble, Treble, Treble, Bass
          case KeyboardType.drumTab:
            return [
              '\uf472',
              '\uf472',
              '\uf472',
              '\uf474'
            ]; // Treble, Treble, Treble, Bass
          case KeyboardType.guitarTab:
            return [
              '\uf472',
              '\uf472',
              '\uf472',
              '\uf474'
            ]; // Treble, Treble, Treble, Bass
        }
      case SheetFormat.fiveRows:
        switch (keyboardType) {
          case KeyboardType.sheet:
            return [
              '\uf472',
              '\uf472',
              '\uf472',
              '\uf472',
              '\uf474'
            ]; // Treble, Treble, Treble, Treble, Bass
          case KeyboardType.drumTab:
            return [
              '\uf472',
              '\uf472',
              '\uf472',
              '\uf472',
              '\uf474'
            ]; // Treble, Treble, Treble, Treble, Bass
          case KeyboardType.guitarTab:
            return [
              '\uf472',
              '\uf472',
              '\uf472',
              '\uf472',
              '\uf474'
            ]; // Treble, Treble, Treble, Treble, Bass
        }
    }
  }

  SheetFormatConfig get config {
    switch (this) {
      case SheetFormat.single:
        return const SheetFormatConfig(
          musicSheetWidth: 1320,
          a4Height: 1700,
          a4ProportionalRatio: 1.7,
          rowsOnFirstPage: 8,
          rowsOnFollowingPages: 10,
        );
      case SheetFormat.twoRows:
        return const SheetFormatConfig(
          musicSheetWidth: 1320,
          a4Height: 1700,
          a4ProportionalRatio: 1.7,
          rowsOnFirstPage: 8,
          rowsOnFollowingPages: 10,
        );
      case SheetFormat.threeRows:
        return const SheetFormatConfig(
          musicSheetWidth: 1320,
          a4Height: 1700,
          a4ProportionalRatio: 1.7,
          rowsOnFirstPage: 9,
          rowsOnFollowingPages: 9,
        );
      case SheetFormat.fourRows:
        return const SheetFormatConfig(
          musicSheetWidth: 1320,
          a4Height: 1700,
          a4ProportionalRatio: 1.7,
          rowsOnFirstPage: 8,
          rowsOnFollowingPages: 8,
        );
      case SheetFormat.fiveRows:
        return const SheetFormatConfig(
          musicSheetWidth: 1320,
          a4Height: 1700,
          a4ProportionalRatio: 1.7,
          rowsOnFirstPage: 5,
          rowsOnFollowingPages: 10,
        );
    }
  }

  String toJson() => toString().split('.').last;

  static SheetFormat fromJson(String value) {
    return SheetFormat.values.firstWhere(
      (e) => e.toString().split('.').last == value,
      orElse: () => SheetFormat.single,
    );
  }
}
