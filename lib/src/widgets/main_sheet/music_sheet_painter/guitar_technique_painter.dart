import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';

/// Draws guitar-technique markings on the main music sheet: bends, mutes,
/// harmonics, vibrato, slides, taps, and pick strokes.
///
/// This is a plain (non-CustomPainter) helper class used by
/// [MusicSheetPainter] via composition. All methods take the
/// [Canvas]/[Paint]/geometry they need as explicit arguments and hold no
/// mutable state of their own.
class GuitarTechniquePainter {
  void drawArrowHead(Canvas canvas, Paint paint, double peakX, double peakY,
      String labelText, Color noteColour, bool isUpArrow) {
    final double arrowWidth = 3.0;
    final double arrowHeight = 6.0;

    Paint arrowPaint = paint;
    arrowPaint.style = PaintingStyle.fill;
    arrowPaint.color = noteColour;
    arrowPaint.isAntiAlias = true;

    final Path arrowHead = Path();
    if (isUpArrow) {
      peakY = peakY - 5;
      arrowHead.moveTo(peakX, peakY);
      arrowHead.lineTo(peakX - arrowWidth, peakY + arrowHeight);
      arrowHead.lineTo(peakX + arrowWidth, peakY + arrowHeight);
      arrowHead.close();
    } else {
      peakY = peakY + 0;
      arrowHead.moveTo(peakX, peakY);
      arrowHead.lineTo(peakX - arrowWidth, peakY - arrowHeight);
      arrowHead.lineTo(peakX + arrowWidth, peakY - arrowHeight);
      arrowHead.close();
    }

    canvas.drawPath(arrowHead, arrowPaint);

    if (isUpArrow) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(
            color: noteColour,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(peakX - textPainter.width / 2, peakY - 15));
    }
  }

  /// Helper function to draw upward curved line from start to peak
  void drawBendCurveUp(
      Canvas canvas,
      Paint paint,
      double startX,
      double startY,
      double endX,
      double endY,
      double currentRowSpacing,
      bool isRelease) {
    final Path path = Path();
    path.moveTo(startX + 8, startY - 2);

    double bezierEndY = endY;
    if (isRelease) {
      startX = startX + (currentRowSpacing * 0.35);
      bezierEndY = bezierEndY + (currentRowSpacing * 0.35);
    } else {
      startX = startX + (currentRowSpacing * 0.8);
      bezierEndY = bezierEndY + (currentRowSpacing * 0.3);
    }

    path.quadraticBezierTo(startX, bezierEndY, endX, endY);
//(startX + endX) / 2
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.2;
    canvas.drawPath(path, paint);
  }

  /// Helper function to draw downward curved line from peak to end
  void drawBendCurveDown(Canvas canvas, Paint paint, double startX,
      double startY, double endX, double? endY, double currentRowSpacing) {
    final Path path = Path();
    path.moveTo(startX + 5, startY - 4);

    startX = startX + (currentRowSpacing * 0.35);
    double bezierStartY = startY + (currentRowSpacing * -0.2);

    path.quadraticBezierTo(startX, bezierStartY, endX, endY! - 6);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.2;
    canvas.drawPath(path, paint);
  }

  /// Draw bend arrow (single upward arrow with "full" label)
  void drawBend(
      Canvas canvas,
      Paint paint,
      double startX,
      double endX,
      double stringY,
      double staffTop,
      double lineSpacing,
      Color noteColour,
      double currentRowSpacing) {
    final double peakY = staffTop - 20;

    drawBendCurveUp(
        canvas, paint, startX, stringY, endX, peakY, currentRowSpacing, false);

    drawArrowHead(canvas, paint, endX, peakY, 'full', noteColour, true);
  }

  /// Draw pre-bend arrow (single upward arrow with "1/2" label)
  void drawPreBend(
      Canvas canvas,
      Paint paint,
      double startX,
      double endX,
      double stringY,
      double staffTop,
      double lineSpacing,
      Color noteColour,
      double currentRowSpacing) {
    final double peakY = staffTop - 20;
    startX = startX + 5;

    drawBendCurveUp(
        canvas, paint, startX, stringY, endX, peakY, currentRowSpacing, false);

    drawArrowHead(canvas, paint, endX, peakY, '1/2', noteColour, true);
  }

  /// Draw bend-release arrow (up then down with "full" label)
  void drawBendRelease(
      Canvas canvas,
      Paint paint,
      double startX,
      double endX,
      double stringY,
      double staffTop,
      double lineSpacing,
      Color noteColour,
      double currentRowSpacing,
      double? curveDownY) {
    // Calculate peak position above the staff
    final double peakY = staffTop - 20;

    double peakX = startX + (currentRowSpacing * 0.4);

    drawBendCurveUp(
        canvas, paint, startX, stringY, peakX, peakY, currentRowSpacing, true);

    drawBendCurveDown(
        canvas, paint, peakX, peakY, endX, curveDownY, currentRowSpacing);

    drawArrowHead(canvas, paint, peakX, peakY, 'full', noteColour, true);
    drawArrowHead(canvas, paint, endX, curveDownY!, 'full', noteColour, false);
  }

  /// Draw pre-bend-release arrow (up then down with "1/2" label)
  void drawPreBendRelease(
      Canvas canvas,
      Paint paint,
      double startX,
      double endX,
      double stringY,
      double staffTop,
      double lineSpacing,
      Color noteColour,
      double currentRowSpacing,
      double? curveDownY) {
    // Calculate peak position above the staff
    final double peakY = staffTop - 20;
    double peakX = startX + (currentRowSpacing * 0.4);

    // Draw curved line from start to peak - curve bulges downward under the arrow
    drawBendCurveUp(
        canvas, paint, startX, stringY, peakX, peakY, currentRowSpacing, true);

    // Draw curved line from peak back down to end
    drawBendCurveDown(
        canvas, paint, peakX, peakY, endX, curveDownY, currentRowSpacing);

    // Draw "1/2" label at peak
    drawArrowHead(canvas, paint, peakX, peakY, '1/2', noteColour, true);
    drawArrowHead(canvas, paint, endX, curveDownY!, '1/2', noteColour, false);
  }

  /// Draw hammer-left-hand: a quadratic bezier curve along the same string Y
  void drawHammerLeftHand(Canvas canvas, Paint paint, double startX,
      double endX, double stringY, Color noteColour) {
    final Path path = Path();
    final double controlX = (startX + endX) / 2;
    // Arc slightly above the string line
    stringY = stringY - 5;
    final double controlY = stringY - 20;

    path.moveTo(startX + 8, stringY);
    path.quadraticBezierTo(controlX, controlY, endX, stringY);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.2;
    paint.color = noteColour;
    canvas.drawPath(path, paint);
  }

  /// Draw slide-up: diagonal line going from lower-left to upper-right on the string,
  /// sitting between the current note and the next note position.
  void drawSlideUp(Canvas canvas, Paint paint, double x, double stringY,
      Color noteColour, double rowSpacing) {
    const double startOffset = 10.0;
    const double endOffset = 10.0;
    const double diagonalHeight = 5.0;

    final double startX = x + startOffset;
    final double endX = x + rowSpacing - endOffset;
    final double startY = stringY + diagonalHeight;
    final double endY = stringY - diagonalHeight;

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    paint.color = noteColour;

    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
  }

  /// Draw slide-down: diagonal line going from upper-left to lower-right on the string,
  /// sitting between the current note and the next note position.
  void drawSlideDown(Canvas canvas, Paint paint, double x, double stringY,
      Color noteColour, double rowSpacing) {
    const double startOffset = 10.0;
    const double endOffset = 10.0;
    const double diagonalHeight = 5.0;

    final double startX = x + startOffset;
    final double endX = x + rowSpacing - endOffset;
    final double startY = stringY - diagonalHeight;
    final double endY = stringY + diagonalHeight;

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    paint.color = noteColour;

    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
  }

  void drawDottedLine(Canvas canvas, Paint paint, TextPainter textPainter,
      double startX, double endX, double labelY, Color noteColour) {
    final double lineStartX = startX + textPainter.width + 2;
    final double lineY = labelY + (textPainter.height / 2);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    paint.color = noteColour;

    // Draw dotted line
    final double dashWidth = 5;
    final double dashSpace = 3;
    double currentX = lineStartX;

    while (currentX < endX) {
      canvas.drawLine(
        Offset(currentX, lineY),
        Offset(currentX + dashWidth, lineY),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }

    canvas.drawLine(
      Offset(currentX - dashSpace, lineY - 7.5),
      Offset(currentX - dashSpace, lineY + 7.5),
      paint,
    );
  }

  /// Draw mute technique (P.M. label with dotted line)
  void drawMute(
      Canvas canvas,
      Paint paint,
      double startX,
      double endX,
      double staffTop,
      double lineSpacing,
      Color noteColour,
      bool hasBend,
      bool isSingleChordSpan) {
    // Position label above staff, higher if there's also a bend
    final double labelY = hasBend ? staffTop - 60 : staffTop - 30;

    // Draw the "P.M." label
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'P.M.',
        style: TextStyle(
          color: noteColour,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(startX, labelY));

    if (!isSingleChordSpan) {
      drawDottedLine(
          canvas, paint, textPainter, startX, endX, labelY, noteColour);
    }
  }

  /// Draw pinch harmonic technique (P.H. label with dotted line)
  void drawPinchHarmonic(
      Canvas canvas,
      Paint paint,
      double startX,
      double endX,
      double staffTop,
      double lineSpacing,
      Color noteColour,
      bool hasBend,
      bool isSingleChordSpan) {
    // Position label above staff, higher if there's also a bend
    final double labelY = hasBend ? staffTop - 60 : staffTop - 30;

    // Draw the "P.H." label
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'P.H.',
        style: TextStyle(
          color: noteColour,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(startX, labelY));

    if (!isSingleChordSpan) {
      drawDottedLine(
          canvas, paint, textPainter, startX, endX, labelY, noteColour);
    }
  }

  /// Draw harmonic technique (Ham. label with dotted line)
  void drawHarmonic(
      Canvas canvas,
      Paint paint,
      double startX,
      double endX,
      double staffTop,
      double lineSpacing,
      Color noteColour,
      bool hasBend,
      bool isSingleChordSpan) {
    // Position label above staff, higher if there's also a bend
    final double labelY = hasBend ? staffTop - 60 : staffTop - 30;

    // Draw the "Ham." label
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Ham.',
        style: TextStyle(
          color: noteColour,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(startX, labelY));

    if (!isSingleChordSpan) {
      drawDottedLine(
          canvas, paint, textPainter, startX, endX, labelY, noteColour);
    }
  }

  /// Draw vibrato technique (vibrato unicode character with multiple instances)
  void drawVibrato(
      Canvas canvas,
      Paint paint,
      double startX,
      double endX,
      double staffTop,
      double lineSpacing,
      Color noteColour,
      bool hasBend,
      bool isSingleChordSpan,
      double rowSpacing) {
    final double labelY = hasBend ? staffTop - 70 : staffTop - 40;

    double distance = endX - startX;
    int symbolCount = 1;

    final double symbolWidth = 10.0;

    symbolCount = (distance / symbolWidth).floor();
    symbolCount = symbolCount < 1 ? 1 : symbolCount;

    for (int i = 0; i < symbolCount; i++) {
      double symbolX = startX + (i * symbolWidth);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '',
          style: TextStyle(
            fontFamily: 'Bravura',
            fontSize: 20,
            color: noteColour,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      double xPos = symbolX;
      textPainter.paint(canvas, Offset(xPos, labelY - 10));
    }
  }

  void drawTapRightHand(
      Canvas canvas,
      MusicalNote chord,
      Color noteColour,
      double x,
      double staffTop,
      double lineSpacing,
      List<MusicalNote> notes,
      int noteIndex) {
    double baseOffset = hasBendOrHarmonicOnChord(chord);

    // Check if this technique needs additional offset due to overlapping with other techniques
    bool needsAdditionalOffset = false;
    if (chord.tapRightHandCharacter.isNotEmpty) {
      // Only tap-right-hand gets the additional offset when overlapping
      bool hasPickUpward = chord.hasPickUpward;
      bool hasPickDownward = chord.hasPickDownward;

      if ((hasPickUpward || hasPickDownward) &&
          chord.tapRightHandCharacter.isNotEmpty) {
        needsAdditionalOffset = true;
      }
    }

    double symbolY = staffTop - 25 - baseOffset;
    if (needsAdditionalOffset) {
      symbolY -= 15; // Additional offset for tap-right-hand when overlapping
    }

    // Adjust position based on note height to avoid overlap
    if (noteIndex < notes.length) {
      double noteY = notes[noteIndex].noteY;
      if (noteY < symbolY + 20) {
        symbolY = noteY - 40;
      }
    }

    final textStyle = TextStyle(
      color: noteColour,
      fontSize: 16,
      fontFamily: 'Bravura',
    );
    final textSpan = TextSpan(
      text: chord.tapRightHandCharacter,
      style: textStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Center the symbol horizontally over the note
    double xPos = x - (textPainter.width / 2);
    double yPos = symbolY - 20;

    textPainter.paint(canvas, Offset(xPos, yPos));
  }

  void drawPickDownward(
      Canvas canvas,
      MusicalNote chord,
      Color noteColour,
      double x,
      double staffTop,
      double lineSpacing,
      List<MusicalNote> notes,
      int noteIndex) {
    double baseOffset = hasBendOrHarmonicOnChord(chord);

    double symbolY = staffTop - 25 - baseOffset;

    // Adjust position based on note height to avoid overlap
    if (noteIndex < notes.length) {
      double noteY = notes[noteIndex].noteY;
      if (noteY < symbolY + 20) {
        symbolY = noteY - 40;
      }
    }

    final textStyle = TextStyle(
      color: noteColour,
      fontSize: 24,
      fontFamily: 'Bravura',
    );
    final textSpan = TextSpan(
      text: '',
      style: textStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Center the symbol horizontally over the note
    double xPos = x - (textPainter.width / 2);
    double yPos = symbolY - 35;

    textPainter.paint(canvas, Offset(xPos, yPos));
  }

  void drawPickUpward(
      Canvas canvas,
      MusicalNote chord,
      Color noteColour,
      double x,
      double staffTop,
      double lineSpacing,
      List<MusicalNote> notes,
      int noteIndex) {
    double baseOffset = hasBendOrHarmonicOnChord(chord);

    double symbolY = staffTop - 25 - baseOffset;

    // Adjust position based on note height to avoid overlap
    if (noteIndex < notes.length) {
      double noteY = notes[noteIndex].noteY;
      if (noteY < symbolY + 20) {
        symbolY = noteY - 40;
      }
    }

    final textStyle = TextStyle(
      color: noteColour,
      fontSize: 24,
      fontFamily: 'Bravura',
    );
    final textSpan = TextSpan(
      text: '',
      style: textStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Center the symbol horizontally over the note
    double xPos = x - (textPainter.width / 2);
    double yPos = symbolY - 35;

    textPainter.paint(canvas, Offset(xPos, yPos));
  }

  /// Checks whether any chord in [chords] has a bend (on any childNote) whose
  /// normalized index range [j, normalizedBendEnd] overlaps with [startIndex, endIndex].
  /// Two ranges [a, b] and [c, d] overlap when a <= d && c <= b.
  bool hasBendOverlappingRange(
      List<MusicalNote> chords, int startIndex, int endIndex) {
    for (int j = 0; j < chords.length; j++) {
      final chord = chords[j];
      if (chord.childNotes == null) continue;

      for (var childNote in chord.childNotes!) {
        int? rawBendEnd;

        if (childNote.isBendStart && childNote.bendEndIndex != null) {
          rawBendEnd = childNote.bendEndIndex;
        } else if (childNote.isPreBendStart &&
            childNote.preBendEndIndex != null) {
          rawBendEnd = childNote.preBendEndIndex;
        } else if (childNote.isBendReleaseStart &&
            childNote.bendReleaseEndIndex != null) {
          rawBendEnd = childNote.bendReleaseEndIndex;
        } else if (childNote.isPreBendReleaseStart &&
            childNote.preBendReleaseEndIndex != null) {
          rawBendEnd = childNote.preBendReleaseEndIndex;
        }

        if (rawBendEnd != null) {
          // Normalize the bend end index the same way the painter does
          final int normalizedBendEnd = rawBendEnd == (j - 1)
              ? j
              : rawBendEnd < chords.length - 1
                  ? rawBendEnd
                  : chords.length - 1;

          // Check if bend range [j, normalizedBendEnd] overlaps technique range
          // [startIndex, endIndex]
          if (j <= endIndex && normalizedBendEnd >= startIndex) {
            return true;
          }
        }
      }
    }
    return false;
  }

  double hasBendOrHarmonicOnChord(MusicalNote chord) {
    bool hasBend = chord.isBendStart ||
        chord.isPreBendStart ||
        chord.isBendReleaseStart ||
        chord.isPreBendReleaseStart;

    bool hasHarmonic = chord.isMuteStart ||
        chord.isPinchHarmonicStart ||
        chord.isHarmonicStart;

    bool hasVibrato = chord.isVibratoStart;

    // Check for the three techniques that can overlap
    bool hasTapRightHand = chord.tapRightHandCharacter.isNotEmpty;
    bool hasPickUpward = chord.hasPickUpward;
    bool hasPickDownward = chord.hasPickDownward;

    if (chord.childNotes != null) {
      for (var childNote in chord.childNotes!) {
        hasBend = hasBend ||
            childNote.isBendStart ||
            childNote.isPreBendStart ||
            childNote.isBendReleaseStart ||
            childNote.isPreBendReleaseStart;

        hasHarmonic = hasHarmonic ||
            childNote.isMuteStart ||
            childNote.isPinchHarmonicStart ||
            childNote.isHarmonicStart;
      }
    }

    var returnOffset = 0.0;

    if (hasBend) returnOffset += 30;
    if (hasHarmonic) returnOffset += 25;
    if (hasVibrato) returnOffset += 15;

    return returnOffset;
  }
}
