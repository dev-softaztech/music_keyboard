import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';

void drawGuitarTabRowClef(Canvas canvas, double lineSpacing, double staffTop,
    double noteX, Color noteColour) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: '\uF40C',
      style: TextStyle(
        fontFamily: 'Bravura',
        fontSize: 35,
        color: noteColour,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  textPainter.layout();
  final offsetX = noteX - textPainter.width / 2;
  double offsetY = staffTop - (lineSpacing * 4) - 1;
  offsetY = offsetY - 4;

  textPainter.paint(canvas, Offset(offsetX, offsetY + 0.5));
}

void drawGuitarTabFrets(Canvas canvas, MusicalNote parentChord,
    double lineSpacing, double staffTop, double noteX, Color noteColour) {
  if (parentChord.childNotes == null || parentChord.childNotes!.isEmpty) {
    return;
  }

  for (var childNote in parentChord.childNotes!) {
    double stringY = staffTop + (childNote.octave * lineSpacing);

    final textPainter = TextPainter(
      text: TextSpan(
        text: childNote.unicodeCharacter,
        style: TextStyle(
          fontSize: 11,
          color: noteColour,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final double xPos = noteX - (textPainter.width / 2);
    final double yPos = stringY - (textPainter.height / 2);

    final Paint backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final double paddingVertical = 2;
    final double paddingHorizontal = 0.5;
    final Rect backgroundRect = Rect.fromLTRB(
      xPos - paddingHorizontal,
      yPos + paddingVertical,
      xPos + textPainter.width + paddingHorizontal,
      yPos + textPainter.height - paddingVertical,
    );

    canvas.drawRect(backgroundRect, backgroundPaint);

    textPainter.paint(canvas, Offset(xPos, yPos));
  }
}
