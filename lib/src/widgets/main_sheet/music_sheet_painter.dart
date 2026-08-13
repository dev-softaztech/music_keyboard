import 'package:flutter/material.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/models/sheet_properties.dart';
import 'package:music_keyboard/models/keyboard_type.dart';
import 'package:music_keyboard/src/utils/pdf_exporter.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/bar_line_calculator.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/drawing_helpers.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_width_calculator.dart';
import 'music_sheet_painter/guitar_technique_painter.dart';
import 'music_sheet_painter/expression_markings_painter.dart';
import 'music_sheet_painter/staff_structure_painter.dart';
import 'music_sheet_painter/sheet_header_text_painter.dart';

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

  // Composed drawing helpers (stateless; see widgets/main_sheet/music_sheet_painter/)
  final GuitarTechniquePainter _guitarTechnique = GuitarTechniquePainter();
  final ExpressionMarkingsPainter _expressionMarkings =
      ExpressionMarkingsPainter();
  final StaffStructurePainter _staffStructure = StaffStructurePainter();
  final SheetHeaderTextPainter _sheetHeaderText = SheetHeaderTextPainter();

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
      _sheetHeaderText.drawTitleAndComposer(canvas, size, title, composer,
          renderStartRow, renderEndRow, showTitleAndComposer);
    }

    // Draw visual page breaks if content spans multiple pages
    _staffStructure.drawPageBreaks(canvas, size, renderStartRow, renderEndRow,
        sheetNoteRows, rowSpacing, sheetFormat, verticalOffset);

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
      _staffStructure.drawStaffLines(
          canvas, paint, staffTop, lineSpacing, sheetHeight, size, keyboardType);

      // Always draw the guitar tab clef symbol at the start of each row
      if (keyboardType == KeyboardType.guitarTab) {
        drawGuitarTabRowClef(canvas, lineSpacing, staffTop, 70, Colors.black);
      }

      // Draw bar number above the start of this row
      _staffStructure.drawBarNumber(canvas, rowIndex, staffTop, sheetNoteRows);

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
      _sheetHeaderText.drawTempo(
          canvas, rowIndex, staffTop, tempoTextY, sheetNoteRows);

      // Draw swing below the tempo if set
      _sheetHeaderText.drawSwing(
          canvas, rowIndex, staffTop, tempoTextY, sheetNoteRows);

      double x = keyboardType.startingNoteX;
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
      double barStartX = keyboardType.startingNoteX;
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
        double endX = keyboardType.startingNoteX +
            (sheetNoteRows[rowIndex].chords.length * currentRowSpacing);
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
      x = keyboardType.startingNoteX; // Reset x position for drawing
      for (int i = 0; i < sheetNoteRows[rowIndex].chords.length; i++) {
        MusicalNote chord = sheetNoteRows[rowIndex].chords[i];

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

        if (chord.type == NoteType.keySignature) {
          _staffStructure.drawKeySignature(
              canvas, paint, chord, lineSpacing, staffTop, x, noteColour);
        } else {
          drawNote(
              canvas,
              paint,
              chord,
              lineSpacing,
              staffTop,
              x,
              sheetNoteRows[rowIndex].chords,
              i,
              currentRowSpacing,
              noteColour,
              keyboardType);
        }

        if (chord.isTriplet) {
          _expressionMarkings.drawTriplet(canvas, paint, x, staffTop,
              lineSpacing, sheetNoteRows[rowIndex].chords, i, currentRowSpacing);
        }

        if (chord.dynamicCharacter.isNotEmpty) {
          _expressionMarkings.drawDynamicCharacter(canvas, chord, noteColour,
              x, staffTop, lineSpacing, sheetNoteRows[rowIndex].chords, i);
        }

        if (chord.accentCharacter.isNotEmpty) {
          _expressionMarkings.drawAccentCharacter(canvas, chord, noteColour, x,
              staffTop, lineSpacing, sheetNoteRows[rowIndex].chords, i);
        }

        if (chord.rehearsalMarking.isNotEmpty) {
          double textY = staffTop - 30;

          for (int x = i; x < i + 3; x++) {
            if (sheetNoteRows[rowIndex].chords.length > x &&
                sheetNoteRows[rowIndex].chords[x].noteY - 10 <= textY) {
              textY = sheetNoteRows[rowIndex].chords[x].noteY - 30;
            }
          }

          _expressionMarkings.drawRehearsalMarking(
              canvas, chord, noteColour, x, staffTop, lineSpacing, textY);
        }

        if (chord.tapRightHandCharacter.isNotEmpty) {
          _guitarTechnique.drawTapRightHand(canvas, chord, noteColour, x,
              staffTop, lineSpacing, sheetNoteRows[rowIndex].chords, i);
        }

        if (chord.hasPickDownward) {
          _guitarTechnique.drawPickDownward(canvas, chord, noteColour, x,
              staffTop, lineSpacing, sheetNoteRows[rowIndex].chords, i);
        }

        if (chord.hasPickUpward) {
          _guitarTechnique.drawPickUpward(canvas, chord, noteColour, x,
              staffTop, lineSpacing, sheetNoteRows[rowIndex].chords, i);
        }

        if (chord.type == NoteType.bar) {
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
          if (chord.tempoNumber > 0) {
            _staffStructure.drawBarTempo(canvas, chord, x, textY);
          }

          // Draw bar-level swing markings below bar tempo if set
          if (chord.swing) {
            _staffStructure.drawBarSwing(canvas, chord, x, textY);
          }
        }

        var staffCenter = staffTop + (lineSpacing * 2);

        if (chord.isTiedToNext &&
            i < sheetNoteRows[rowIndex].chords.length - 1) {
          if (chord.type == NoteType.chord &&
              chord.childNotes != null &&
              chord.childNotes!.isNotEmpty) {
            // For NoteType.chord, draw a tie for every childNote that has a
            // matching note (same pitch + octave) at the next position in the
            // row, whether the next note is a regular note or another chord.
            final MusicalNote nextNote = sheetNoteRows[rowIndex].chords[i + 1];
            for (final childNote in chord.childNotes!) {
              bool hasMatch = false;
              if (nextNote.type == NoteType.chord &&
                  nextNote.childNotes != null) {
                // Next note is also a chord – match against its children.
                hasMatch = nextNote.childNotes!.any((n) =>
                    n.pitch == childNote.pitch && n.octave == childNote.octave);
              } else {
                // Next note is a regular note – match directly.
                hasMatch = nextNote.pitch == childNote.pitch &&
                    nextNote.octave == childNote.octave;
              }
              if (hasMatch) {
                final double childY = calculateNoteYMainSheet(
                    childNote.pitch, childNote.octave, lineSpacing, staffTop);
                _expressionMarkings.drawTie(canvas, paint, x, staffCenter,
                    x + currentRowSpacing, childY);
              }
            }
          } else {
            // Regular (non-chord) note – draw a single tie as before.
            double y = calculateNoteYMainSheet(
                chord.pitch, chord.octave, lineSpacing, staffTop);
            _expressionMarkings.drawTie(
                canvas, paint, x, staffCenter, x + currentRowSpacing, y);
          }
        }

        if (chord.slurEndIndex != null) {
          var slurEndIndex =
              chord.slurEndIndex! < sheetNoteRows[rowIndex].chords.length - 1
                  ? chord.slurEndIndex!
                  : sheetNoteRows[rowIndex].chords.length - 1;

          double startX = x;

          // Calculate endX by accounting for space note spacing
          double endX = keyboardType.startingNoteX;
          for (int index = 0; index < slurEndIndex; index++) {
            final currentNote = sheetNoteRows[rowIndex].chords[index];

            endX += currentNote.type == NoteType.clef ||
                    currentNote.type == NoteType.timeSignature
                ? getNoteWidth(currentNote)
                : currentNote.type == NoteType.keySignature
                    ? getNoteWidth(currentNote) + 10
                    : currentRowSpacing;
          }

          // Pre-determine slur direction (mirrors logic inside drawSlurBetweenNotes)
          // so we can pick the correct extremal child note for chord notes.
          final bool slurIsAbove = _expressionMarkings.isSlurAboveForRange(
              sheetNoteRows[rowIndex].chords, i, slurEndIndex, staffCenter);

          // For NoteType.chord start note, attach slur to highest child (if
          // curving above) or lowest child (if curving below).
          double startY;
          if (chord.type == NoteType.chord &&
              chord.childNotes != null &&
              chord.childNotes!.isNotEmpty) {
            startY = _expressionMarkings.extremalChildY(
                chord, slurIsAbove, lineSpacing, staffTop);
          } else {
            startY = calculateNoteYMainSheet(
                chord.pitch, chord.octave, lineSpacing, staffTop);
          }

          // For NoteType.chord end note, do the same.
          final MusicalNote endChord =
              sheetNoteRows[rowIndex].chords[slurEndIndex];
          double endY;
          if (endChord.type == NoteType.chord &&
              endChord.childNotes != null &&
              endChord.childNotes!.isNotEmpty) {
            endY = _expressionMarkings.extremalChildY(
                endChord, slurIsAbove, lineSpacing, staffTop);
          } else {
            endY = calculateNoteYMainSheet(
                endChord.pitch, endChord.octave, lineSpacing, staffTop);
          }

          _expressionMarkings.drawSlurBetweenNotes(
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

        if (chord.isCrescendoStart && chord.crescendoEndIndex != null) {
          var crescendoEndIndex = chord.crescendoEndIndex! <
                  sheetNoteRows[rowIndex].chords.length - 1
              ? chord.crescendoEndIndex!
              : sheetNoteRows[rowIndex].chords.length - 1;

          // Calculate endX by accounting for space note spacing
          double crescendoEndX = keyboardType.startingNoteX;
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

          _expressionMarkings.drawDynamicMarking(
              canvas,
              paint,
              x,
              crescendoEndX,
              staffTop,
              true,
              i,
              crescendoEndIndex,
              sheetNoteRows[rowIndex].chords,
              rowIndex,
              editingDynamicRow,
              editingDynamicIndex);
        }

        if (chord.isDecrescendoStart && chord.decrescendoEndIndex != null) {
          var decrescendoEndIndex = chord.decrescendoEndIndex! <
                  sheetNoteRows[rowIndex].chords.length - 1
              ? chord.decrescendoEndIndex!
              : sheetNoteRows[rowIndex].chords.length - 1;

          // Calculate endX by accounting for space note spacing
          double decrescendoEndX = keyboardType.startingNoteX;
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

          _expressionMarkings.drawDynamicMarking(
              canvas,
              paint,
              x,
              decrescendoEndX,
              staffTop,
              false,
              i,
              decrescendoEndIndex,
              sheetNoteRows[rowIndex].chords,
              rowIndex,
              editingDynamicRow,
              editingDynamicIndex);
        }

        if (keyboardType == KeyboardType.guitarTab &&
            chord.type == NoteType.fret) {
          if (chord.childNotes != null) {
            // Track bend-release info for single curve down drawing
            List<({double startX, double peakX, double stringY})>
                releaseBendCurves = [];
            double? highestReleaseString;

            for (var childNote in chord.childNotes!) {
              double stringY = staffTop + (childNote.octave * lineSpacing);

              if (highestReleaseString == null ||
                  stringY < highestReleaseString) {
                highestReleaseString = stringY;
              }
            }

            // Iterate through each childNote to draw bends
            for (var childNote in chord.childNotes!) {
              // Check for bend
              if (childNote.isBendStart && childNote.bendEndIndex != null) {
                var bendEndIndex = childNote.bendEndIndex! == (i - 1)
                    ? i
                    : childNote.bendEndIndex! <
                            sheetNoteRows[rowIndex].chords.length - 1
                        ? childNote.bendEndIndex!
                        : sheetNoteRows[rowIndex].chords.length - 1;

                var indexDistanceCount = bendEndIndex - i;

                double bendEndX =
                    x + ((indexDistanceCount) * currentRowSpacing);
                bendEndX += (currentRowSpacing * 0.85);

                // Get string Y position from this childNote
                double stringY = staffTop + (childNote.octave * lineSpacing);

                _guitarTechnique.drawBend(canvas, paint, x, bendEndX, stringY,
                    staffTop, lineSpacing, noteColour, currentRowSpacing);
              }

              // Check for pre-bend
              if (childNote.isPreBendStart &&
                  childNote.preBendEndIndex != null) {
                var preBendEndIndex = childNote.preBendEndIndex! == (i - 1)
                    ? i
                    : childNote.preBendEndIndex! <
                            sheetNoteRows[rowIndex].chords.length - 1
                        ? childNote.preBendEndIndex!
                        : sheetNoteRows[rowIndex].chords.length - 1;

                var indexDistanceCount = preBendEndIndex - i;

                double preBendEndX =
                    x + ((indexDistanceCount) * currentRowSpacing);
                preBendEndX += (currentRowSpacing * 0.85);

                // Get string Y position from this childNote
                double stringY = staffTop + (childNote.octave * lineSpacing);

                _guitarTechnique.drawPreBend(
                    canvas,
                    paint,
                    x,
                    preBendEndX,
                    stringY,
                    staffTop,
                    lineSpacing,
                    noteColour,
                    currentRowSpacing);
              }

              // Check for bend-release
              if (childNote.isBendReleaseStart &&
                  childNote.bendReleaseEndIndex != null) {
                var bendReleaseEndIndex =
                    childNote.bendReleaseEndIndex! == (i - 1)
                        ? i
                        : childNote.bendReleaseEndIndex! <
                                sheetNoteRows[rowIndex].chords.length - 1
                            ? childNote.bendReleaseEndIndex!
                            : sheetNoteRows[rowIndex].chords.length - 1;

                var indexDistanceCount = bendReleaseEndIndex - i;

                double bendReleaseEndX =
                    x + ((indexDistanceCount) * currentRowSpacing);
                bendReleaseEndX += (currentRowSpacing * 0.85);

                // Get string Y position from this childNote
                double stringY = staffTop + (childNote.octave * lineSpacing);

                // Store this release bend for potential combined drawing
                double peakX = x + (currentRowSpacing * 0.4);
                releaseBendCurves
                    .add((startX: x, peakX: peakX, stringY: stringY));

                _guitarTechnique.drawBendRelease(
                    canvas,
                    paint,
                    x,
                    bendReleaseEndX,
                    stringY,
                    staffTop,
                    lineSpacing,
                    noteColour,
                    currentRowSpacing,
                    highestReleaseString);
              }

              // Check for pre-bend-release
              if (childNote.isPreBendReleaseStart &&
                  childNote.preBendReleaseEndIndex != null) {
                var preBendReleaseEndIndex =
                    childNote.preBendReleaseEndIndex! == (i - 1)
                        ? i
                        : childNote.preBendReleaseEndIndex! <
                                sheetNoteRows[rowIndex].chords.length - 1
                            ? childNote.preBendReleaseEndIndex!
                            : sheetNoteRows[rowIndex].chords.length - 1;

                var indexDistanceCount = preBendReleaseEndIndex - i;

                double preBendReleaseEndX =
                    x + ((indexDistanceCount) * currentRowSpacing);
                preBendReleaseEndX += (currentRowSpacing * 0.85);

                // Get string Y position from this childNote
                double stringY = staffTop + (childNote.octave * lineSpacing);

                _guitarTechnique.drawPreBendRelease(
                    canvas,
                    paint,
                    x,
                    preBendReleaseEndX,
                    stringY,
                    staffTop,
                    lineSpacing,
                    noteColour,
                    currentRowSpacing,
                    highestReleaseString);
              }

              // Check for hammer-left-hand
              if (childNote.isHammerLeftHandStart &&
                  childNote.hammerLeftHandEndIndex != null) {
                var hammerLeftHandEndIndex = childNote.hammerLeftHandEndIndex! <
                        sheetNoteRows[rowIndex].chords.length - 1
                    ? childNote.hammerLeftHandEndIndex!
                    : sheetNoteRows[rowIndex].chords.length - 1;

                var indexDistanceCount = hammerLeftHandEndIndex - i;

                double hammerLeftHandEndX =
                    x + ((indexDistanceCount) * currentRowSpacing);
                hammerLeftHandEndX += (currentRowSpacing * 0.85);

                // Get string Y position from this childNote (start and end Y are the same)
                double stringY = staffTop + (childNote.octave * lineSpacing);

                _guitarTechnique.drawHammerLeftHand(
                    canvas, paint, x, hammerLeftHandEndX, stringY, noteColour);
              }

              // Check for slide-up
              if (childNote.hasSlideUp) {
                double stringY = staffTop + (childNote.octave * lineSpacing);
                _guitarTechnique.drawSlideUp(
                    canvas, paint, x, stringY, noteColour, currentRowSpacing);
              }

              // Check for slide-down
              if (childNote.hasSlideDown) {
                double stringY = staffTop + (childNote.octave * lineSpacing);
                _guitarTechnique.drawSlideDown(
                    canvas, paint, x, stringY, noteColour, currentRowSpacing);
              }
            }
          }
          // Check if chord has any bend to determine positioning
          bool hasBend =
              chord.childNotes != null && chord.childNotes!.isNotEmpty
                  ? chord.childNotes!.any((child) =>
                      child.isBendStart ||
                      child.isPreBendStart ||
                      child.isBendReleaseStart ||
                      child.isPreBendReleaseStart)
                  : false;

          // Check for mute technique
          if (chord.isMuteStart && chord.muteEndIndex != null) {
            bool isSingleChordSpan = chord.muteEndIndex! == (i - 1);
            var muteEndIndex = isSingleChordSpan
                ? i
                : chord.muteEndIndex! <
                        sheetNoteRows[rowIndex].chords.length - 1
                    ? chord.muteEndIndex!
                    : sheetNoteRows[rowIndex].chords.length - 1;

            var indexDistanceCount = muteEndIndex - i;

            double muteEndX = x + ((indexDistanceCount) * currentRowSpacing);
            muteEndX += (currentRowSpacing * 0.85);

            // Check if any chord whose bend range overlaps [i, muteEndIndex]
            bool hasBendForMute = hasBend ||
                _guitarTechnique.hasBendOverlappingRange(
                    sheetNoteRows[rowIndex].chords, i, muteEndIndex);

            _guitarTechnique.drawMute(canvas, paint, x, muteEndX, staffTop,
                lineSpacing, noteColour, hasBendForMute, isSingleChordSpan);
          }

          // Check for pinch harmonic technique
          if (chord.isPinchHarmonicStart &&
              chord.pinchHarmonicEndIndex != null) {
            bool isSingleChordSpan = chord.pinchHarmonicEndIndex! == (i - 1);
            var pinchHarmonicEndIndex = isSingleChordSpan
                ? i
                : chord.pinchHarmonicEndIndex! <
                        sheetNoteRows[rowIndex].chords.length - 1
                    ? chord.pinchHarmonicEndIndex!
                    : sheetNoteRows[rowIndex].chords.length - 1;

            var indexDistanceCount = pinchHarmonicEndIndex - i;

            double pinchHarmonicEndX =
                x + ((indexDistanceCount) * currentRowSpacing);
            pinchHarmonicEndX += (currentRowSpacing * 0.85);

            // Check if any chord whose bend range overlaps [i, pinchHarmonicEndIndex]
            bool hasBendForPinchHarmonic = hasBend ||
                _guitarTechnique.hasBendOverlappingRange(
                    sheetNoteRows[rowIndex].chords, i, pinchHarmonicEndIndex);

            _guitarTechnique.drawPinchHarmonic(
                canvas,
                paint,
                x,
                pinchHarmonicEndX,
                staffTop,
                lineSpacing,
                noteColour,
                hasBendForPinchHarmonic,
                isSingleChordSpan);
          }

          // Check for harmonic technique
          if (chord.isHarmonicStart && chord.harmonicEndIndex != null) {
            bool isSingleChordSpan = chord.harmonicEndIndex! == (i - 1);
            var harmonicEndIndex = isSingleChordSpan
                ? i
                : chord.harmonicEndIndex! <
                        sheetNoteRows[rowIndex].chords.length - 1
                    ? chord.harmonicEndIndex!
                    : sheetNoteRows[rowIndex].chords.length - 1;

            var indexDistanceCount = harmonicEndIndex - i;

            double harmonicEndX =
                x + ((indexDistanceCount) * currentRowSpacing);
            harmonicEndX += (currentRowSpacing * 0.85);

            // Check if any chord whose bend range overlaps [i, harmonicEndIndex]
            bool hasBendForHarmonic = hasBend ||
                _guitarTechnique.hasBendOverlappingRange(
                    sheetNoteRows[rowIndex].chords, i, harmonicEndIndex);

            _guitarTechnique.drawHarmonic(
                canvas,
                paint,
                x,
                harmonicEndX,
                staffTop,
                lineSpacing,
                noteColour,
                hasBendForHarmonic,
                isSingleChordSpan);
          }

          // Check for vibrato technique
          if (chord.isVibratoStart && chord.vibratoEndIndex != null) {
            bool isSingleChordSpan = chord.vibratoEndIndex! == (i - 1);
            var vibratoEndIndex = isSingleChordSpan
                ? i
                : chord.vibratoEndIndex! <
                        sheetNoteRows[rowIndex].chords.length - 1
                    ? chord.vibratoEndIndex!
                    : sheetNoteRows[rowIndex].chords.length - 1;

            var indexDistanceCount = vibratoEndIndex - i;

            double vibratoEndX = x + ((indexDistanceCount) * currentRowSpacing);
            vibratoEndX += (currentRowSpacing * 0.85);

            // Check if any chord whose bend range overlaps [i, vibratoEndIndex]
            bool hasBendForVibrato = hasBend ||
                _guitarTechnique.hasBendOverlappingRange(
                    sheetNoteRows[rowIndex].chords, i, vibratoEndIndex);

            _guitarTechnique.drawVibrato(
                canvas,
                paint,
                x,
                vibratoEndX,
                staffTop,
                lineSpacing,
                noteColour,
                hasBendForVibrato,
                isSingleChordSpan,
                currentRowSpacing);
          }
        }

        // Calculate spacing for space notes
        double spaceNoteSpacing = 0;
        if (chord.type == NoteType.space && i > 0) {
          // Check if previous note is also a space note
          bool prevIsSpace =
              sheetNoteRows[rowIndex].chords[i - 1].type == NoteType.space;
          // First space note in sequence: no spacing, subsequent: full spacing
          spaceNoteSpacing = prevIsSpace ? currentRowSpacing : 0;
        }

        x += chord.type == NoteType.clef || chord.type == NoteType.timeSignature
            ? getNoteWidth(chord)
            : chord.type == NoteType.keySignature
                ? getNoteWidth(chord) + 10
                : chord.type == NoteType.space
                    ? spaceNoteSpacing
                    : currentRowSpacing;
      }

      // Draw selection highlight for selected notes
      if (selectionRow == rowIndex &&
          selectionStart != null &&
          selectionEnd != null) {
        _staffStructure.drawHighlight(
            canvas,
            size,
            rowIndex,
            staffTop,
            lineSpacing,
            sheetNoteRows,
            rowSpacingList,
            keyboardType,
            selectionStart,
            selectionEnd,
            selectionRow);
      }

      // Draw row highlight for select rows mode
      if (selectedRowsForCurlyBrace != null &&
          selectedRowsForCurlyBrace!.contains(rowIndex)) {
        _staffStructure.drawRowHighlight(canvas, size, staffTop, lineSpacing);
      }

      // We no longer add automatic bar lines here as it's now handled in CurrentSelectedNoteProvider

      if (rowIndex == selectedRow) {
        // Draw the cursor if showCursor is true and not in read-only mode
        if (showCursor && !isReadOnly) {
          _staffStructure.drawInsertionCursor(
              canvas,
              paint,
              staffTop,
              selectedIndex + 1,
              size,
              currentRowSpacing,
              sheetNoteRows[rowIndex].chords,
              lineSpacing,
              keyboardType,
              selectionStart,
              selectionEnd,
              selectionRow);
        }

        // Find which bar contains the selected note and check if it's overfilled
        for (var bar in bars) {
          if (selectedIndex >= bar.startIndex &&
              selectedIndex <= bar.endIndex &&
              bar.isOverfilled) {
            // Draw warning above the specific bar
            _staffStructure.drawTooManyNotesWarning(
                canvas, staffTop, bar.xStart, bar.xEnd);
            break;
          }
        }
      }

      paint = Paint()..color = Colors.black;
      noteColour = Colors.black;
    }

    // Draw permanent curly braces from saved groups (after all rows are drawn)
    if (curlyBraceGroups.isNotEmpty) {
      _staffStructure.drawPermanentCurlyBraces(
          canvas,
          size,
          lineSpacing,
          adjustedVerticalOffset,
          cumulativeMarginOffsets,
          sheetHeight,
          startRow,
          rowSpacing,
          curlyBraceGroups);
    }

    // Draw connecting elements for connected row formats (piano, grand, etc.)
    _staffStructure.drawConnectedRowElements(
        canvas,
        size,
        sheetFormat,
        sheetNoteRows,
        rowSpacing,
        keyboardType,
        rowSpacingList,
        renderStartRow,
        renderEndRow,
        showTitleAndComposer,
        verticalOffset);
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
}
