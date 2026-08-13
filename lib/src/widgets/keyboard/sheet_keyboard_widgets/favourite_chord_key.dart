import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';
import 'package:music_keyboard/src/widgets/keyboard/sheet_keyboard_widgets/keyboard_symbols_music_staff_painter.dart';

class FavouriteChordKey extends StatefulWidget {
  final List<MusicalNote> childNotes;
  final bool isDotted;
  final VoidCallback onTap;

  const FavouriteChordKey({
    super.key,
    required this.childNotes,
    required this.isDotted,
    required this.onTap,
  });

  @override
  State<FavouriteChordKey> createState() => _FavouriteChordKeyState();
}

class _FavouriteChordKeyState extends State<FavouriteChordKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _pressed ? Colors.grey[400] : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isDotted
                ? Colors.blue.shade300
                : const Color.fromARGB(255, 130, 130, 130),
            width: widget.isDotted ? 1.5 : 1.0,
          ),
        ),
        child: CustomPaint(
          painter: _ChordKeyPainter(
            childNotes: widget.childNotes,
            isDotted: widget.isDotted,
          ),
        ),
      ),
    );
  }
}

class _ChordKeyPainter extends CustomPainter {
  final List<MusicalNote> childNotes;
  final bool isDotted;

  _ChordKeyPainter({required this.childNotes, required this.isDotted});

  /// SMuFL note-head glyphs (no stem).
  static const String _headWhole = '';
  static const String _headHalf = '';
  static const String _headBlack = '';

  String _headGlyph(NoteType type) {
    switch (type) {
      case NoteType.whole:
        return _headWhole;
      case NoteType.half:
        return _headHalf;
      default:
        return _headBlack;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (childNotes.isEmpty) return;

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0;

    final lineSpacing = size.height / 20;
    final staffTop = (size.height - 4 * lineSpacing) / 2;
    final staffCenter = staffTop + 2 * lineSpacing;

    for (int i = 0; i < 5; i++) {
      canvas.drawLine(
        Offset(0, staffTop + i * lineSpacing),
        Offset(size.width, staffTop + i * lineSpacing),
        paint,
      );
    }

    final noteYs = childNotes
        .map((n) => calculateNoteYVerticalKeyboard(
            n.pitch, n.octave, lineSpacing, staffTop))
        .toList();

    final double avgY = noteYs.reduce((a, b) => a + b) / noteYs.length;

    final bool stemDown = avgY <= staffCenter;

    final NoteType noteType = childNotes.first.type;
    final bool isWhole = noteType == NoteType.whole;
    final String headGlyph = _headGlyph(noteType);
    final double fontSize = size.height / 5;

    final TextPainter measurer = TextPainter(
      text: TextSpan(
        text: headGlyph,
        style: TextStyle(fontFamily: 'Bravura', fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double headW = measurer.width;
    final double headH = measurer.height;

    final double centreX = size.width / 2;

    final double headOffsetX =
        stemDown ? (centreX - headW / 2 + 2) : (centreX - headW / 2 - 2);

    for (int i = 0; i < childNotes.length; i++) {
      final MusicalNote child = childNotes[i];
      final double noteY = noteYs[i];
      final double noteX = centreX;
      final String accidental = child.accidentalCharacter;
      final bool hasAccidental =
          accidental.isNotEmpty && accidental != 'dotted_rest';

      drawLedgerLines(
          canvas, paint, noteY, noteX, headW, lineSpacing, staffTop, false);

      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: headGlyph,
          style: TextStyle(
            fontFamily: 'Bravura',
            fontSize: fontSize,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(headOffsetX, noteY - headH / 2));

      if (hasAccidental) {
        final TextPainter accPainter = TextPainter(
          text: TextSpan(
            text: accidental,
            style: TextStyle(
              fontFamily: 'Bravura',
              fontSize: size.height / 7.0,
              color: Colors.black,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final double accX = headOffsetX - accPainter.width * 1.3;

        final double accY =
            stemDown ? noteY - headH / 2 + 13 : noteY - headH / 2.8;
        accPainter.paint(canvas, Offset(accX, accY));
      }

      if (isDotted) {
        final Paint dotPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(headOffsetX + headW + 2.5, noteY + 1.5),
          1.5,
          dotPaint,
        );
      }
    }

    if (!isWhole) {
      final double topY = noteYs.reduce((a, b) => a < b ? a : b);
      final double bottomY = noteYs.reduce((a, b) => a > b ? a : b);
      final double stemLength = lineSpacing * 3.0;

      final stemPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 1.2;

      double stemTipY;
      double stemX;

      if (stemDown) {
        stemX = headOffsetX + 1;
        stemTipY = bottomY + stemLength;
        canvas.drawLine(
            Offset(stemX, topY), Offset(stemX, stemTipY), stemPaint);
      } else {
        stemX = headOffsetX + headW - 1;
        stemTipY = topY - stemLength;
        canvas.drawLine(
            Offset(stemX, bottomY), Offset(stemX, stemTipY), stemPaint);
      }

      final String? flagGlyph = _flagGlyph(noteType, stemDown);
      if (flagGlyph != null) {
        final double flagFontSize = fontSize * 0.8;

        final double flagY = stemTipY - flagFontSize * 2.0;

        final double flagX = stemX - flagFontSize * 0.01;

        final TextPainter flagPainter = TextPainter(
          text: TextSpan(
            text: flagGlyph,
            style: TextStyle(
              fontFamily: 'Bravura',
              fontSize: flagFontSize,
              color: Colors.black,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        flagPainter.paint(canvas, Offset(flagX, flagY));
      }
    }
  }

  static String? _flagGlyph(NoteType type, bool stemDown) {
    switch (type) {
      case NoteType.eighth:
        return stemDown ? '' : '';
      case NoteType.sixteenth:
        return stemDown ? '' : '';
      case NoteType.thirtySecond:
        return stemDown ? '' : '';
      case NoteType.sixtyFourth:
        return stemDown ? '' : '';
      default:
        return null;
    }
  }

  @override
  bool shouldRepaint(_ChordKeyPainter old) =>
      old.childNotes != childNotes || old.isDotted != isDotted;
}
