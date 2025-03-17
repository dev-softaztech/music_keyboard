import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/drawing_helpers.dart';

class MusicSheetPainter extends CustomPainter {
  final List<List<MusicalNote>> sheetNoteRows;
  final int selectedRow; // Row where the cursor is placed
  final int selectedIndex; // Index within the row
  final bool showCursor;

  MusicSheetPainter(this.sheetNoteRows, this.selectedRow, this.selectedIndex,
      this.showCursor);

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

      for (int i = 0; i < sheetNoteRows[rowIndex].length; i++) {
        MusicalNote note = sheetNoteRows[rowIndex][i];

        drawNote(canvas, paint, note, lineSpacing, staffTop, x,
            sheetNoteRows[rowIndex], i);

        if (note.isTiedToNext && i < sheetNoteRows[rowIndex].length - 1) {
          drawTie(canvas, paint, x, staffTop, x + 26); // Tie to the next note
        }

        x += 26;
      }

      if (showCursor && rowIndex == selectedRow) {
        drawInsertionCursor(canvas, paint, staffTop, selectedIndex, size);
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
      Canvas canvas, Paint paint, double staffTop, int index, Size size) {
    //if (!showCursor) return;

    final Paint cursorPaint = Paint()..color = Colors.blue.withOpacity(0.8);
    double cursorX = 25.0 + (index * 26); // Offset for insertion
    double cursorY = staffTop + (10 * 2); // Center on staff

    canvas.drawLine(
      Offset(cursorX - 12, cursorY - 35),
      Offset(cursorX - 12, cursorY + 35),
      cursorPaint..strokeWidth = 2.0,
    );
  }

  void drawTie(
      Canvas canvas, Paint paint, double startX, double staffTop, double endX) {
    Path path = Path();
    double controlY = staffTop + 20; // Adjust height of curve

    path.moveTo(startX, staffTop + 30);
    path.quadraticBezierTo((startX + endX) / 2, controlY, endX, staffTop + 30);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;

    canvas.drawPath(path, paint);
  }
}
