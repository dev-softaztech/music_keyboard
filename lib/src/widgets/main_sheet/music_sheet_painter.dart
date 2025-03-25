import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/cursor_calculation.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/drawing_helpers.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';

class MusicSheetPainter extends CustomPainter {
  final List<List<MusicalNote>> sheetNoteRows;
  final int selectedRow; // Row where the cursor is placed
  final int selectedIndex; // Index within the row
  final bool showCursor;
  final List<int> rowSpacingList;

  MusicSheetPainter(this.sheetNoteRows, this.selectedRow, this.selectedIndex,
      this.showCursor, this.rowSpacingList);

  @override
  void paint(Canvas canvas, Size size) {
    // Ensure the entire canvas is filled with white
    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    final paint = Paint()..color = Colors.black;
    const double lineSpacing = 10;
    const double sheetHeight = lineSpacing * 4;
    const double rowSpacing = 130.0; // Space between rows

    for (int rowIndex = 0; rowIndex < sheetNoteRows.length; rowIndex++) {
      double staffTop = rowIndex == 0
          ? rowSpacing / 2
          : (rowIndex * rowSpacing) +
              (rowIndex * sheetHeight) +
              (rowSpacing / 2);
      drawStaffLines(canvas, paint, staffTop, lineSpacing, sheetHeight, size);

      double x = 25.0;
      int currentRowSpacing = rowSpacingList[rowIndex];

      for (int i = 0; i < sheetNoteRows[rowIndex].length; i++) {
        MusicalNote note = sheetNoteRows[rowIndex][i];

        drawNote(canvas, paint, note, lineSpacing, staffTop, x,
            sheetNoteRows[rowIndex], i, currentRowSpacing);

        if (note.isTiedToNext && i < sheetNoteRows[rowIndex].length - 1) {
          double y = calculateNoteYMainSheet(
              note.pitch, note.octave, lineSpacing, staffTop);
          drawTie(canvas, paint, x, staffTop + (lineSpacing * 2),
              x + currentRowSpacing, y); // Tie to the next note
        }

        x += note.type == NoteType.clef ? 26 : currentRowSpacing; //26;
      }

      if (showCursor && rowIndex == selectedRow) {
        int clefCount = sheetNoteRows[rowIndex]
            .where((x) => x.type == NoteType.clef)
            .length;

        drawInsertionCursor(canvas, paint, staffTop, selectedIndex - 1, size,
            currentRowSpacing, clefCount, sheetNoteRows[rowIndex], lineSpacing);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  void drawStaffLines(Canvas canvas, Paint paint, double staffTop,
      double lineSpacing, double sheetHeight, Size size) {
    // Draw staff lines
    for (int i = 0; i < 5; i++) {
      final y = staffTop + i * lineSpacing;
      canvas.drawLine(
        Offset(5, y),
        Offset(size.width - 5, y), // Extend to full fixed width
        paint..strokeWidth = 1.0,
      );
    }

    canvas.drawLine(Offset(5, staffTop), Offset(5, staffTop + (sheetHeight)),
        paint..strokeWidth = 1.0);

    canvas.drawLine(
        Offset(size.width - 5, staffTop),
        Offset(size.width - 5, staffTop + (sheetHeight)),
        paint..strokeWidth = 1.0);
  }

  void drawInsertionCursor(
      Canvas canvas,
      Paint paint,
      double staffTop,
      int index,
      Size size,
      int rowSpacing,
      int clefCount,
      List<MusicalNote> notes,
      double lineSpacing) {
    double cursorX = notes.isEmpty
        ? 25
        : calculateCursorPosition(notes[index], rowSpacing, clefCount, index);

    double cursorY = staffTop + (lineSpacing * 2); // Center on staff

    final Paint cursorPaint = Paint()..color = Colors.blue.withOpacity(0.8);

    canvas.drawLine(
      Offset(cursorX, cursorY - 45),
      Offset(cursorX, cursorY + 45),
      cursorPaint..strokeWidth = 2.0,
    );
  }

  void drawTie(Canvas canvas, Paint paint, double startX, double staffCentre,
      double endX, double y) {
    Path path = Path();
    double controlY =
        y >= staffCentre ? y + 30 : y - 30; // Adjust height of curve

    y = y >= staffCentre ? y + 10 : y - 10;

    path.moveTo(startX + 5, y);
    path.quadraticBezierTo((startX + endX) / 2, controlY, endX - 5, y);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;

    canvas.drawPath(path, paint);
  }
}
