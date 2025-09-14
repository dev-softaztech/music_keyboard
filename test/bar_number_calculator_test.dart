import 'package:flutter_test/flutter_test.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/bar_number_calculator.dart';

void main() {
  group('BarNumberCalculator Tests', () {
    test('should count bars correctly in a single row with no bar lines', () {
      // Row with no bar lines should have 1 bar
      List<MusicalNote> row = [
        MusicalNote(pitch: 'C', octave: 4, type: NoteType.quarter),
        MusicalNote(pitch: 'D', octave: 4, type: NoteType.quarter),
        MusicalNote(pitch: 'E', octave: 4, type: NoteType.quarter),
        MusicalNote(pitch: 'F', octave: 4, type: NoteType.quarter),
      ];

      expect(BarNumberCalculator.countBarsInRow(row), equals(1));
    });

    test('should count bars correctly in a single row with bar lines', () {
      // Row with 2 bar lines should have 3 bars
      List<MusicalNote> row = [
        MusicalNote(pitch: 'C', octave: 4, type: NoteType.quarter),
        MusicalNote(pitch: 'D', octave: 4, type: NoteType.quarter),
        MusicalNote(pitch: '', octave: 0, type: NoteType.bar),
        MusicalNote(pitch: 'E', octave: 4, type: NoteType.quarter),
        MusicalNote(pitch: 'F', octave: 4, type: NoteType.quarter),
        MusicalNote(pitch: '', octave: 0, type: NoteType.bar),
        MusicalNote(pitch: 'G', octave: 4, type: NoteType.quarter),
        MusicalNote(pitch: 'A', octave: 4, type: NoteType.quarter),
      ];

      expect(BarNumberCalculator.countBarsInRow(row), equals(3));
    });

    test('should count bars correctly in empty row', () {
      List<MusicalNote> emptyRow = [];
      expect(BarNumberCalculator.countBarsInRow(emptyRow), equals(1));
    });

    test('should calculate bar numbers correctly for multiple rows', () {
      List<List<MusicalNote>> sheetNoteRows = [
        // Row 0: 2 bars (1 bar line)
        [
          MusicalNote(pitch: 'C', octave: 4, type: NoteType.quarter),
          MusicalNote(pitch: 'D', octave: 4, type: NoteType.quarter),
          MusicalNote(pitch: '', octave: 0, type: NoteType.bar),
          MusicalNote(pitch: 'E', octave: 4, type: NoteType.quarter),
          MusicalNote(pitch: 'F', octave: 4, type: NoteType.quarter),
        ],
        // Row 1: 1 bar (no bar lines)
        [
          MusicalNote(pitch: 'G', octave: 4, type: NoteType.quarter),
          MusicalNote(pitch: 'A', octave: 4, type: NoteType.quarter),
          MusicalNote(pitch: 'B', octave: 4, type: NoteType.quarter),
          MusicalNote(pitch: 'C', octave: 5, type: NoteType.quarter),
        ],
        // Row 2: 3 bars (2 bar lines)
        [
          MusicalNote(pitch: 'D', octave: 5, type: NoteType.quarter),
          MusicalNote(pitch: '', octave: 0, type: NoteType.bar),
          MusicalNote(pitch: 'E', octave: 5, type: NoteType.quarter),
          MusicalNote(pitch: '', octave: 0, type: NoteType.bar),
          MusicalNote(pitch: 'F', octave: 5, type: NoteType.quarter),
        ],
      ];

      // Row 0 should start at bar 1 (0 previous bars + 1)
      expect(BarNumberCalculator.calculateBarNumberForRow(sheetNoteRows, 0),
          equals(1));

      // Row 1 should start at bar 3 (2 previous bars + 1)
      expect(BarNumberCalculator.calculateBarNumberForRow(sheetNoteRows, 1),
          equals(3));

      // Row 2 should start at bar 4 (3 previous bars + 1)
      expect(BarNumberCalculator.calculateBarNumberForRow(sheetNoteRows, 2),
          equals(4));
    });

    test('should calculate bar numbers for all rows correctly', () {
      List<List<MusicalNote>> sheetNoteRows = [
        // Row 0: 1 bar
        [
          MusicalNote(pitch: 'C', octave: 4, type: NoteType.quarter),
          MusicalNote(pitch: 'D', octave: 4, type: NoteType.quarter),
        ],
        // Row 1: 2 bars
        [
          MusicalNote(pitch: 'E', octave: 4, type: NoteType.quarter),
          MusicalNote(pitch: '', octave: 0, type: NoteType.bar),
          MusicalNote(pitch: 'F', octave: 4, type: NoteType.quarter),
        ],
        // Row 2: 1 bar
        [
          MusicalNote(pitch: 'G', octave: 4, type: NoteType.quarter),
        ],
      ];

      List<int> barNumbers =
          BarNumberCalculator.calculateBarNumbersForAllRows(sheetNoteRows);

      expect(barNumbers, equals([1, 2, 4]));
    });

    test('should handle rows with only bar lines', () {
      List<MusicalNote> rowWithOnlyBarLines = [
        MusicalNote(pitch: '', octave: 0, type: NoteType.bar),
        MusicalNote(pitch: '', octave: 0, type: NoteType.bar),
        MusicalNote(pitch: '', octave: 0, type: NoteType.bar),
      ];

      // 3 bar lines = 4 bars
      expect(
          BarNumberCalculator.countBarsInRow(rowWithOnlyBarLines), equals(4));
    });

    test('should handle mixed note types correctly', () {
      List<MusicalNote> mixedRow = [
        MusicalNote(pitch: '', octave: 0, type: NoteType.clef),
        MusicalNote(pitch: 'C', octave: 4, type: NoteType.quarter),
        MusicalNote(pitch: '', octave: 0, type: NoteType.bar),
        MusicalNote(pitch: 'D', octave: 4, type: NoteType.rest),
        MusicalNote(pitch: '', octave: 0, type: NoteType.timeSignature),
        MusicalNote(pitch: 'E', octave: 4, type: NoteType.half),
      ];

      // Only 1 bar line, so 2 bars total
      expect(BarNumberCalculator.countBarsInRow(mixedRow), equals(2));
    });
  });
}
