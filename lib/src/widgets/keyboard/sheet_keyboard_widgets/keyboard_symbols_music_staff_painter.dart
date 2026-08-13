import 'package:flutter/material.dart';
import 'package:music_keyboard/models/note_unicode_characters.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';

class KeyboardSymbolsMusicStaffPainter extends CustomPainter {
  final NoteUnicodeCharacters unicodeCharacter;
  final String accidentalCharacter;
  final MusicalNote musicalNote;
  final int index;
  final BuildContext? context;
  final bool isDisabled;

  KeyboardSymbolsMusicStaffPainter({
    required this.unicodeCharacter,
    required this.accidentalCharacter,
    required this.musicalNote,
    required this.index,
    this.context,
    this.isDisabled = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0;

    final lineScaleFactor = 15;
    final lineSpacing = size.height / lineScaleFactor;
    final staffTop = (size.height - (4 * lineSpacing)) / 2;
    final staffCenter = staffTop + (2 * lineSpacing);

    for (int i = 0; i < 5; i++) {
      final y = staffTop + (i * lineSpacing);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final double noteY = calculateNoteYVerticalKeyboard(
        musicalNote.pitch, musicalNote.octave, lineSpacing, staffTop);

    double noteWidth = size.width / 3;

    drawLedgerLines(canvas, paint, noteY, size.width / 2, noteWidth,
        lineSpacing, staffTop, accidentalCharacter != '');

    bool isUpsideDownNote = noteY <= staffCenter;

    final textPainter = TextPainter(
      text: TextSpan(
        text: isUpsideDownNote
            ? unicodeCharacter.upsideDown
            : unicodeCharacter.normal,
        style: TextStyle(
          fontFamily: 'Bravura',
          fontSize: size.height / 4.4,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    double x = (size.width - textPainter.width) / 2;
    final y = (calculateNoteYVerticalKeyboard(
            musicalNote.pitch, musicalNote.octave, lineSpacing, staffTop)) -
        (textPainter.height / 2);

    if (accidentalCharacter != '') {
      x = x + 6;
    } else if (!isUpsideDownNote && musicalNote.type != NoteType.whole) {
      x = x + 3;
    }

    textPainter.paint(canvas, Offset(x, y));

    if (accidentalCharacter != '') {
      double noteX = 0.0;
      final accidentalPainter = TextPainter(
        text: TextSpan(
          text: accidentalCharacter,
          style: TextStyle(
            fontFamily: 'Bravura',
            fontSize: size.height / 5.0,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      if (accidentalCharacter != 'dotted_rest') {
        accidentalPainter.layout();
        final accidentalX = (size.width - textPainter.width) / 2 -
            accidentalPainter.width * 0.9;

        accidentalPainter.paint(
            canvas, Offset(accidentalX, isUpsideDownNote ? y + 13 : y + 5));
      } else {
        noteX = (size.width - textPainter.width) / 2 * 1.2;

        final Paint handlePaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(noteX + 12, noteY + 5), 1.5, handlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

void drawLedgerLines(Canvas canvas, Paint paint, double noteY, double noteX,
    double noteWidth, double lineSpacing, double staffTop, bool hasAccidental) {
  final double staffBottom = staffTop + (4 * lineSpacing);

  double leftX = hasAccidental ? -2 : 2;
  double rightX = hasAccidental ? 8 : 2;

  if (noteY <= staffTop - lineSpacing) {
    for (double y = staffTop - lineSpacing;
        y >= noteY - lineSpacing / 3;
        y -= lineSpacing) {
      canvas.drawLine(
        Offset(noteX - (noteWidth / 3) - leftX, y),
        Offset(noteX + (noteWidth / 3) + rightX, y),
        paint..strokeWidth = 1.0,
      );
    }
  } else if (noteY >= staffBottom + lineSpacing) {
    for (double y = staffBottom + lineSpacing;
        y <= noteY + lineSpacing / 3;
        y += lineSpacing) {
      canvas.drawLine(
        Offset(noteX - (noteWidth / 3) - leftX, y),
        Offset(noteX + (noteWidth / 3) + rightX, y),
        paint..strokeWidth = 1.0,
      );
    }
  }
}
