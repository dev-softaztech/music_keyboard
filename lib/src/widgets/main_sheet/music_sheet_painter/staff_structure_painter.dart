import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/models/sheet_properties.dart';
import 'package:music_keyboard/models/keyboard_type.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/key_signature_position_calculator.dart';
import 'package:music_keyboard/src/utils/pdf_exporter.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/bar_number_calculator.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_width_calculator.dart';

/// Draws the structural elements of the main music sheet: staff lines,
/// cursor, curly braces, bar numbers/lines, page breaks, row highlights,
/// key signatures, and connected-row (piano/grand staff) elements.
///
/// This is a plain (non-CustomPainter) helper class used by
/// [MusicSheetPainter] via composition. All methods take the
/// [Canvas]/[Paint]/geometry they need as explicit arguments and hold no
/// mutable state of their own.
class StaffStructurePainter {
  /// Draw permanent curly braces from saved groups
  void drawPermanentCurlyBraces(
      Canvas canvas,
      Size size,
      double lineSpacing,
      double adjustedVerticalOffset,
      Map<int, double> cumulativeMarginOffsets,
      double sheetHeight,
      int startRow,
      double rowSpacing,
      List<CurlyBraceGroup> curlyBraceGroups) {
    for (final group in curlyBraceGroups) {
      final firstRow = group.startRow;
      final lastRow = group.endRow;
      final rowCount = lastRow - firstRow + 1;

      if (rowCount < 2) continue; // Need at least 2 rows for a curly brace

      // Calculate Y positions for top and bottom of the curly brace
      final int adjustedFirstRow = firstRow - startRow;
      final int adjustedLastRow = lastRow - startRow;

      final double firstMarginOffset = cumulativeMarginOffsets[firstRow] ?? 0.0;
      final double lastMarginOffset = cumulativeMarginOffsets[lastRow] ?? 0.0;

      final double topY = adjustedVerticalOffset +
          (adjustedFirstRow * (rowSpacing + sheetHeight)) +
          firstMarginOffset;
      final double bottomY = adjustedVerticalOffset +
          (adjustedLastRow * (rowSpacing + sheetHeight)) +
          lastMarginOffset +
          sheetHeight;

      // Draw the curly brace
      drawCurlyBrace(canvas, topY, bottomY, rowCount);
    }
  }

  /// Draw a single curly brace on the left side spanning from topY to bottomY
  void drawCurlyBrace(
      Canvas canvas, double topY, double bottomY, int rowCount) {
    const double leftX =
        45.0; // Position to the left of staff lines (which start at x=60)
    final double height = bottomY - topY;

    // For 2 rows (piano), draw a single curly brace
    // For 3-5 rows, repeat curly braces to fill the space
    final int braceCount = rowCount == 2 ? 1 : ((rowCount / 2).ceil());
    final double braceHeight = height / braceCount;

    // Use Bravura font character  for curly brace
    const String braceChar = '';

    for (int i = 0; i < braceCount; i++) {
      final double braceTopY = topY + (i * braceHeight);
      final double braceCenterY = braceTopY + (braceHeight / 2);

      final textPainter = TextPainter(
        text: TextSpan(
          text: braceChar,
          style: TextStyle(
            fontFamily: 'Bravura',
            fontSize: braceHeight,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Center the brace vertically
      final double yPos = braceCenterY - (textPainter.height / 2) + 110;
      // Position slightly to the left
      final double xPos = leftX - (textPainter.width / 2);

      textPainter.paint(canvas, Offset(xPos, yPos));
    }
  }

  /// Draw connecting lines and shared bar lines for connected row formats
  void drawConnectedRowElements(
      Canvas canvas,
      Size size,
      SheetFormat sheetFormat,
      List<SheetRows> sheetNoteRows,
      double rowSpacing,
      KeyboardType keyboardType,
      List<double> rowSpacingList,
      int? renderStartRow,
      int? renderEndRow,
      bool showTitleAndComposer,
      double verticalOffset) {
    if (sheetFormat == SheetFormat.single) {
      return; // No connecting elements needed for single format
    }

    const double lineSpacing = 10;
    const double sheetHeight = lineSpacing * 4;

    // Determine which rows to render
    final int startRow = renderStartRow ?? 0;
    final int endRow = renderEndRow ?? (sheetNoteRows.length - 1);

    // Calculate page margins - 50px header/footer for non-first pages
    const double pageHeaderMargin = 50.0;
    const double pageFooterMargin = 50.0;

    // Calculate which page we're on for margin adjustments
    final pageBreaks =
        PdfExporter.calculatePageBreaks(sheetNoteRows, rowSpacing, sheetFormat);
    int currentPageIndex = 0;
    for (int i = 0; i < pageBreaks.length; i++) {
      if (startRow >= pageBreaks[i].startRow &&
          startRow <= pageBreaks[i].endRow) {
        currentPageIndex = i;
        break;
      }
    }

    // Adjust vertical offset for partial rendering and page margins
    double adjustedVerticalOffset = verticalOffset;
    if (renderStartRow != null && renderEndRow != null) {
      if (showTitleAndComposer) {
        // Increased from 200 to 250 to match painter adjustment
        adjustedVerticalOffset = pageHeaderMargin + 350;
      } else {
        // Increased from 50 to 150 to match painter adjustment
        adjustedVerticalOffset = pageHeaderMargin + 300;
      }
    } else if (currentPageIndex > 0) {
      adjustedVerticalOffset = verticalOffset + pageHeaderMargin;
    }

    // Calculate cumulative margin offsets for all rows
    Map<int, double> cumulativeMarginOffsets = {};
    if (renderStartRow == null || renderEndRow == null) {
      final pageBreaks = PdfExporter.calculatePageBreaks(
          sheetNoteRows, rowSpacing, sheetFormat);
      double cumulativeOffset = 0.0;
      for (int rowIndex = 0; rowIndex < sheetNoteRows.length; rowIndex++) {
        cumulativeMarginOffsets[rowIndex] = cumulativeOffset;
        for (int i = 1; i < pageBreaks.length; i++) {
          final pageInfo = pageBreaks[i];
          if (rowIndex == pageInfo.startRow - 1) {
            cumulativeOffset += pageHeaderMargin;
            break;
          }
        }
        for (int i = 0; i < pageBreaks.length - 1; i++) {
          final pageInfo = pageBreaks[i];
          if (rowIndex == pageInfo.endRow) {
            cumulativeOffset += pageFooterMargin;
            break;
          }
        }
      }
    }

    // Group rows into connected groups based on format
    final int rowsPerGroup = sheetFormat.rowsPerGroup;

    // Draw connecting elements for each group
    for (int groupStartRow = startRow;
        groupStartRow <= endRow;
        groupStartRow += rowsPerGroup) {
      final int groupEndRow =
          math.min(groupStartRow + rowsPerGroup - 1, endRow);

      // Only draw connecting elements if we have a complete group
      if (groupEndRow - groupStartRow + 1 == rowsPerGroup && rowsPerGroup > 1) {
        drawConnectedGroup(
            canvas,
            size,
            groupStartRow,
            groupEndRow,
            adjustedVerticalOffset,
            cumulativeMarginOffsets,
            sheetHeight,
            sheetNoteRows,
            rowSpacingList,
            keyboardType,
            renderStartRow,
            rowSpacing);
      }
    }
  }

  /// Draw connecting elements for a specific group of connected rows
  void drawConnectedGroup(
      Canvas canvas,
      Size size,
      int groupStartRow,
      int groupEndRow,
      double adjustedVerticalOffset,
      Map<int, double> cumulativeMarginOffsets,
      double sheetHeight,
      List<SheetRows> sheetNoteRows,
      List<double> rowSpacingList,
      KeyboardType keyboardType,
      int? renderStartRow,
      double rowSpacing) {
    Paint paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0;

    // Calculate positions for the first and last rows in the group
    final int adjustedStartRow = groupStartRow - (renderStartRow ?? 0);
    final int adjustedEndRow = groupEndRow - (renderStartRow ?? 0);

    final double startMarginOffset =
        cumulativeMarginOffsets[groupStartRow] ?? 0.0;
    final double endMarginOffset = cumulativeMarginOffsets[groupEndRow] ?? 0.0;

    final double topStaffTop = adjustedVerticalOffset +
        (adjustedStartRow * (rowSpacing + sheetHeight)) +
        startMarginOffset;
    final double bottomStaffTop = adjustedVerticalOffset +
        (adjustedEndRow * (rowSpacing + sheetHeight)) +
        endMarginOffset;
    final double bottomStaffBottom = bottomStaffTop + sheetHeight;

    // Draw left connecting line (brace/bracket)
    const double leftX = 60;
    canvas.drawLine(
      Offset(leftX, topStaffTop),
      Offset(leftX, bottomStaffBottom),
      paint..strokeWidth = 2.0,
    );

    // Draw right connecting line
    final double rightX = size.width - 60;
    canvas.drawLine(
      Offset(rightX, topStaffTop),
      Offset(rightX, bottomStaffBottom),
      paint..strokeWidth = 2.0,
    );

    // Draw shared bar lines that connect the rows
    drawSharedBarLines(canvas, groupStartRow, groupEndRow, topStaffTop,
        bottomStaffBottom, sheetNoteRows, rowSpacingList, keyboardType);

    paint..strokeWidth = 1.0; // Reset stroke width
  }

  /// Draw shared bar lines that connect rows only when bars exist at same index
  void drawSharedBarLines(
      Canvas canvas,
      int groupStartRow,
      int groupEndRow,
      double topStaffTop,
      double bottomStaffBottom,
      List<SheetRows> sheetNoteRows,
      List<double> rowSpacingList,
      KeyboardType keyboardType) {
    Paint paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0;

    double currentRowSpacing = rowSpacingList[groupStartRow];

    // Find the maximum number of notes across all rows in the group
    int maxNotes = 0;
    for (int rowIndex = groupStartRow; rowIndex <= groupEndRow; rowIndex++) {
      maxNotes = math.max(maxNotes, sheetNoteRows[rowIndex].chords.length);
    }

    // Check each note index position across all rows
    for (int noteIndex = 0; noteIndex < maxNotes; noteIndex++) {
      // Track which rows have a bar at this index and their X positions
      Map<int, double> rowsWithBarsAtIndex = {};

      for (int rowIndex = groupStartRow; rowIndex <= groupEndRow; rowIndex++) {
        if (noteIndex < sheetNoteRows[rowIndex].chords.length) {
          MusicalNote note = sheetNoteRows[rowIndex].chords[noteIndex];

          if (note.type == NoteType.bar) {
            // Calculate X position for this bar
            double x = keyboardType.startingNoteX;
            for (int i = 0; i < noteIndex; i++) {
              if (i < sheetNoteRows[rowIndex].chords.length) {
                MusicalNote prevNote = sheetNoteRows[rowIndex].chords[i];

                // Calculate spacing for space notes
                double spaceNoteSpacing = 0;
                if (prevNote.type == NoteType.space && i > 0) {
                  // Check if previous note is also a space note
                  bool prevIsSpace =
                      sheetNoteRows[rowIndex].chords[i - 1].type ==
                          NoteType.space;
                  // First space note in sequence: no spacing, subsequent: full spacing
                  spaceNoteSpacing = prevIsSpace ? currentRowSpacing : 0;
                }

                x += prevNote.type == NoteType.clef ||
                        prevNote.type == NoteType.timeSignature
                    ? getNoteWidth(prevNote)
                    : prevNote.type == NoteType.keySignature
                        ? getNoteWidth(prevNote) + 10
                        : prevNote.type == NoteType.space
                            ? spaceNoteSpacing
                            : currentRowSpacing;
              }
            }
            rowsWithBarsAtIndex[rowIndex] = x;
          }
        }
      }

      // Only draw connecting line if ALL rows in the group have a bar at this index
      if (rowsWithBarsAtIndex.length == (groupEndRow - groupStartRow + 1)) {
        // All rows have a bar at this index, use the X position from the first row
        double barX =
            rowsWithBarsAtIndex[groupStartRow] ?? keyboardType.startingNoteX;

        canvas.drawLine(
          Offset(barX, topStaffTop),
          Offset(barX, bottomStaffBottom),
          paint,
        );
      }
    }
  }

  /// Draw a warning when there are too many notes in a bar
  void drawTooManyNotesWarning(
      Canvas canvas, double staffTop, double barStartX, double barEndX) {
    final TextPainter textPainter = TextPainter(
      text: const TextSpan(
        text: 'Too many notes for bar',
        style: TextStyle(
          color: Colors.red,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Position the warning above the specific bar
    final double barWidth = barEndX - barStartX;
    final double x = barStartX + (barWidth - textPainter.width) / 2;
    final double y = staffTop - 40;

    // Draw a semi-transparent background for better readability
    final Rect backgroundRect = Rect.fromLTWH(
        x - 10, y - 5, textPainter.width + 20, textPainter.height + 10);

    canvas.drawRect(
      backgroundRect,
      Paint()..color = Colors.white.withOpacity(0.8),
    );

    // Draw the warning text
    textPainter.paint(canvas, Offset(x, y));
  }

  /// Draw bar number above the start of a row
  void drawBarNumber(Canvas canvas, int rowIndex, double staffTop,
      List<SheetRows> sheetNoteRows) {
    // Calculate the bar number for this row
    int barNumber =
        BarNumberCalculator.calculateBarNumberForRow(sheetNoteRows, rowIndex);

    final textPainter = TextPainter(
      text: TextSpan(
        text: barNumber.toString(),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Position the bar number above and to the left of the staff start
    // X position: slightly to the right of the staff start (60 is where staff lines start)
    final double x = 75 - textPainter.width;
    // Y position: above the staff with some padding
    final double y = staffTop - 35;

    textPainter.paint(canvas, Offset(x, y));
  }

  /// Draw tempo above a specific bar note
  void drawBarTempo(Canvas canvas, MusicalNote barNote, double x, double textY) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Tempo = ${barNote.tempoNumber.round()}bpm',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    textY = textY - 15;

    textPainter.paint(canvas, Offset(x, textY));
  }

  /// Draw swing below the bar tempo if set
  void drawBarSwing(Canvas canvas, MusicalNote barNote, double x, double textY) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: barNote.swingText,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    textPainter.paint(canvas, Offset(x, textY));
  }

  /// Draw visual page breaks between A4-sized pages
  void drawPageBreaks(
      Canvas canvas,
      Size size,
      int? renderStartRow,
      int? renderEndRow,
      List<SheetRows> sheetNoteRows,
      double rowSpacing,
      SheetFormat sheetFormat,
      double verticalOffset) {
    // Only draw page breaks if we're not in partial rendering mode
    if (renderStartRow != null || renderEndRow != null) {
      return;
    }

    // Calculate page breaks using the same logic as PDF export
    final pageBreaks =
        PdfExporter.calculatePageBreaks(sheetNoteRows, rowSpacing, sheetFormat);

    // Only draw dividers if there are multiple pages
    if (pageBreaks.length <= 1) {
      return;
    }

    const double lineSpacing = 10;
    const double sheetHeight = lineSpacing * 4;
    const double pageHeaderMargin = 50.0;
    const double pageFooterMargin = 50.0;

    // Calculate cumulative margin offsets (same logic as main rendering)
    Map<int, double> cumulativeMarginOffsets = {};
    double cumulativeOffset = 0.0;

    for (int rowIndex = 0; rowIndex < sheetNoteRows.length; rowIndex++) {
      cumulativeMarginOffsets[rowIndex] = cumulativeOffset;

      // Check if this row is at the start of a non-first page (add header margin)
      for (int i = 1; i < pageBreaks.length; i++) {
        final pageInfo = pageBreaks[i];
        if (rowIndex == pageInfo.startRow) {
          cumulativeOffset += pageHeaderMargin;
          break;
        }
      }

      // Check if this row is at the end of any page (add footer margin after it)
      for (int i = 0; i < pageBreaks.length - 1; i++) {
        final pageInfo = pageBreaks[i];
        if (rowIndex == pageInfo.endRow) {
          cumulativeOffset += pageFooterMargin;
          break;
        }
      }
    }

    // Draw grey dividers between pages
    final Paint dividerPaint = Paint()
      ..color = const Color.fromARGB(255, 199, 199, 199) // Same as background
      ..strokeWidth = 3.0;

    for (int i = 1; i < pageBreaks.length; i++) {
      final pageInfo = pageBreaks[i];

      // Calculate the Y position where this page starts including margins
      final double marginOffset =
          cumulativeMarginOffsets[pageInfo.startRow] ?? 0.0;
      final double pageStartY = verticalOffset +
          (pageInfo.startRow * (rowSpacing + sheetHeight)) +
          marginOffset -
          (rowSpacing / 2);

      // Draw a horizontal line across the width of the sheet
      canvas.drawLine(
        Offset(0, pageStartY),
        Offset(size.width, pageStartY),
        dividerPaint,
      );
    }
  }

  void drawStaffLines(Canvas canvas, Paint paint, double staffTop,
      double lineSpacing, double sheetHeight, Size size,
      KeyboardType keyboardType) {
    // Draw horizontal staff lines based on keyboard type
    for (int i = 0; i < keyboardType.lineCount; i++) {
      final y = staffTop + i * lineSpacing;
      canvas.drawLine(
        Offset(60, y),
        Offset(size.width - 60, y),
        paint..strokeWidth = 1.0,
      );
    }

    // Draw vertical lines at start and end of staff
    canvas.drawLine(Offset(60, staffTop), Offset(60, staffTop + (sheetHeight)),
        paint..strokeWidth = 1.0);
    canvas.drawLine(
        Offset(size.width - 60, staffTop),
        Offset(size.width - 60, staffTop + (sheetHeight)),
        paint..strokeWidth = 1.0);
  }

  void drawInsertionCursor(
      Canvas canvas,
      Paint paint,
      double staffTop,
      int insertionIndex,
      Size size,
      double rowSpacing,
      List<MusicalNote> notes,
      double lineSpacing,
      KeyboardType keyboardType,
      int? selectionStart,
      int? selectionEnd,
      int? selectionRow) {
    if (selectionStart != null &&
        selectionEnd != null &&
        selectionRow != null) {
      return;
    }
    // Calculate cursor X position using the new note width calculator
    double cursorX = notes.isEmpty
        ? keyboardType.startingNoteX
        : calculateXPositionForIndex(
            insertionIndex - 1, notes, rowSpacing, false,
            startingX: keyboardType.startingNoteX);

    double cursorY = staffTop + (lineSpacing * 2);

    final Paint cursorPaint = Paint()..color = Colors.blue.withOpacity(0.8);

    if (insertionIndex > 0) {
      if (insertionIndex >= notes.length) {
        insertionIndex = notes.length - 1;
      } else {
        insertionIndex = insertionIndex - 1;
      }

      // Check if the selected note is a space note
      bool isSpaceNote =
          notes.isNotEmpty && notes[insertionIndex].type == NoteType.space;
      bool isFirstSpaceInSequence = false;

      if (isSpaceNote && insertionIndex > 0) {
        // Check if previous note is also a space note
        isFirstSpaceInSequence =
            notes[insertionIndex - 1].type != NoteType.space;
      } else if (isSpaceNote && insertionIndex == 0) {
        // Space note at index 0 is always first in sequence
        isFirstSpaceInSequence = true;
      }

      // Don't add offset for key signatures or first-in-sequence space notes (which have 0 width)
      if (notes.isNotEmpty &&
          notes[insertionIndex].type == NoteType.keySignature) {
        cursorX += 0;
      } else if (isFirstSpaceInSequence) {
        cursorX += 0; // First space note has no width, so no offset
      } else {
        cursorX += 20; // Standard offset for other notes
      }
    }

    canvas.drawLine(
      Offset(cursorX, cursorY - 60),
      Offset(cursorX, cursorY + 60),
      cursorPaint..strokeWidth = 3.5,
    );
  }

  /// Draw highlight for entire row in select rows mode
  void drawRowHighlight(
      Canvas canvas, Size size, double staffTop, double lineSpacing) {
    final double sheetHeight = lineSpacing * 4;

    final Rect rowRect = Rect.fromLTRB(
      60, // Start from left edge of staff
      staffTop - 20, // A bit above the staff
      size.width - 60, // End at right edge of staff
      staffTop + sheetHeight + 20, // A bit below the staff
    );

    final Paint highlightPaint = Paint()
      ..color = Colors.blue.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    canvas.drawRect(rowRect, highlightPaint);
  }

  void drawHighlight(
      Canvas canvas,
      Size size,
      int rowIndex,
      double staffTop,
      double lineSpacing,
      List<SheetRows> sheetNoteRows,
      List<double> rowSpacingList,
      KeyboardType keyboardType,
      int? selectionStart,
      int? selectionEnd,
      int? selectionRow) {
    if (selectionStart == null ||
        selectionEnd == null ||
        selectionRow == null) {
      return;
    }

    final rowNotes = sheetNoteRows[selectionRow].chords;
    if (rowNotes.isEmpty) {
      return;
    }

    final int start =
        selectionStart < selectionEnd ? selectionStart : selectionEnd;
    final int end =
        selectionStart > selectionEnd ? selectionStart : selectionEnd;

    final double startX = calculateXPositionForIndex(
        start, rowNotes, rowSpacingList[rowIndex], true,
        startingX: keyboardType.startingNoteX);
    final double endX = calculateXPositionForIndex(
        end, rowNotes, rowSpacingList[rowIndex], false,
        startingX: keyboardType.startingNoteX);

    // Always cover at minimum the full stave height, then expand for notes outside
    final double staveTop = staffTop;
    final double staveBottom =
        staffTop + (lineSpacing * (keyboardType.lineCount - 1));
    double min_y = staveTop;
    double max_y = staveBottom;

    for (int i = start; i <= end; i++) {
      final note = rowNotes[i];
      double y = note.noteY;
      min_y = math.min(min_y, y - 15);
      max_y = math.max(max_y, y + 15);

      if (note.type != NoteType.whole &&
          note.type != NoteType.rest &&
          note.type != NoteType.clef &&
          note.type != NoteType.bar &&
          note.type != NoteType.accidental &&
          note.type != NoteType.timeSignature &&
          note.type != NoteType.keySignature &&
          note.type != NoteType.space) {
        final bool isUpsideDownNote = y < staffTop + 20;
        double stemHeight = 35.0;
        if (note.type == NoteType.thirtySecond ||
            note.type == NoteType.sixtyFourth) {
          stemHeight += 20.0;
        }
        if (isUpsideDownNote) {
          min_y = math.min(min_y, y - stemHeight);
        } else {
          max_y = math.max(max_y, y + stemHeight);
        }
      }
    }

    final Rect highlightRect = Rect.fromLTRB(
      startX - 10,
      min_y - 20,
      endX + 20,
      max_y,
    );

    final Paint highlightPaint = Paint()
      ..color = Colors.blue.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRect(highlightRect, highlightPaint);
    canvas.drawRect(highlightRect, borderPaint);

    final Paint handlePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
        Offset(highlightRect.left, highlightRect.center.dy), 7, handlePaint);
    canvas.drawCircle(
        Offset(highlightRect.right, highlightRect.center.dy), 7, handlePaint);
  }

  double endXForIndex(
      int index, double currentRowSpacing, KeyboardType keyboardType) {
    return keyboardType.startingNoteX + (index * currentRowSpacing);
  }

  /// Draw key signature on the staff
  void drawKeySignature(Canvas canvas, Paint paint, MusicalNote note,
      double lineSpacing, double staffTop, double x, Color noteColour) {
    // Parse the key signature name to determine symbol count and type
    final keySignatureName = note.keySignatureName;
    if (keySignatureName.isEmpty) return;

    // Map key signature names to their properties
    final Map<String, Map<String, dynamic>> keySignatureMap = {
      'G/Em': {'count': 1, 'isSharp': true},
      'D/Bm': {'count': 2, 'isSharp': true},
      'A/F#m': {'count': 3, 'isSharp': true},
      'E/C#m': {'count': 4, 'isSharp': true},
      'B/G#m': {'count': 5, 'isSharp': true},
      'F#/D#m': {'count': 6, 'isSharp': true},
      'C#/A#m': {'count': 7, 'isSharp': true},
      'F/Dm': {'count': 1, 'isSharp': false},
      'Bb/Gm': {'count': 2, 'isSharp': false},
      'Eb/Cm': {'count': 3, 'isSharp': false},
      'Ab/Fm': {'count': 4, 'isSharp': false},
      'Db/Bbm': {'count': 5, 'isSharp': false},
      'Gb/Ebm': {'count': 6, 'isSharp': false},
      'Cb/Abm': {'count': 7, 'isSharp': false},
    };

    final keyData = keySignatureMap[keySignatureName];
    if (keyData == null) return;

    final int symbolCount = keyData['count'];
    final bool isSharp = keyData['isSharp'];
    final String symbol = isSharp ? '♯' : '♭';

    final (sharpPositions, flatPositions) = getPositionsForClefType(
        note.keySignatureClefType, staffTop, lineSpacing);

    final positions = isSharp ? sharpPositions : flatPositions;
    final double symbolSpacing = 12.0; // Horizontal spacing between symbols

    // Draw the symbols
    for (int i = 0; i < symbolCount && i < positions.length; i++) {
      final symbolPainter = TextPainter(
        text: TextSpan(
          text: symbol,
          style: TextStyle(
            fontFamily: 'Bravura',
            fontSize: 40,
            color: noteColour,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      symbolPainter.layout();

      final double symbolX = x + (i * symbolSpacing);
      final double symbolY = positions[i] - (symbolPainter.height / 2);

      symbolPainter.paint(canvas, Offset(symbolX, symbolY));
    }
  }
}
