import 'package:flutter/material.dart';
import 'package:music_keyboard/models/sheet_rows.dart';

/// Draws row-level header text on the main music sheet: title, composer,
/// tempo, and swing markings.
///
/// This is a plain (non-CustomPainter) helper class used by
/// [MusicSheetPainter] via composition. All methods take the
/// [Canvas]/geometry they need as explicit arguments and hold no mutable
/// state of their own.
class SheetHeaderTextPainter {
  void drawTitleAndComposer(Canvas canvas, Size size, String title,
      String composer, int? renderStartRow, int? renderEndRow,
      bool showTitleAndComposer) {
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

  /// Draw tempo above the left side of a row if set
  void drawTempo(Canvas canvas, int rowIndex, double staffTop,
      double tempoTextY, List<SheetRows> sheetNoteRows) {
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
  void drawSwing(Canvas canvas, int rowIndex, double staffTop,
      double tempoTextY, List<SheetRows> sheetNoteRows) {
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
}
