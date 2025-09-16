import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';

/// Utility class for calculating bar numbers for each row
class BarNumberCalculator {
  /// Calculate the bar number for a specific row
  /// This is the total number of bars in all previous rows + 1
  static int calculateBarNumberForRow(
      List<SheetRows> sheetNoteRows, int rowIndex) {
    int totalBarsInPreviousRows = 0;

    // Count bars in all previous rows
    for (int i = 0; i < rowIndex; i++) {
      totalBarsInPreviousRows += countBarsInRow(sheetNoteRows[i].notes);
    }

    // Return the bar number for this row (previous bars + 1)
    return totalBarsInPreviousRows + 1;
  }

  /// Count the number of bars in a single row
  /// Rules:
  /// - Start of row counts as beginning of a bar
  /// - End of row counts as end of a bar
  /// - Each NoteType.bar note starts a new bar
  /// - If row has 3 bar lines, it has 4 bars total
  /// - If row has no bar lines, it has 1 bar
  static int countBarsInRow(List<MusicalNote> notes) {
    if (notes.isEmpty) {
      return 1; // Empty row still counts as 1 bar
    }

    int barLineCount = 0;

    // Count all bar line notes in the row
    for (MusicalNote note in notes) {
      if (note.type == NoteType.bar) {
        barLineCount++;
      }
    }

    // Total bars = bar lines + 1
    // This is because:
    // - Start of row is beginning of first bar
    // - Each bar line starts a new bar
    // - End of row is end of last bar
    return barLineCount + 1;
  }

  /// Get bar numbers for all rows in the sheet
  static List<int> calculateBarNumbersForAllRows(
      List<SheetRows> sheetNoteRows) {
    List<int> barNumbers = [];

    for (int i = 0; i < sheetNoteRows.length; i++) {
      barNumbers.add(calculateBarNumberForRow(sheetNoteRows, i));
    }

    return barNumbers;
  }
}
