import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';

class SheetPreviewPainter extends CustomPainter {
  final List<MusicalNote> notes;
  final Color backgroundColor;
  final Color lineColor;

  SheetPreviewPainter({
    required this.notes,
    this.backgroundColor = Colors.white,
    this.lineColor = Colors.black,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Staff line paint
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    // Calculate staff dimensions
    final lineSpacing = size.height / 12;
    final staffTop = (size.height - (4 * lineSpacing)) / 2;

    // Draw 5 staff lines
    for (int i = 0; i < 5; i++) {
      final y = staffTop + (i * lineSpacing);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // If no notes, return early
    if (notes.isEmpty) {
      return;
    }

    // Draw notes
    final double noteSpacing = size.width / (notes.length + 1);
    final double staffCenter = staffTop + (2 * lineSpacing);

    for (int i = 0; i < notes.length && i < 5; i++) {
      final note = notes[i];
      final double noteX = noteSpacing * (i + 1);

      // Calculate note Y position
      final double noteY = calculateNoteYVerticalKeyboard(
        note.pitch,
        note.octave,
        lineSpacing,
        staffTop,
      );

      // Determine if note should be upside down
      final bool isUpsideDown = noteY <= staffCenter;

      // Draw ledger lines if needed
      _drawLedgerLines(
        canvas,
        linePaint,
        noteY,
        noteX,
        size.width / 15,
        lineSpacing,
        staffTop,
      );

      // Draw the note
      final textPainter = TextPainter(
        text: TextSpan(
          text: _getNoteUnicode(note, isUpsideDown),
          style: TextStyle(
            fontFamily: 'Bravura',
            fontSize: size.height / 5,
            color: lineColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      final x = noteX - (textPainter.width / 2);
      final y = noteY - (textPainter.height / 2);

      textPainter.paint(canvas, Offset(x, y));

      // Draw accidental if present
      if (note.accidentalCharacter != null &&
          note.accidentalCharacter!.isNotEmpty) {
        _drawAccidental(
          canvas,
          note.accidentalCharacter!,
          x,
          y,
          isUpsideDown,
          size.height / 7,
        );
      }
    }
  }

  String _getNoteUnicode(MusicalNote note, bool isUpsideDown) {
    // Map note types to their unicode characters
    // This is simplified - you might want to use the actual NoteUnicodeCharacters class
    switch (note.type) {
      case NoteType.whole:
        return '\uE0A2';
      case NoteType.half:
        return isUpsideDown ? '\uE0A4' : '\uE0A3';
      case NoteType.quarter:
        return isUpsideDown ? '\uE0A5' : '\uE0A4';
      case NoteType.eighth:
        return isUpsideDown ? '\uE0A9' : '\uE0A8';
      case NoteType.sixteenth:
        return isUpsideDown ? '\uE0AB' : '\uE0AA';
      default:
        return note.unicodeCharacter ?? '\uE0A4';
    }
  }

  void _drawLedgerLines(
    Canvas canvas,
    Paint paint,
    double noteY,
    double noteX,
    double noteWidth,
    double lineSpacing,
    double staffTop,
  ) {
    final double staffBottom = staffTop + (4 * lineSpacing);

    // Draw ledger lines above staff
    if (noteY <= staffTop - lineSpacing) {
      for (double y = staffTop - lineSpacing;
          y >= noteY - lineSpacing / 3;
          y -= lineSpacing) {
        canvas.drawLine(
          Offset(noteX - noteWidth, y),
          Offset(noteX + noteWidth, y),
          paint..strokeWidth = 1.0,
        );
      }
    }
    // Draw ledger lines below staff
    else if (noteY >= staffBottom + lineSpacing) {
      for (double y = staffBottom + lineSpacing;
          y <= noteY + lineSpacing / 3;
          y += lineSpacing) {
        canvas.drawLine(
          Offset(noteX - noteWidth, y),
          Offset(noteX + noteWidth, y),
          paint..strokeWidth = 1.0,
        );
      }
    }
  }

  void _drawAccidental(
    Canvas canvas,
    String accidental,
    double noteX,
    double noteY,
    bool isUpsideDown,
    double fontSize,
  ) {
    final accidentalPainter = TextPainter(
      text: TextSpan(
        text: accidental,
        style: TextStyle(
          fontFamily: 'Bravura',
          fontSize: fontSize,
          color: lineColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    accidentalPainter.layout();
    final x = noteX - accidentalPainter.width * 1.2;
    final y = noteY + (isUpsideDown ? 8 : 3);

    accidentalPainter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant SheetPreviewPainter oldDelegate) {
    return oldDelegate.notes != notes ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.lineColor != lineColor;
  }
}
