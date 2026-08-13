import 'package:flutter/material.dart';
import 'package:music_keyboard/models/sheet_rows.dart';

class SheetHeaderTextPainter {
  void drawTitleAndComposer(
      Canvas canvas,
      Size size,
      String title,
      String composer,
      int? renderStartRow,
      int? renderEndRow,
      bool showTitleAndComposer) {
    double titleY = 50;
    double composerY = 90;

    if (renderStartRow != null &&
        renderEndRow != null &&
        showTitleAndComposer) {
      titleY = 140;
      composerY = 175;
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

  void drawTempo(Canvas canvas, int rowIndex, double staffTop,
      double tempoTextY, List<SheetRows> sheetNoteRows) {
    final tempo = sheetNoteRows[rowIndex].rowProperties.tempoNumber;
    if (tempo <= 0) {
      return;
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

  void drawSwing(Canvas canvas, int rowIndex, double staffTop,
      double tempoTextY, List<SheetRows> sheetNoteRows) {
    final swing = sheetNoteRows[rowIndex].rowProperties.swing;
    if (!swing) {
      return;
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
}
