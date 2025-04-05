import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/cursor_calculation.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/drawing_helpers.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';

class MusicSheetPainter extends CustomPainter {
  final List<List<MusicalNote>> sheetNoteRows;
  final int selectedRow;
  final int selectedIndex;
  final bool showCursor;
  final List<int> rowSpacingList;

  MusicSheetPainter(this.sheetNoteRows, this.selectedRow, this.selectedIndex,
      this.showCursor, this.rowSpacingList);

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    Paint paint = Paint()..color = Colors.black;
    Color noteColour = Colors.black;
    const double lineSpacing = 10;
    const double sheetHeight = lineSpacing * 4;
    const double rowSpacing = 130.0;

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

        if (rowIndex == selectedRow && i == selectedIndex) {
          paint = Paint()..color = const Color.fromARGB(255, 222, 15, 0);
          noteColour = const Color.fromARGB(255, 222, 15, 0);
        } else {
          paint = Paint()..color = Colors.black;
          noteColour = Colors.black;
        }

        drawNote(canvas, paint, note, lineSpacing, staffTop, x,
            sheetNoteRows[rowIndex], i, currentRowSpacing, noteColour);

        var staffCenter = staffTop + (lineSpacing * 2);

        if (note.isTiedToNext && i < sheetNoteRows[rowIndex].length - 1) {
          double y = calculateNoteYMainSheet(
              note.pitch, note.octave, lineSpacing, staffTop);
          drawTie(canvas, paint, x, staffCenter, x + currentRowSpacing, y);
        }

        if (note.slurEndIndex != null) {
          double startX = x;
          double startY = calculateNoteYMainSheet(
              note.pitch, note.octave, lineSpacing, staffTop);

          double endX = 25.0 + (note.slurEndIndex! * currentRowSpacing);
          double endY = calculateNoteYMainSheet(
              sheetNoteRows[rowIndex][note.slurEndIndex!].pitch,
              sheetNoteRows[rowIndex][note.slurEndIndex!].octave,
              lineSpacing,
              staffTop);

          drawSlur(canvas, paint, startX, startY, endX, endY, staffCenter);
        }

        x += note.type == NoteType.clef ? 26 : currentRowSpacing;
      }

      if (showCursor && rowIndex == selectedRow) {
        int clefCount = sheetNoteRows[rowIndex]
            .where((x) => x.type == NoteType.clef)
            .length;

        drawInsertionCursor(canvas, paint, staffTop, selectedIndex, size,
            currentRowSpacing, clefCount, sheetNoteRows[rowIndex], lineSpacing);
      }

      paint = Paint()..color = Colors.black;
      noteColour = Colors.black;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  void drawStaffLines(Canvas canvas, Paint paint, double staffTop,
      double lineSpacing, double sheetHeight, Size size) {
    for (int i = 0; i < 5; i++) {
      final y = staffTop + i * lineSpacing;
      canvas.drawLine(
        Offset(5, y),
        Offset(size.width - 5, y),
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
    double cursorY = staffTop + (lineSpacing * 2);

    final Paint cursorPaint = Paint()..color = Colors.blue.withOpacity(0.8);

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
}
