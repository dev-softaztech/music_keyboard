import 'package:flutter/material.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/models/sheet_properties.dart';
import 'package:music_keyboard/models/keyboard_type.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/key_signature_position_calculator.dart';
import 'package:music_keyboard/src/utils/pdf_exporter.dart';
import 'package:vector_math/vector_math.dart' as vec;
import 'dart:math' as math;
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/bar_line_calculator.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/bar_number_calculator.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/drawing_helpers.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_width_calculator.dart';

class MusicSheetPainter extends CustomPainter {
  final String title;
  final String composer;
  final List<SheetRows> sheetNoteRows;
  final SheetFormat sheetFormat;
  final KeyboardType keyboardType;
  final int selectedRow;
  final int selectedIndex;
  final bool showCursor;
  final List<double> rowSpacingList;
  final int? selectionStart;
  final int? selectionEnd;
  final int? selectionRow;
  final int? editingDynamicIndex;
  final int? editingDynamicRow;
  final double rowSpacing;
  double verticalOffset;

  // parameters for partial export rendering
  final int? renderStartRow;
  final int? renderEndRow;
  final bool showTitleAndComposer;

  // Select Rows mode parameters
  final Set<int>? selectedRowsForCurlyBrace;

  // Curly brace groups (permanent)
  final List<CurlyBraceGroup> curlyBraceGroups;

  // Read-only mode flag
  final bool isReadOnly;

  MusicSheetPainter({
    required this.title,
    required this.composer,
    required this.sheetNoteRows,
    required this.sheetFormat,
    required this.keyboardType,
    required this.selectedRow,
    required this.selectedIndex,
    required this.showCursor,
    required this.rowSpacingList,
    required this.rowSpacing,
    this.selectionStart,
    this.selectionEnd,
    this.selectionRow,
    this.editingDynamicIndex,
    this.editingDynamicRow,
    this.verticalOffset = 250.0,
    this.renderStartRow,
    this.renderEndRow,
    this.showTitleAndComposer = true,
    this.selectedRowsForCurlyBrace,
    List<CurlyBraceGroup>? curlyBraceGroups,
    this.isReadOnly = false,
  }) : curlyBraceGroups = curlyBraceGroups ?? [];

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the proper background height based on page breaks
    double backgroundHeight = _calculateRequiredBackgroundHeight(size);

    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, backgroundHeight), backgroundPaint);

    Paint paint = Paint()..color = Colors.black;
    Color noteColour = Colors.black;
    const double lineSpacing = 10;
    final double sheetHeight = lineSpacing * (keyboardType.lineCount - 1);

    // Draw title and composer only if showTitleAndComposer is true
    if (showTitleAndComposer) {
      _drawTitleAndComposer(canvas, size);
    }

    // Draw visual page breaks if content spans multiple pages
    _drawPageBreaks(canvas, size);

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
      // During PDF export partial rendering, provide enough top padding to avoid cutoff
      if (showTitleAndComposer) {
        // First page with title - provide extra padding above title (title is at Y=85)
        // Increased from 200 to 250 to ensure title top is fully captured
        adjustedVerticalOffset = pageHeaderMargin + 350;
      } else {
        // Non-first page - provide extra padding above first row
        // Increased from 50 to 150 to ensure first row top is fully captured
        adjustedVerticalOffset = pageHeaderMargin + 300;
      }
    } else if (currentPageIndex > 0) {
      // Not in partial rendering mode but we're on a non-first page
      adjustedVerticalOffset = verticalOffset + pageHeaderMargin;
    }

    // Calculate cumulative margin offsets for all rows
    Map<int, double> cumulativeMarginOffsets = {};
    if (renderStartRow == null || renderEndRow == null) {
      // Only calculate margins during normal rendering (not partial rendering for PDF export)
      final pageBreaks = PdfExporter.calculatePageBreaks(
          sheetNoteRows, rowSpacing, sheetFormat);

      double cumulativeOffset = 0.0;
      for (int rowIndex = 0; rowIndex < sheetNoteRows.length; rowIndex++) {
        cumulativeMarginOffsets[rowIndex] = cumulativeOffset;

        // Check if this row is at the start of a non-first page (add header margin)
        for (int i = 1; i < pageBreaks.length; i++) {
          final pageInfo = pageBreaks[i];
          if (rowIndex == pageInfo.startRow - 1) {
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
    }

    for (int rowIndex = startRow;
        rowIndex <= endRow && rowIndex < sheetNoteRows.length;
        rowIndex++) {
      // Calculate staff position - for partial rendering, we need to adjust the row positioning
      final int adjustedRowIndex = rowIndex - startRow;

      // Get the cumulative margin offset for this row
      final double additionalMarginOffset =
          cumulativeMarginOffsets[rowIndex] ?? 0.0;

      final staffTop = adjustedVerticalOffset +
          (adjustedRowIndex * (rowSpacing + sheetHeight)) +
          additionalMarginOffset;
      drawStaffLines(canvas, paint, staffTop, lineSpacing, sheetHeight, size);

      // Draw bar number above the start of this row
      _drawBarNumber(canvas, rowIndex, staffTop);

      var tempoTextY = staffTop - 55;

      if (sheetNoteRows[rowIndex].chords.isNotEmpty) {
        for (int i = 0;
            i <
                (3 > sheetNoteRows[rowIndex].chords.length
                    ? sheetNoteRows[rowIndex].chords.length
                    : 3);
            i++) {
          if (sheetNoteRows[rowIndex].chords[i].noteY - 20 <= tempoTextY) {
            tempoTextY = sheetNoteRows[rowIndex].chords[i].noteY - 40;
          }
        }
      }

      // Draw tempo above the left side of this row if set
      _drawTempo(canvas, rowIndex, staffTop, tempoTextY);

      // Draw swing below the tempo if set
      _drawSwing(canvas, rowIndex, staffTop, tempoTextY);

      double x = 85.0;
      double currentRowSpacing = rowSpacingList[rowIndex];

      // Set duration values for notes in this row
      BarLineCalculator.setNoteDurations(sheetNoteRows[rowIndex].chords);

      // Find the applicable time signature for this row
      MusicalNote? timeSignature;

      // First check for time signatures within the current row
      timeSignature = BarLineCalculator.findLastTimeSignature(
          sheetNoteRows[rowIndex].chords);

      // If no time signature found in current row, check previous rows
      if (timeSignature == null && rowIndex > 0) {
        timeSignature = BarLineCalculator.findLastTimeSignatureAcrossRows(
            sheetNoteRows, rowIndex - 1);
      }

      // Track bars and their properties for warning display
      List<
          ({
            int startIndex,
            int endIndex,
            double xStart,
            double xEnd,
            bool isOverfilled
          })> bars = [];
      int barStartIndex = 0;
      double barStartX = 85.0;
      double currentBarDuration = 0.0;
      MusicalNote? currentBarTimeSignature = timeSignature;

      // First pass: identify all bars and their properties
      for (int i = 0; i < sheetNoteRows[rowIndex].chords.length; i++) {
        MusicalNote note = sheetNoteRows[rowIndex].chords[i];
        double currentX = barStartX + ((i - barStartIndex) * currentRowSpacing);

        final double noteY = calculateNoteYMainSheet(
            note.pitch, note.octave, lineSpacing, staffTop);
        note.noteY = noteY;

        if (note.isUpsideDown == null) {
          final double sheetCenter = staffTop + (lineSpacing * 2);
          note.isUpsideDown = noteY <= sheetCenter;
        }

        // Check for time signature changes within the row
        if (note.type == NoteType.timeSignature) {
          currentBarTimeSignature = note;

          // End the previous bar if there was one
          if (i > 0) {
            bool isOverfilled = currentBarTimeSignature != null &&
                BarLineCalculator.hasBarTooManyNotes(
                    currentBarDuration, currentBarTimeSignature);

            bars.add((
              startIndex: barStartIndex,
              endIndex: i - 1,
              xStart: barStartX,
              xEnd: currentX - currentRowSpacing,
              isOverfilled: isOverfilled
            ));
          }

          barStartIndex = i + 1;
          barStartX = currentX + getNoteWidth(note);
          currentBarDuration = 0.0;
          // Removed the continue statement that was causing time signatures to be invisible
        }

        // Check if this is a bar line (either existing or to be added)
        if (note.type == NoteType.bar) {
          // End the current bar
          bool isOverfilled = currentBarTimeSignature != null &&
              BarLineCalculator.hasBarTooManyNotes(
                  currentBarDuration, currentBarTimeSignature);

          bars.add((
            startIndex: barStartIndex,
            endIndex: i - 1,
            xStart: barStartX,
            xEnd: currentX - currentRowSpacing,
            isOverfilled: isOverfilled
          ));

          barStartIndex = i + 1;
          barStartX = currentX + currentRowSpacing;
          currentBarDuration = 0.0;
        } else {
          currentBarDuration += note.duration;
        }
      }

      // Add the final bar if there are notes after the last bar line
      if (barStartIndex < sheetNoteRows[rowIndex].chords.length) {
        double endX =
            85.0 + (sheetNoteRows[rowIndex].chords.length * currentRowSpacing);
        bool isOverfilled = currentBarTimeSignature != null &&
            BarLineCalculator.hasBarTooManyNotes(
                currentBarDuration, currentBarTimeSignature);

        bars.add((
          startIndex: barStartIndex,
          endIndex: sheetNoteRows[rowIndex].chords.length - 1,
          xStart: barStartX,
          xEnd: endX,
          isOverfilled: isOverfilled
        ));
      }

      // Second pass: draw all notes
      x = 85.0; // Reset x position for drawing
      for (int i = 0; i < sheetNoteRows[rowIndex].chords.length; i++) {
        MusicalNote note = sheetNoteRows[rowIndex].chords[i];

        bool isSelected = rowIndex == selectedRow && i == selectedIndex;
        bool inHighlight = selectionRow == rowIndex &&
            selectionStart != null &&
            selectionEnd != null &&
            i >=
                (selectionStart! < selectionEnd!
                    ? selectionStart!
                    : selectionEnd!) &&
            i <=
                (selectionStart! > selectionEnd!
                    ? selectionStart!
                    : selectionEnd!);

        if ((isSelected || inHighlight) && !isReadOnly) {
          paint = Paint()..color = const Color.fromARGB(255, 222, 15, 0);
          noteColour = const Color.fromARGB(255, 222, 15, 0);
        } else {
          paint = Paint()..color = Colors.black;
          noteColour = Colors.black;
        }

        if (note.type == NoteType.keySignature) {
          _drawKeySignature(
              canvas, paint, note, lineSpacing, staffTop, x, noteColour);
        } else {
          drawNote(
              canvas,
              paint,
              note,
              lineSpacing,
              staffTop,
              x,
              sheetNoteRows[rowIndex].chords,
              i,
              currentRowSpacing,
              noteColour,
              keyboardType);
        }

        if (note.isTriplet) {
          _drawTriplet(canvas, paint, x, staffTop, lineSpacing,
              sheetNoteRows[rowIndex].chords, i, currentRowSpacing);
        }

        if (note.dynamicCharacter.isNotEmpty) {
          _drawDynamicCharacter(canvas, note, noteColour, x, staffTop,
              lineSpacing, sheetNoteRows[rowIndex].chords, i);
        }

        if (note.accentCharacter.isNotEmpty) {
          _drawAccentCharacter(canvas, note, noteColour, x, staffTop,
              lineSpacing, sheetNoteRows[rowIndex].chords, i);
        }

        if (note.rehearsalMarking.isNotEmpty) {
          double textY = staffTop - 30;

          for (int x = i; x < i + 3; x++) {
            if (sheetNoteRows[rowIndex].chords.length > x &&
                sheetNoteRows[rowIndex].chords[x].noteY - 10 <= textY) {
              textY = sheetNoteRows[rowIndex].chords[x].noteY - 30;
            }
          }

          _drawRehearsalMarking(
              canvas, note, noteColour, x, staffTop, lineSpacing, textY);
        }

        if (note.type == NoteType.bar) {
          double textY = staffTop - 35;
          int noteLookupIndex = i;

          if (sheetNoteRows[rowIndex].chords.length - 1 >= i + 1) {
            noteLookupIndex = i + 1;
          }
          if (sheetNoteRows[rowIndex].chords.length - 1 >= i + 2) {
            noteLookupIndex = i + 2;
          }
          if (sheetNoteRows[rowIndex].chords.length - 1 >= i + 3) {
            noteLookupIndex = i + 3;
          }

          for (int x = i + 1; x < noteLookupIndex; x++) {
            if (sheetNoteRows[rowIndex].chords[x].noteY - 10 <= textY) {
              textY = sheetNoteRows[rowIndex].chords[x].noteY - 30;
            }
          }

          // Draw bar-level tempo markings above bar notes
          if (note.tempoNumber > 0) {
            _drawBarTempo(canvas, note, x, textY);
          }

          // Draw bar-level swing markings below bar tempo if set
          if (note.swing) {
            _drawBarSwing(canvas, note, x, textY);
          }
        }

        var staffCenter = staffTop + (lineSpacing * 2);

        if (note.isTiedToNext &&
            i < sheetNoteRows[rowIndex].chords.length - 1) {
          double y = calculateNoteYMainSheet(
              note.pitch, note.octave, lineSpacing, staffTop);
          drawTie(canvas, paint, x, staffCenter, x + currentRowSpacing, y);
        }

        if (note.slurEndIndex != null) {
          var slurEndIndex =
              note.slurEndIndex! < sheetNoteRows[rowIndex].chords.length - 1
                  ? note.slurEndIndex!
                  : sheetNoteRows[rowIndex].chords.length - 1;

          double startX = x;
          double startY = calculateNoteYMainSheet(
              note.pitch, note.octave, lineSpacing, staffTop);

          // Calculate endX by accounting for space note spacing
          double endX = 85.0;
          for (int index = 0; index <= slurEndIndex; index++) {
            final currentNote = sheetNoteRows[rowIndex].chords[index];

            if (currentNote.type == NoteType.space && index > 0) {
              bool prevIsSpace =
                  sheetNoteRows[rowIndex].chords[index - 1].type ==
                      NoteType.space;
              endX += prevIsSpace ? currentRowSpacing : 0;
            } else if (currentNote.type != NoteType.space) {
              endX += currentNote.type == NoteType.clef ||
                      currentNote.type == NoteType.timeSignature
                  ? getNoteWidth(currentNote)
                  : currentNote.type == NoteType.keySignature
                      ? getNoteWidth(currentNote) + 10
                      : currentRowSpacing;
            }
          }

          double endY = calculateNoteYMainSheet(
              sheetNoteRows[rowIndex].chords[slurEndIndex].pitch,
              sheetNoteRows[rowIndex].chords[slurEndIndex].octave,
              lineSpacing,
              staffTop);

          drawSlurBetweenNotes(
              canvas,
              paint,
              startX,
              startY,
              endX,
              endY,
              staffTop,
              staffCenter,
              i,
              slurEndIndex,
              noteColour,
              sheetNoteRows[rowIndex].chords,
              0); // spaceNotesCount no longer needed
        }

        if (note.isCrescendoStart && note.crescendoEndIndex != null) {
          var crescendoEndIndex = note.crescendoEndIndex! <
                  sheetNoteRows[rowIndex].chords.length - 1
              ? note.crescendoEndIndex!
              : sheetNoteRows[rowIndex].chords.length - 1;

          // Calculate endX by accounting for space note spacing
          double crescendoEndX = 85.0;
          for (int index = 0; index <= crescendoEndIndex; index++) {
            final currentNote = sheetNoteRows[rowIndex].chords[index];

            if (currentNote.type == NoteType.space && index > 0) {
              bool prevIsSpace =
                  sheetNoteRows[rowIndex].chords[index - 1].type ==
                      NoteType.space;
              crescendoEndX += prevIsSpace ? currentRowSpacing : 0;
            } else if (currentNote.type != NoteType.space) {
              crescendoEndX += currentNote.type == NoteType.clef ||
                      currentNote.type == NoteType.timeSignature
                  ? getNoteWidth(currentNote)
                  : currentNote.type == NoteType.keySignature
                      ? getNoteWidth(currentNote) + 10
                      : currentRowSpacing;
            }
          }

          _drawDynamicMarking(canvas, paint, x, crescendoEndX, staffTop, true,
              i, crescendoEndIndex, sheetNoteRows[rowIndex].chords, rowIndex);
        }

        if (note.isDecrescendoStart && note.decrescendoEndIndex != null) {
          var decrescendoEndIndex = note.decrescendoEndIndex! <
                  sheetNoteRows[rowIndex].chords.length - 1
              ? note.decrescendoEndIndex!
              : sheetNoteRows[rowIndex].chords.length - 1;

          // Calculate endX by accounting for space note spacing
          double decrescendoEndX = 85.0;
          for (int index = 0; index <= decrescendoEndIndex; index++) {
            final currentNote = sheetNoteRows[rowIndex].chords[index];

            if (currentNote.type == NoteType.space && index > 0) {
              bool prevIsSpace =
                  sheetNoteRows[rowIndex].chords[index - 1].type ==
                      NoteType.space;
              decrescendoEndX += prevIsSpace ? currentRowSpacing : 0;
            } else if (currentNote.type != NoteType.space) {
              decrescendoEndX += currentNote.type == NoteType.clef ||
                      currentNote.type == NoteType.timeSignature
                  ? getNoteWidth(currentNote)
                  : currentNote.type == NoteType.keySignature
                      ? getNoteWidth(currentNote) + 10
                      : currentRowSpacing;
            }
          }

          _drawDynamicMarking(
              canvas,
              paint,
              x,
              decrescendoEndX,
              staffTop,
              false,
              i,
              decrescendoEndIndex,
              sheetNoteRows[rowIndex].chords,
              rowIndex);
        }

        // Draw bends for guitar tabs
        if (keyboardType == KeyboardType.guitarTab &&
            note.type == NoteType.fret) {
          // Check for bend
          if (note.isBendStart && note.bendEndIndex != null) {
            var bendEndIndex =
                note.bendEndIndex! < sheetNoteRows[rowIndex].chords.length - 1
                    ? note.bendEndIndex!
                    : sheetNoteRows[rowIndex].chords.length - 1;

            double bendEndX = 85.0;
            for (int index = 1; index <= bendEndIndex; index++) {
              bendEndX += currentRowSpacing;
            }

            // Get string Y position from first child note
            double stringY = staffTop;
            if (note.childNotes != null && note.childNotes!.isNotEmpty) {
              stringY =
                  staffTop + (note.childNotes!.first.octave * lineSpacing);
            }

            _drawBend(canvas, paint, x, bendEndX, stringY, staffTop,
                lineSpacing, noteColour);
          }

          // Check for pre-bend
          if (note.isPreBendStart && note.preBendEndIndex != null) {
            var preBendEndIndex = note.preBendEndIndex! <
                    sheetNoteRows[rowIndex].chords.length - 1
                ? note.preBendEndIndex!
                : sheetNoteRows[rowIndex].chords.length - 1;

            double preBendEndX = 85.0;
            for (int index = 1; index <= preBendEndIndex; index++) {
              preBendEndX += currentRowSpacing;
            }

            // Get string Y position from first child note
            double stringY = staffTop;
            if (note.childNotes != null && note.childNotes!.isNotEmpty) {
              stringY =
                  staffTop + (note.childNotes!.first.octave * lineSpacing);
            }

            _drawPreBend(canvas, paint, x, preBendEndX, stringY, staffTop,
                lineSpacing, noteColour);
          }

          // Check for bend-release
          if (note.isBendReleaseStart && note.bendReleaseEndIndex != null) {
            var bendReleaseEndIndex = note.bendReleaseEndIndex! <
                    sheetNoteRows[rowIndex].chords.length - 1
                ? note.bendReleaseEndIndex!
                : sheetNoteRows[rowIndex].chords.length - 1;

            double bendReleaseEndX = 85.0;
            for (int index = 1; index <= bendReleaseEndIndex; index++) {
              bendReleaseEndX += currentRowSpacing;
            }

            // Get string Y position from first child note
            double stringY = staffTop;
            if (note.childNotes != null && note.childNotes!.isNotEmpty) {
              stringY =
                  staffTop + (note.childNotes!.first.octave * lineSpacing);
            }

            _drawBendRelease(canvas, paint, x, bendReleaseEndX, stringY,
                staffTop, lineSpacing, noteColour);
          }

          // Check for pre-bend-release
          if (note.isPreBendReleaseStart &&
              note.preBendReleaseEndIndex != null) {
            var preBendReleaseEndIndex = note.preBendReleaseEndIndex! <
                    sheetNoteRows[rowIndex].chords.length - 1
                ? note.preBendReleaseEndIndex!
                : sheetNoteRows[rowIndex].chords.length - 1;

            double preBendReleaseEndX = 85.0;
            for (int index = 1; index <= preBendReleaseEndIndex; index++) {
              preBendReleaseEndX += currentRowSpacing;
            }

            // Get string Y position from first child note
            double stringY = staffTop;
            if (note.childNotes != null && note.childNotes!.isNotEmpty) {
              stringY =
                  staffTop + (note.childNotes!.first.octave * lineSpacing);
            }

            _drawPreBendRelease(canvas, paint, x, preBendReleaseEndX, stringY,
                staffTop, lineSpacing, noteColour);
          }
        }

        // Calculate spacing for space notes
        double spaceNoteSpacing = 0;
        if (note.type == NoteType.space && i > 0) {
          // Check if previous note is also a space note
          bool prevIsSpace =
              sheetNoteRows[rowIndex].chords[i - 1].type == NoteType.space;
          // First space note in sequence: no spacing, subsequent: full spacing
          spaceNoteSpacing = prevIsSpace ? currentRowSpacing : 0;
        }

        x += note.type == NoteType.clef || note.type == NoteType.timeSignature
            ? getNoteWidth(note)
            : note.type == NoteType.keySignature
                ? getNoteWidth(note) + 10
                : note.type == NoteType.space
                    ? spaceNoteSpacing
                    : currentRowSpacing;
      }

      // Draw selection highlight for selected notes
      if (selectionRow == rowIndex &&
          selectionStart != null &&
          selectionEnd != null) {
        drawHighlight(canvas, size, rowIndex, staffTop, lineSpacing);
      }

      // Draw row highlight for select rows mode
      if (selectedRowsForCurlyBrace != null &&
          selectedRowsForCurlyBrace!.contains(rowIndex)) {
        _drawRowHighlight(canvas, size, staffTop, lineSpacing);
      }

      // We no longer add automatic bar lines here as it's now handled in CurrentSelectedNoteProvider

      if (rowIndex == selectedRow) {
        // Draw the cursor if showCursor is true and not in read-only mode
        if (showCursor && !isReadOnly) {
          drawInsertionCursor(canvas, paint, staffTop, selectedIndex + 1, size,
              currentRowSpacing, sheetNoteRows[rowIndex].chords, lineSpacing);
        }

        // Find which bar contains the selected note and check if it's overfilled
        for (var bar in bars) {
          if (selectedIndex >= bar.startIndex &&
              selectedIndex <= bar.endIndex &&
              bar.isOverfilled) {
            // Draw warning above the specific bar
            drawTooManyNotesWarning(canvas, staffTop, bar.xStart, bar.xEnd);
            break;
          }
        }
      }

      paint = Paint()..color = Colors.black;
      noteColour = Colors.black;
    }

    // Draw permanent curly braces from saved groups (after all rows are drawn)
    if (curlyBraceGroups.isNotEmpty) {
      _drawPermanentCurlyBraces(
          canvas,
          size,
          lineSpacing,
          adjustedVerticalOffset,
          cumulativeMarginOffsets,
          sheetHeight,
          startRow);
    }

    // Draw connecting elements for connected row formats (piano, grand, etc.)
    _drawConnectedRowElements(canvas, size);
  }

  /// Draw permanent curly braces from saved groups
  void _drawPermanentCurlyBraces(
      Canvas canvas,
      Size size,
      double lineSpacing,
      double adjustedVerticalOffset,
      Map<int, double> cumulativeMarginOffsets,
      double sheetHeight,
      int startRow) {
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
      _drawCurlyBrace(canvas, topY, bottomY, rowCount);
    }
  }

  /// Draw a single curly brace on the left side spanning from topY to bottomY
  void _drawCurlyBrace(
      Canvas canvas, double topY, double bottomY, int rowCount) {
    const double leftX =
        45.0; // Position to the left of staff lines (which start at x=60)
    final double height = bottomY - topY;

    // For 2 rows (piano), draw a single curly brace
    // For 3-5 rows, repeat curly braces to fill the space
    final int braceCount = rowCount == 2 ? 1 : ((rowCount / 2).ceil());
    final double braceHeight = height / braceCount;

    // Use Bravura font character \uE000 for curly brace
    const String braceChar = '\uE000';

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
  void _drawConnectedRowElements(Canvas canvas, Size size) {
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
        _drawConnectedGroup(canvas, size, groupStartRow, groupEndRow,
            adjustedVerticalOffset, cumulativeMarginOffsets, sheetHeight);
      }
    }
  }

  /// Draw connecting elements for a specific group of connected rows
  void _drawConnectedGroup(
      Canvas canvas,
      Size size,
      int groupStartRow,
      int groupEndRow,
      double adjustedVerticalOffset,
      Map<int, double> cumulativeMarginOffsets,
      double sheetHeight) {
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
    _drawSharedBarLines(
        canvas, groupStartRow, groupEndRow, topStaffTop, bottomStaffBottom);

    paint..strokeWidth = 1.0; // Reset stroke width
  }

  /// Draw shared bar lines that connect rows only when bars exist at same index
  void _drawSharedBarLines(Canvas canvas, int groupStartRow, int groupEndRow,
      double topStaffTop, double bottomStaffBottom) {
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
            double x = 85.0;
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
        double barX = rowsWithBarsAtIndex[groupStartRow] ?? 85.0;

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
  void _drawBarNumber(Canvas canvas, int rowIndex, double staffTop) {
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

  /// Draw tempo above the left side of a row if set
  void _drawTempo(
      Canvas canvas, int rowIndex, double staffTop, double tempoTextY) {
    // Check if this row has a tempo set
    final tempo = sheetNoteRows[rowIndex].rowProperties.tempoNumber;
    if (tempo <= 0) {
      return; // Don't draw tempo if it's 0 or negative
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Tempo = ${tempo.round()}bpm',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final double x = 85;

    textPainter.paint(canvas, Offset(x, tempoTextY));
  }

  /// Draw swing below the tempo if set
  void _drawSwing(
      Canvas canvas, int rowIndex, double staffTop, double tempoTextY) {
    // Check if this row has swing set
    final swing = sheetNoteRows[rowIndex].rowProperties.swing;
    if (!swing) {
      return; // Don't draw swing if it's false
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: sheetNoteRows[rowIndex].rowProperties.swingText,
        style: TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final double x = 85;

    textPainter.paint(canvas, Offset(x, tempoTextY + 15));
  }

  /// Draw tempo above a specific bar note
  void _drawBarTempo(
      Canvas canvas, MusicalNote barNote, double x, double textY) {
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
  void _drawBarSwing(
      Canvas canvas, MusicalNote barNote, double x, double textY) {
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
  void _drawPageBreaks(Canvas canvas, Size size) {
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

  void _drawTitleAndComposer(Canvas canvas, Size size) {
    // Calculate title and composer Y positions based on whether we're in PDF export mode
    double titleY = 50;
    double composerY = 90;

    // During PDF export with partial rendering, coordinate title position with staff content
    if (renderStartRow != null &&
        renderEndRow != null &&
        showTitleAndComposer) {
      // Position title and composer relative to where the staff content will start
      // Leave space at the top, then title, then composer, then space before first staff
      titleY = 140; // Position same as normal rendering
      composerY = 175; // Position same as normal rendering
    }

    if (title.isNotEmpty) {
      final titlePainter = TextPainter(
        text: TextSpan(
          text: title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      titlePainter.layout(minWidth: 0, maxWidth: size.width);
      final titleX = (size.width - titlePainter.width) / 2;
      titlePainter.paint(canvas, Offset(titleX, titleY));
    }

    if (composer.isNotEmpty) {
      final composerPainter = TextPainter(
        text: TextSpan(
          text: 'By $composer',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      composerPainter.layout(minWidth: 0, maxWidth: size.width);
      final composerX = (size.width - composerPainter.width) / 2;
      composerPainter.paint(canvas, Offset(composerX, composerY));
    }
  }

  /// Calculate the required background height based on page breaks
  double _calculateRequiredBackgroundHeight(Size size) {
    // Only apply this logic when not in partial rendering mode (i.e., normal display mode)
    if (renderStartRow != null || renderEndRow != null) {
      return size.height; // Use original size during PDF export
    }

    // Calculate page breaks using the same logic as PDF export
    final pageBreaks =
        PdfExporter.calculatePageBreaks(sheetNoteRows, rowSpacing, sheetFormat);

    // If only one page, use the original size
    if (pageBreaks.length <= 1) {
      return size.height;
    }

    // Calculate total height needed for all pages
    const double a4Height = 1700; // Same as PDF exporter constant
    double totalHeight = pageBreaks.length * a4Height;

    // Use the larger of the calculated height or original size
    return totalHeight > size.height ? totalHeight : size.height;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;

  void drawStaffLines(Canvas canvas, Paint paint, double staffTop,
      double lineSpacing, double sheetHeight, Size size) {
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
      double lineSpacing) {
    if (selectionStart != null &&
        selectionEnd != null &&
        selectionRow != null) {
      return;
    }
    // Calculate cursor X position using the new note width calculator
    double cursorX = notes.isEmpty
        ? 85.0
        : calculateXPositionForIndex(
            insertionIndex - 1, notes, rowSpacing, false);

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

  void drawTie(Canvas canvas, Paint paint, double startX, double staffCentre,
      double endX, double y) {
    Path path = Path();
    double controlY = y >= staffCentre ? y + 30 : y - 30;
    y = y >= staffCentre ? y + 10 : y - 10;

    path.moveTo(startX + 5, y);
    path.quadraticBezierTo((startX + endX) / 2, controlY, endX - 5, y);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;

    canvas.drawPath(path, paint);
  }

  void drawSlur(Canvas canvas, Paint paint, double startX, double startY,
      double endX, double endY, double staffCentre) {
    Path path = Path();
    //pass in start index and end index so I can work out how large to make the curve.

    double controlY = (startY < endY) ? startY - 40 : startY + 40;
    startY = startY >= staffCentre ? startY + 10 : startY - 10;
    endY = startY >= staffCentre ? endY + 10 : endY - 10;

    path.moveTo(startX + 5, startY);
    path.quadraticBezierTo((startX + endX) / 2, controlY, endX - 5, endY);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;

    canvas.drawPath(path, paint);
  }

  void drawSlurBetweenNotes(
      Canvas canvas,
      Paint paint,
      double startX,
      double startY,
      double endX,
      double endY,
      double staffTop,
      double staffCentre,
      int startIndex,
      int endIndex,
      Color color,
      List<MusicalNote> rowNotes,
      int spaceNotesCount) {
    // Ensure left-to-right direction
    final int minIndex = startIndex < endIndex ? startIndex : endIndex;
    final int maxIndex = startIndex > endIndex ? startIndex : endIndex;

    // Determine if the slur should be above or below based on note positions
    // If most notes are above the staff center, slur should be below, and vice versa
    int notesAboveCenter = 0;
    int notesBelowCenter = 0;

    for (int i = minIndex; i <= maxIndex; i++) {
      final note = rowNotes[i];
      if (note.type != NoteType.space) {
        if (note.noteY > staffCentre) {
          notesAboveCenter++;
        } else {
          notesBelowCenter++;
        }
      }
    }

    final bool isSlurAbove = notesBelowCenter >= notesAboveCenter;

    // Apply vertical offset based on slur position - increase for better clearance
    startY = isSlurAbove ? startY - 12 : startY + 12;
    endY = isSlurAbove ? endY - 12 : endY + 12;

    final Offset start = Offset(startX, startY);
    final Offset end = Offset(endX, endY);

    // Start with a moderate base curve height
    double curveHeight = 30;

    int noteSpan = ((maxIndex - minIndex) - spaceNotesCount)
        .clamp(1, rowNotes.length - spaceNotesCount);
    double horizontalDistance = (endX - startX).abs();

    // Define note head size (approximate)
    const double noteHeadHeight = 10.0;
    const double noteHeadWidth = 12.0;

    // Track obstacles for optimal control point placement
    List<
        ({
          double x,
          double y,
          double width,
          double height,
          bool? isUpsideDown,
          bool isStem,
          double obstacleTop,
          double obstacleBottom
        })> obstacles = [];

    bool hasUpsideDownStems = false;
    bool hasDownwardStems = false;

    // Find the extreme Y positions of all intermediate notes to ensure proper clearance
    double highestNoteY = double.infinity;
    double lowestNoteY = double.negativeInfinity;
    double highestStemY = double.infinity;
    double lowestStemY = double.negativeInfinity;

    // First pass: identify all obstacles (note heads and stems) and find extremes
    for (int i = minIndex; i <= maxIndex; i++) {
      final note = rowNotes[i];
      if (note.type != NoteType.space) {
        var spaceCount = 0;

        for (int index = minIndex; index <= i; index++) {
          final noteCurrent = rowNotes[index];
          if (noteCurrent.type == NoteType.space) {
            spaceCount++;
          }
        }

        // Calculate note X position more accurately
        double noteX = startX +
            ((i - minIndex - spaceCount) / noteSpan) * horizontalDistance;

        // Track extreme note positions
        highestNoteY = math.min(highestNoteY, note.noteY);
        lowestNoteY = math.max(lowestNoteY, note.noteY);

        // Add note head as an obstacle (all notes have heads)
        double noteHeadTop = note.noteY - (noteHeadHeight / 2);
        double noteHeadBottom = note.noteY + (noteHeadHeight / 2);

        obstacles.add((
          x: noteX,
          y: note.noteY,
          width: noteHeadWidth,
          height: noteHeadHeight,
          isUpsideDown: false,
          isStem: false,
          obstacleTop: noteHeadTop,
          obstacleBottom: noteHeadBottom
        ));

        // Skip stem calculation for notes that don't have stems
        if (note.type == NoteType.whole ||
            note.type == NoteType.rest ||
            note.type == NoteType.clef ||
            note.type == NoteType.bar ||
            note.type == NoteType.accidental ||
            note.type == NoteType.timeSignature ||
            note.type == NoteType.keySignature ||
            note.type == NoteType.accidental ||
            note.type == NoteType.space) {
          continue;
        }

        // Determine if the note's stem is upside down (pointing up)
        if (note.isUpsideDown == true) {
          hasUpsideDownStems = true;
        } else {
          hasDownwardStems = true;
        }

        // Calculate stem height based on note type and connected status
        double stemHeight = 35.0; // Base stem height

        // Adjust stem height for 32nd or 64th notes
        if (note.type == NoteType.thirtySecond ||
            note.type == NoteType.sixtyFourth) {
          stemHeight += 10.0;
        }

        // For connected notes, calculate more accurate stem height
        if ((note.type == NoteType.eighth ||
                note.type == NoteType.sixteenth ||
                note.type == NoteType.thirtySecond ||
                note.type == NoteType.sixtyFourth) &&
            note.isBeamed) {
          // Get the connected notes group to determine actual stem height
          var notesGroup = getConnectedNotesGroup(i, rowNotes);
          var connectedNotesGroup = notesGroup.notesGroup;
          bool firstNoteUpsideDown = false;

          if (connectedNotesGroup.isNotEmpty) {
            var notesGroupYs = getConnectedNotesGroupHighestY(
                connectedNotesGroup, 10.0, staffTop, staffCentre);

            double connectedGroupHighestY = notesGroupYs.highestY;
            double connectedGroupLowestY = notesGroupYs.lowestY;
            firstNoteUpsideDown = notesGroupYs.firstNoteY < staffCentre;

            // Adjust stem height based on the connected group
            if (!firstNoteUpsideDown) {
              stemHeight = (note.noteY - connectedGroupHighestY) + stemHeight;
            } else {
              stemHeight = (connectedGroupLowestY - note.noteY) + stemHeight;
            }

            // Add buffer for complex connected notes
            if (notesGroupYs.doesGroupContain32ndOr64thNote) {
              stemHeight += 30.0;
            }
          }
        }

        // Add a safety buffer to stem height
        stemHeight += 30.0;

        // Calculate stem position and dimensions
        double stemX = note.isUpsideDown == true ? noteX - 5.0 : noteX + 5.0;
        double stemWidth = 1.5; // Stem width
        double stemTop, stemBottom;

        if (note.isUpsideDown == true) {
          // Stem points up
          stemTop = note.noteY - stemHeight;
          stemBottom = note.noteY;
          // Track extreme stem positions
          highestStemY = math.min(highestStemY, stemTop);
        } else {
          // Stem points down
          stemTop = note.noteY;
          stemBottom = note.noteY + stemHeight;
          // Track extreme stem positions
          lowestStemY = math.max(lowestStemY, stemBottom);
        }

        // Add stem as an obstacle
        obstacles.add((
          x: stemX,
          y: note.noteY,
          width: stemWidth,
          height: stemHeight,
          isUpsideDown: note.isUpsideDown,
          isStem: true,
          obstacleTop: stemTop,
          obstacleBottom: stemBottom
        ));
      }
    }

    // Calculate minimum curve height to clear ALL intermediate notes and stems
    double minRequiredCurveHeight = 60.0; // Increased base minimum

    if (isSlurAbove) {
      // Slur goes above notes - find the highest point (lowest Y value) and add clearance
      double highestPoint = highestNoteY;
      if (highestStemY != double.infinity) {
        highestPoint = math.min(highestPoint, highestStemY);
      }

      // For slurs above, we need to ensure the control point is well above the highest obstacle
      // The control point should be at least 40px above the highest point
      double requiredControlY = highestPoint - 40.0;
      double slurMidY = (start.dy + end.dy) / 2;

      // Calculate how much curve height we need to reach that control point
      minRequiredCurveHeight =
          math.max(minRequiredCurveHeight, slurMidY - requiredControlY);

      // Additional clearance for upward stems
      if (hasUpsideDownStems) {
        minRequiredCurveHeight += 20.0;
      }
    } else {
      // Slur goes below notes - find the lowest point (highest Y value) and add clearance
      double lowestPoint = lowestNoteY;
      if (lowestStemY != double.negativeInfinity) {
        lowestPoint = math.max(lowestPoint, lowestStemY);
      }

      // For slurs below, we need to ensure the control point is well below the lowest obstacle
      // The control point should be at least 40px below the lowest point
      double requiredControlY = lowestPoint + 40.0;
      double slurMidY = (start.dy + end.dy) / 2;

      // Calculate how much curve height we need to reach that control point
      minRequiredCurveHeight =
          math.max(minRequiredCurveHeight, requiredControlY - slurMidY);

      // Additional clearance for downward stems
      if (hasDownwardStems) {
        minRequiredCurveHeight += 20.0;
      }
    }

    // Set curve height to at least the minimum required
    curveHeight = math.max(curveHeight, minRequiredCurveHeight);

    // Find the most problematic obstacle for control point positioning
    double maxObstacleImpact = 0;
    double obstaclePositionRatio = 0.5; // Default to center

    for (var obstacle in obstacles) {
      // Calculate where this obstacle is along the x-axis (0.0 = start, 1.0 = end)
      double positionRatio = (obstacle.x - startX) / horizontalDistance;
      positionRatio = positionRatio.clamp(0.0, 1.0);

      // Calculate the impact of this obstacle
      double impact = 0;

      if (obstacle.isStem) {
        // Stems have higher impact when they're in the slur's path
        if (isSlurAbove && obstacle.isUpsideDown == true) {
          // For upward stems when slur is above
          impact = obstacle.height * 1.5;
        } else if (!isSlurAbove && obstacle.isUpsideDown == false) {
          // For downward stems when slur is below
          impact = obstacle.height * 1.5;
        }
      } else {
        // Note heads have impact regardless of slur position
        impact = obstacle.height;
      }

      // If this obstacle has more impact than previous ones
      if (impact > maxObstacleImpact) {
        maxObstacleImpact = impact;
        // Shift control point slightly away from the obstacle
        obstaclePositionRatio =
            positionRatio > 0.5 ? positionRatio - 0.2 : positionRatio + 0.2;
        obstaclePositionRatio = obstaclePositionRatio.clamp(
            0.3, 0.7); // Keep within reasonable bounds
      }
    }

    // Calculate control point for the Bezier curve
    double controlX = startX + (horizontalDistance * obstaclePositionRatio);
    double controlY = (start.dy + end.dy) / 2;

    // Apply curve height with height multiplier for longer distances
    double heightMultiplier = 1.0 + (horizontalDistance / 500);
    heightMultiplier = heightMultiplier.clamp(1.0, 1.5);

    controlY += isSlurAbove
        ? -curveHeight * heightMultiplier
        : curveHeight * heightMultiplier;

    // Configurable parameters for slur appearance
    const double minBufferSpace = 25.0; // Minimum space above/below notes
    const double maxSlurHeight =
        180.0; // Maximum slur height to prevent overlap with other rows

    // Force the slur to have proper clearance above or below ALL obstacles
    if (isSlurAbove) {
      // Force the slur to be well above ALL obstacles
      double highestObstacle = highestNoteY;
      if (highestStemY != double.infinity) {
        highestObstacle = math.min(highestObstacle, highestStemY);
      }

      // Force control point to be at least minBufferSpace above the highest obstacle
      double forcedControlY = highestObstacle - minBufferSpace;
      controlY = math.min(controlY, forcedControlY);

      // Apply maximum height limit to prevent overlap with other rows
      double maxAllowedY = staffCentre - maxSlurHeight;
      controlY = math.max(controlY, maxAllowedY);
    } else {
      // Force the slur to be well below ALL obstacles
      double lowestObstacle = lowestNoteY;
      if (lowestStemY != double.negativeInfinity) {
        lowestObstacle = math.max(lowestObstacle, lowestStemY);
      }

      // Force control point to be at least minBufferSpace below the lowest obstacle
      double forcedControlY = lowestObstacle + minBufferSpace;
      controlY = math.max(controlY, forcedControlY);

      // Apply maximum height limit to prevent overlap with other rows
      double maxAllowedY = staffCentre + maxSlurHeight;
      controlY = math.min(controlY, maxAllowedY);
    }

    Offset control = Offset(controlX, controlY);

    // Final validation: Generate curve points and verify clearance
    List<Offset> bezierPoints = [];
    const int segments = 100;

    // Generate points along the curve for validation
    for (int i = 0; i <= segments; i++) {
      double t = i / segments;
      double x = (1 - t) * (1 - t) * start.dx +
          2 * (1 - t) * t * control.dx +
          t * t * end.dx;
      double y = (1 - t) * (1 - t) * start.dy +
          2 * (1 - t) * t * control.dy +
          t * t * end.dy;
      bezierPoints.add(Offset(x, y));
    }

    // Final check for intersections and adjust if needed
    bool hasIntersection;
    int maxIterations =
        5; // Reduced iterations since we pre-calculated clearance
    int iteration = 0;

    do {
      hasIntersection = false;
      iteration++;

      // Check each obstacle against the curve
      for (var obstacle in obstacles) {
        // For stems, check if the curve intersects the stem line
        if (obstacle.isStem) {
          double stemX = obstacle.x;
          double stemTop = obstacle.obstacleTop;
          double stemBottom = obstacle.obstacleBottom;

          // Find the closest point on the curve to this stem's x-coordinate
          Offset? closestPoint;
          double minDistance = double.infinity;

          for (var point in bezierPoints) {
            double distance = (point.dx - stemX).abs();
            if (distance < minDistance) {
              minDistance = distance;
              closestPoint = point;
            }
          }

          if (closestPoint != null && minDistance < 5.0) {
            // Check if this point intersects with the stem
            bool intersects = false;

            if (isSlurAbove && obstacle.isUpsideDown == true) {
              // For upward stems when slur is above
              intersects =
                  closestPoint.dy > stemTop && closestPoint.dy < stemBottom;
            } else if (!isSlurAbove && obstacle.isUpsideDown == false) {
              // For downward stems when slur is below
              intersects =
                  closestPoint.dy > stemTop && closestPoint.dy < stemBottom;
            }

            if (intersects) {
              hasIntersection = true;
              // Increase curve height to avoid this stem
              curveHeight += 10.0;
              break;
            }
          }
        }
        // For note heads, check if the curve passes through the note head
        else {
          double noteHeadLeft = obstacle.x - (obstacle.width / 2);
          double noteHeadRight = obstacle.x + (obstacle.width / 2);
          double noteHeadTop = obstacle.obstacleTop;
          double noteHeadBottom = obstacle.obstacleBottom;

          // Check if any point on the curve intersects with this note head
          for (var point in bezierPoints) {
            if (point.dx >= noteHeadLeft &&
                point.dx <= noteHeadRight &&
                point.dy >= noteHeadTop &&
                point.dy <= noteHeadBottom) {
              hasIntersection = true;
              // Increase curve height to avoid this note head
              curveHeight += 8.0;
              break;
            }
          }

          if (hasIntersection) break;
        }
      }

      if (hasIntersection) {
        // Recalculate control point with new curve height
        controlY = (start.dy + end.dy) / 2;
        controlY += isSlurAbove
            ? -curveHeight * heightMultiplier
            : curveHeight * heightMultiplier;

        // Re-apply our forced positioning to maintain buffer space
        if (isSlurAbove) {
          double highestObstacle = highestNoteY;
          if (highestStemY != double.infinity) {
            highestObstacle = math.min(highestObstacle, highestStemY);
          }
          double forcedControlY = highestObstacle - minBufferSpace;
          controlY = math.min(controlY, forcedControlY);

          // Apply maximum height limit
          double maxAllowedY = staffCentre - maxSlurHeight;
          controlY = math.max(controlY, maxAllowedY);
        } else {
          double lowestObstacle = lowestNoteY;
          if (lowestStemY != double.negativeInfinity) {
            lowestObstacle = math.max(lowestObstacle, lowestStemY);
          }
          double forcedControlY = lowestObstacle + minBufferSpace;
          controlY = math.max(controlY, forcedControlY);

          // Apply maximum height limit
          double maxAllowedY = staffCentre + maxSlurHeight;
          controlY = math.min(controlY, maxAllowedY);
        }

        control = Offset(controlX, controlY);

        // Regenerate bezier points
        bezierPoints.clear();
        for (int i = 0; i <= segments; i++) {
          double t = i / segments;
          double x = (1 - t) * (1 - t) * start.dx +
              2 * (1 - t) * t * control.dx +
              t * t * end.dx;
          double y = (1 - t) * (1 - t) * start.dy +
              2 * (1 - t) * t * control.dy +
              t * t * end.dy;
          bezierPoints.add(Offset(x, y));
        }
      }
    } while (hasIntersection && iteration < maxIterations);

    // Draw the slur
    drawVariableThicknessBezier(
      canvas: canvas,
      start: start,
      control: control,
      end: end,
      maxThickness: 3,
      color: color,
    );
  }

  /// Draw highlight for entire row in select rows mode
  void _drawRowHighlight(
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

  void drawHighlight(Canvas canvas, Size size, int rowIndex, double staffTop,
      double lineSpacing) {
    if (selectionStart == null ||
        selectionEnd == null ||
        selectionRow == null) {
      return;
    }

    final rowNotes = sheetNoteRows[selectionRow!].chords;
    if (rowNotes.isEmpty) {
      return;
    }

    final int start =
        selectionStart! < selectionEnd! ? selectionStart! : selectionEnd!;
    final int end =
        selectionStart! > selectionEnd! ? selectionStart! : selectionEnd!;

    final double startX = calculateXPositionForIndex(
        start, rowNotes, rowSpacingList[rowIndex], true);
    final double endX = calculateXPositionForIndex(
        end, rowNotes, rowSpacingList[rowIndex], false);

    double min_y = double.infinity;
    double max_y = double.negativeInfinity;

    for (int i = start; i <= end; i++) {
      final note = rowNotes[i];
      double y = note.noteY;
      min_y = math.min(min_y, y - 15);
      max_y = math.max(max_y, y + 15);

      if (note.type == NoteType.rest ||
          note.type == NoteType.clef ||
          note.type == NoteType.bar ||
          note.type == NoteType.accidental ||
          note.type == NoteType.timeSignature ||
          note.type == NoteType.keySignature ||
          note.type == NoteType.accidental ||
          note.type == NoteType.space) {
        min_y = staffTop - 25;
        max_y = staffTop + (lineSpacing * 4) + 25;
      }

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
          min_y = math.min(min_y, y + stemHeight);
        } else {
          max_y = math.max(max_y, y - stemHeight);
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

  void drawVariableThicknessBezier({
    required Canvas canvas,
    required Offset start,
    required Offset control,
    required Offset end,
    required double maxThickness,
    required Color color,
  }) {
    const int segments = 300; // More segments = smoother curve
    final path = Path();

    // Store left and right edge of the stroke
    List<Offset> leftPoints = [];
    List<Offset> rightPoints = [];

    for (int i = 0; i <= segments; i++) {
      double t = i / segments;

      // Bézier curve formula
      double x = (1 - t) * (1 - t) * start.dx +
          2 * (1 - t) * t * control.dx +
          t * t * end.dx;
      double y = (1 - t) * (1 - t) * start.dy +
          2 * (1 - t) * t * control.dy +
          t * t * end.dy;
      Offset point = Offset(x, y);

      // Tangent vector
      double dx =
          2 * (1 - t) * (control.dx - start.dx) + 2 * t * (end.dx - control.dx);
      double dy =
          2 * (1 - t) * (control.dy - start.dy) + 2 * t * (end.dy - control.dy);
      vec.Vector2 tangent = vec.Vector2(dx, dy).normalized();

      // Normal vector (perpendicular to tangent)
      vec.Vector2 normal = vec.Vector2(-tangent.y, tangent.x);

      // Thickness tapers in and out toward center
      double thickness =
          maxThickness * (1 - ((t - 0.5) * 2).abs()); // triangle shape taper

      vec.Vector2 offset = normal.scaled(thickness / 2);
      Offset left = point + Offset(offset.x, offset.y);
      Offset right = point - Offset(offset.x, offset.y);

      leftPoints.add(left);
      rightPoints.add(right);
    }

    // Draw thick curve as a filled path
    path.addPolygon(leftPoints, false);
    path.addPolygon(rightPoints.reversed.toList(), true); // Close the shape

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..strokeWidth = 1.0,
    );
  }

  double endXForIndex(int index, double currentRowSpacing) {
    return 85.0 + (index * currentRowSpacing);
  }

  void _drawDynamicCharacter(
      Canvas canvas,
      MusicalNote note,
      Color noteColour,
      double x,
      double staffTop,
      double lineSpacing,
      List<MusicalNote> notes,
      int noteIndex) {
    final textStyle = TextStyle(
      color: noteColour,
      fontSize: 30,
      fontFamily: 'Bravura',
    );
    final textSpan = TextSpan(
      text: note.dynamicCharacter,
      style: textStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    double lowestY = double.negativeInfinity;
    bool hasUpsideDownNoteOnStaff = false;

    if (note.noteY > lowestY) {
      lowestY = note.noteY;
    }
    if (note.isUpsideDown == true && note.noteY >= staffTop) {
      hasUpsideDownNoteOnStaff = true;
    }

    double staffBottomLineY = staffTop + 40; // 4 lines * 10 spacing
    double minDynamicY = staffBottomLineY + 20;
    double yPos = math.max(lowestY + 50, minDynamicY);

    if (hasUpsideDownNoteOnStaff) {
      yPos += 20;
    }

    double xPos = x - (textPainter.width / 2);

    if (note.accentCharacter != "" && note.isUpsideDown == false) {
      yPos = yPos + 10;
    }

    textPainter.paint(canvas, Offset(xPos, yPos - 60));
  }

  void _drawAccentCharacter(
      Canvas canvas,
      MusicalNote note,
      Color noteColour,
      double x,
      double staffTop,
      double lineSpacing,
      List<MusicalNote> notes,
      int noteIndex) {
    final textStyle = TextStyle(
      color: noteColour,
      fontSize: 30,
      fontFamily: 'Bravura',
    );
    final textSpan = TextSpan(
      text: note.accentCharacter,
      style: textStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    double yPos;
    double xPos = x - (textPainter.width / 2);
    bool isUpsideDownNote = note.isUpsideDown == true;

    // Handle beamed notes special case
    if (note.isBeamed) {
      var notesGroup = getConnectedNotesGroup(noteIndex, notes);
      var connectedNotesGroup = notesGroup.notesGroup;

      if (connectedNotesGroup.isNotEmpty) {
        isUpsideDownNote = connectedNotesGroup.first.isUpsideDown == true;
      }

      double staffBottomLineY = staffTop + (lineSpacing * 4);
      double distanceFromStaff = isUpsideDownNote
          ? (staffTop - note.noteY).abs()
          : (note.noteY - staffBottomLineY).abs();

      if (distanceFromStaff > 30) {
        // Position accent at ~30 pixels from note, between staff lines
        if (isUpsideDownNote) {
          // For upside-down notes, accent goes above
          yPos = note.noteY - 85;
          // Adjust to position between staff lines (staff lines are at 0, 10, 20, 30, 40)

          double relativeToStaff = yPos - staffTop;
          double nearestStaffLine =
              (relativeToStaff / lineSpacing).round() * lineSpacing;
          if ((relativeToStaff - nearestStaffLine).abs() < 3) {
            yPos = staffTop + nearestStaffLine; // Move between lines
          }
        } else {
          // For normal notes, accent goes below
          yPos = note.noteY - 45;
          // Adjust to position between staff lines

          double relativeToStaff = yPos - staffTop;
          double nearestStaffLine =
              (relativeToStaff / lineSpacing).round() * lineSpacing;
          if ((relativeToStaff - nearestStaffLine).abs() < 3) {
            yPos = staffTop + nearestStaffLine; // Move between lines
          }
        }

        textPainter.paint(canvas, Offset(xPos, yPos + 0.5));
        return;
      }
    }

    if (isUpsideDownNote) {
      double maxAccentY = staffTop;
      double baseYPos = note.noteY - 1;

      if (note.noteY <= staffTop - 10) {
        baseYPos -= 5;
      }

      yPos = math.min(baseYPos, maxAccentY);

      yPos = yPos - 75;
    } else {
      double staffBottomLineY = staffTop + 40; // 4 lines * 10 spacing
      double minAccentY = staffBottomLineY;
      double baseYPos = note.noteY + 1;

      if (note.noteY >= staffBottomLineY + 10) {
        baseYPos += 5;
      }

      yPos = math.max(baseYPos, minAccentY);
      yPos = yPos - 55;
    }

    textPainter.paint(canvas, Offset(xPos, yPos));
  }

  void _drawDynamicMarking(
      Canvas canvas,
      Paint paint,
      double startX,
      double endX,
      double staffTop,
      bool isCrescendo,
      int startIndex,
      int endIndex,
      List<MusicalNote> notes,
      int rowIndex) {
    if (startIndex == endIndex || endX < startX || endIndex >= notes.length) {
      endX = startX + 10;
    }

    // Offset logic
    if (notes[startIndex].dynamicCharacter.isNotEmpty) {
      startX += 20;
    }
    if (notes[startIndex] == notes[endIndex]) {
      endX += 20;
    } else if (notes[endIndex].dynamicCharacter.isNotEmpty) {
      endX -= 20;
    }

    double lowestY = double.negativeInfinity;
    bool hasUpsideDownNoteOnStaff = false;
    for (int i = startIndex; i <= endIndex; i++) {
      if (notes[i].type != NoteType.space) {
        if (notes[i].noteY > lowestY) {
          lowestY = notes[i].noteY;
        }
        if (notes[i].isUpsideDown == true && notes[i].noteY >= staffTop) {
          hasUpsideDownNoteOnStaff = true;
        }
      }
    }

    double staffBottomLineY = staffTop + 40; // 4 lines * 10 spacing
    double minDynamicY = staffBottomLineY + 20;
    double y = math.max(lowestY + 50, minDynamicY);

    if (hasUpsideDownNoteOnStaff) {
      y += 20;
    }

    double openWidth = 15.0;
    Path path = Path();

    if (isCrescendo) {
      path.moveTo(startX, y);
      path.lineTo(endX, y - openWidth / 2);
      path.moveTo(startX, y);
      path.lineTo(endX, y + openWidth / 2);
    } else {
      path.moveTo(startX, y - openWidth / 2);
      path.lineTo(endX, y);
      path.moveTo(startX, y + openWidth / 2);
      path.lineTo(endX, y);
    }

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawPath(path, paint);

    if (editingDynamicRow == rowIndex && editingDynamicIndex == startIndex) {
      final Paint handlePaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(endX + 10, y), 10, handlePaint);
    }
  }

  void _drawArrowHead(Canvas canvas, Paint paint, double peakX, double peakY,
      double arrowSize, String labelText, Color noteColour, bool isUpArrow) {
    Paint arrowPaint = paint;
    arrowPaint.style = PaintingStyle.fill;
    arrowPaint.color = noteColour;
    arrowPaint.isAntiAlias = true;

    final Path arrowHead = Path();
    if (isUpArrow) {
      peakY = peakY - 5;
      arrowHead.moveTo(peakX, peakY);
      arrowHead.lineTo(peakX - arrowSize, peakY + arrowSize);
      arrowHead.lineTo(peakX + arrowSize, peakY + arrowSize);
      arrowHead.close();
    } else {
      peakY = peakY + 5;
      arrowHead.moveTo(peakX, peakY);
      arrowHead.lineTo(peakX - arrowSize, peakY - arrowSize);
      arrowHead.lineTo(peakX + arrowSize, peakY - arrowSize);
      arrowHead.close();
    }

    canvas.drawPath(arrowHead, arrowPaint);

    if (isUpArrow) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(
            color: noteColour,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(peakX - textPainter.width / 2, peakY - 20));
    }
  }

  /// Draw bend arrow (single upward arrow with "full" label)
  void _drawBend(Canvas canvas, Paint paint, double startX, double endX,
      double stringY, double staffTop, double lineSpacing, Color noteColour) {
    // Calculate peak position above the staff
    final double peakY = staffTop - 30;
    final double arrowSize = 6.0;

    // Draw curved line from start to peak - curve bulges downward under the arrow
    final Path path = Path();
    path.moveTo(startX, stringY);
    path.quadraticBezierTo((startX + endX) / 2, peakY + 40, endX, peakY);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawPath(path, paint);

    // Draw arrowhead and label at peak
    _drawArrowHead(
        canvas, paint, endX, peakY, arrowSize, 'full', noteColour, true);
  }

  /// Draw pre-bend arrow (single upward arrow with "1/2" label)
  void _drawPreBend(Canvas canvas, Paint paint, double startX, double endX,
      double stringY, double staffTop, double lineSpacing, Color noteColour) {
    // Calculate peak position above the staff
    final double peakY = staffTop - 30;
    final double arrowSize = 6.0;
    startX = startX + 5;
    endX = endX - 5;

    // Draw curved line from start to peak - curve bulges downward under the arrow
    final Path path = Path();
    path.moveTo(startX, stringY);
    path.quadraticBezierTo((startX + endX) / 2, peakY + 40, endX, peakY);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawPath(path, paint);

    // Draw arrowhead and label at peak
    _drawArrowHead(
        canvas, paint, endX, peakY, arrowSize, '1/2', noteColour, true);
  }

  /// Draw bend-release arrow (up then down with "full" label)
  void _drawBendRelease(Canvas canvas, Paint paint, double startX, double endX,
      double stringY, double staffTop, double lineSpacing, Color noteColour) {
    // Calculate peak position above the staff
    final double peakY = staffTop - 30;
    final double peakX = startX + (endX - startX) * 0.5;
    final double arrowSize = 6.0;

    // Draw curved line from start to peak - curve bulges downward under the arrow
    final Path upPath = Path();
    upPath.moveTo(startX, stringY);
    upPath.quadraticBezierTo(
        startX + (peakX - startX) * 0.5, peakY + 40, peakX, peakY);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawPath(upPath, paint);

    // Draw curved line from peak back down to end
    final Path downPath = Path();
    downPath.moveTo(peakX, peakY);
    downPath.quadraticBezierTo(
        peakX + (endX - peakX) * 0.5, peakY + 10, endX, stringY);
    canvas.drawPath(downPath, paint);

    // Draw "full" label at peak
    _drawArrowHead(
        canvas, paint, peakX, peakY, arrowSize, 'full', noteColour, true);
    _drawArrowHead(
        canvas, paint, endX, stringY, arrowSize, 'full', noteColour, false);
  }

  /// Draw pre-bend-release arrow (up then down with "1/2" label)
  void _drawPreBendRelease(
      Canvas canvas,
      Paint paint,
      double startX,
      double endX,
      double stringY,
      double staffTop,
      double lineSpacing,
      Color noteColour) {
    // Calculate peak position above the staff
    final double peakY = staffTop - 30;
    final double peakX = startX + (endX - startX) * 0.5;
    final double arrowSize = 6.0;

    // Draw curved line from start to peak - curve bulges downward under the arrow
    final Path upPath = Path();
    upPath.moveTo(startX, stringY);
    upPath.quadraticBezierTo(
        startX + (peakX - startX) * 0.5, peakY + 40, peakX, peakY);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawPath(upPath, paint);

    // Draw curved line from peak back down to end
    final Path downPath = Path();
    downPath.moveTo(peakX, peakY);
    downPath.quadraticBezierTo(
        peakX + (endX - peakX) * 0.5, peakY + 10, endX, stringY);
    canvas.drawPath(downPath, paint);

    // Draw "1/2" label at peak
    _drawArrowHead(
        canvas, paint, peakX, peakY, arrowSize, '1/2', noteColour, true);
    _drawArrowHead(
        canvas, paint, endX, stringY, arrowSize, '1/2', noteColour, false);
  }

  /// Draw rehearsal marking above the staff at the note's position
  void _drawRehearsalMarking(Canvas canvas, MusicalNote note, Color noteColour,
      double x, double staffTop, double lineSpacing, double yPos) {
    // Determine if this is a unicode character (from Bravura font)
    final bool isUnicode =
        note.rehearsalMarking == '\uE047' || note.rehearsalMarking == '\uE048';

    final textStyle = TextStyle(
      color: noteColour,
      fontSize: isUnicode ? 32 : 20,
      fontFamily: isUnicode ? 'Bravura' : null,
      fontStyle: isUnicode ? FontStyle.normal : FontStyle.italic,
      fontWeight: isUnicode ? FontWeight.w200 : FontWeight.w600,
    );

    final textSpan = TextSpan(
      text: note.rehearsalMarking,
      style: textStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Center the text horizontally over the note
    double xPos = x - (textPainter.width / 2);
    if (isUnicode) yPos = yPos - 40;

    textPainter.paint(canvas, Offset(xPos, yPos));
  }

  /// Draw key signature on the staff
  void _drawKeySignature(Canvas canvas, Paint paint, MusicalNote note,
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
    final String symbol = isSharp ? '\u266F' : '\u266D';

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

  void _drawTriplet(
      Canvas canvas,
      Paint paint,
      double x,
      double staffTop,
      double lineSpacing,
      List<MusicalNote> notes,
      int noteIndex,
      double currentRowSpacing) {
    if (noteIndex + 2 >= notes.length) {
      double y = calculateNoteYMainSheet(notes[noteIndex].pitch,
          notes[noteIndex].octave, lineSpacing, staffTop);
      double tripletPlaceholderY = y - 50;

      if (notes[noteIndex].noteY < tripletPlaceholderY + 10) {
        tripletPlaceholderY = notes[noteIndex].noteY - 20;
      }

      if (staffTop + 20 < tripletPlaceholderY) {
        tripletPlaceholderY = staffTop - 20;
      }
      if (staffTop - 40 > tripletPlaceholderY) {
        tripletPlaceholderY = tripletPlaceholderY + 30;
      }

      final textStyle = TextStyle(
        color: paint.color,
        fontSize: 40,
        fontFamily: 'Bravura',
      );
      final textSpan = TextSpan(
        text: '\uE202', // Triplet '3'
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      double x1 = x;
      double x2 = x + currentRowSpacing;
      double x3 = x + (2 * currentRowSpacing);

      double middleX = x2;
      double textX = middleX - (textPainter.width / 2);

      textPainter.paint(canvas, Offset(textX, tripletPlaceholderY - 33));

      paint.strokeWidth = 1.0;
      canvas.drawLine(Offset(x1, tripletPlaceholderY),
          Offset(textX - 4, tripletPlaceholderY), paint);
      canvas.drawLine(
          Offset(textX + textPainter.width + 4, tripletPlaceholderY),
          Offset(x3, tripletPlaceholderY),
          paint);

      canvas.drawLine(Offset(x1, tripletPlaceholderY),
          Offset(x1, tripletPlaceholderY + 7), paint);
      canvas.drawLine(Offset(x3, tripletPlaceholderY),
          Offset(x3, tripletPlaceholderY + 7), paint);
      return;
    }

    MusicalNote note1 = notes[noteIndex];
    MusicalNote note2 = notes[noteIndex + 1];
    MusicalNote note3 = notes[noteIndex + 2];

    double x1 = x;
    double x2 = x + currentRowSpacing;
    double x3 = x + (2 * currentRowSpacing);

    double y1 = calculateNoteYMainSheet(
        note1.pitch, note1.octave, lineSpacing, staffTop);
    double y2 = calculateNoteYMainSheet(
        note2.pitch, note2.octave, lineSpacing, staffTop);
    double y3 = calculateNoteYMainSheet(
        note3.pitch, note3.octave, lineSpacing, staffTop);

    double highestNoteY = math.min(y1, math.min(y2, y3));
    double tripletY = highestNoteY - 50;

    // Adjust Y to avoid overlap with notes above
    for (int i = noteIndex; i <= noteIndex + 2; i++) {
      if (notes[i].noteY < tripletY + 10) {
        tripletY = notes[i].noteY - 20;
      }
    }

    if (staffTop + 20 < tripletY) tripletY = staffTop - 20;
    if (staffTop - 40 > tripletY) tripletY = tripletY + 30;

    bool isAnyNoteInTripletBeamed =
        note1.isBeamed || note2.isBeamed || note3.isBeamed;

    if (isAnyNoteInTripletBeamed) {
      int beamStartIndex = noteIndex;
      // Find the actual start of the beamed group by looking backwards
      while (beamStartIndex > 0 && notes[beamStartIndex - 1].isBeamed) {
        beamStartIndex--;
      }
      MusicalNote firstNoteOfBeam = notes[beamStartIndex];

      // Apply the condition using the first note of the entire beamed group
      if (firstNoteOfBeam.isUpsideDown == true && y1 < staffTop - 20) {
        tripletY = tripletY - 40;
      }
    }

    final textStyle = TextStyle(
      color: paint.color,
      fontSize: 40,
      fontFamily: 'Bravura',
    );
    final textSpan = TextSpan(
      text: '\uE202', // Triplet '3'
      style: textStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    double middleX = x2;
    double textX = middleX - (textPainter.width / 2);

    textPainter.paint(canvas, Offset(textX, tripletY - 33));

    paint.strokeWidth = 1.0;
    canvas.drawLine(Offset(x1, tripletY), Offset(textX - 4, tripletY), paint);
    canvas.drawLine(Offset(textX + textPainter.width + 4, tripletY),
        Offset(x3, tripletY), paint);

    canvas.drawLine(Offset(x1, tripletY), Offset(x1, tripletY + 7), paint);
    canvas.drawLine(Offset(x3, tripletY), Offset(x3, tripletY + 7), paint);
  }
}
