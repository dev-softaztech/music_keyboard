import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/note_unicode_characters.dart';
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
            fontSize: size.height / 4,
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
      if (note.accidentalCharacter.isNotEmpty) {
        _drawAccidental(
          canvas,
          note.accidentalCharacter,
          x,
          y,
          isUpsideDown,
          size.height / 7,
        );
      }
    }
  }

  String _getNoteUnicode(MusicalNote note, bool isUpsideDown) {
    // Define unicode characters for note durations
    List<NoteUnicodeCharacters> unicodeCharacters = [
      NoteUnicodeCharacters(normal: '\ue1d2', upsideDown: '\ue1d2'), //whole
      NoteUnicodeCharacters(normal: '\ue1d3', upsideDown: '\ue1d4'), //half
      NoteUnicodeCharacters(normal: '\ue1d5', upsideDown: '\ue1d6'), //quarter
      NoteUnicodeCharacters(normal: '\ue1d7', upsideDown: '\ue1d8'), //eighth
      NoteUnicodeCharacters(normal: '\ue1d9', upsideDown: '\ue1da'), //sixteenth
      NoteUnicodeCharacters(
          normal: '\ue1db', upsideDown: '\ue1dc'), //thirtysecond
      NoteUnicodeCharacters(
          normal: '\ue1dd', upsideDown: '\ue1de'), //sixtyfourth
    ];

    // Define clef unicode characters
    Map<String, String> clefCharacters = {
      'Treble': '\uf472',
      'Bass': '\uf474',
      'Alto': '\uf473',
      'Tenor': '\uf473',
    };

    switch (note.type) {
      case NoteType.whole:
      case NoteType.half:
      case NoteType.quarter:
      case NoteType.eighth:
      case NoteType.sixteenth:
      case NoteType.thirtySecond:
      case NoteType.sixtyFourth:
        final index = note.type.index;
        if (index < unicodeCharacters.length) {
          return isUpsideDown
              ? unicodeCharacters[index].upsideDown
              : unicodeCharacters[index].normal;
        }
        return note.unicodeCharacter;
      case NoteType.clef:
        return clefCharacters[note.clefType] ?? note.unicodeCharacter;
      case NoteType.rest:
      case NoteType.accidental:
      case NoteType.bar:
      case NoteType.timeSignature:
      case NoteType.keySignature:
      case NoteType.space:
        return note.unicodeCharacter;
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
