import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/key_signature_position_calculator.dart';

class KeySignaturePainter extends CustomPainter {
  final String keySignatureName;
  final double startingY;
  final bool zigzagUp;
  final int symbolCount;
  final bool isSharp;
  String clefType;

  KeySignaturePainter(
      {required this.keySignatureName,
      required this.startingY,
      required this.zigzagUp,
      required this.symbolCount,
      required this.isSharp,
      required this.clefType});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0;

    // Calculate staff line positions at the bottom of the key
    final double staffHeight = size.height * 0.5; // Staff takes up bottom 40%
    final double lineSpacing = staffHeight / 6; // 5 lines with spacing
    final double staffTop = size.height - staffHeight;

    // Draw 5 staff lines
    for (int i = 0; i < 5; i++) {
      final y = staffTop + (i * lineSpacing);
      canvas.drawLine(Offset(5, y), Offset(size.width - 5, y), paint);
    }

    // Draw key signature name above the staff
    final textPainter = TextPainter(
      text: TextSpan(
        text: keySignatureName,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final nameX = 10.0;
    final nameY = staffTop - textPainter.height - 20;
    textPainter.paint(canvas, Offset(nameX, nameY));

    // Draw sharp or flat symbols
    final String symbol = isSharp ? '\u266F' : '\u266D';

    final (sharpPositions, flatPositions) =
        getPositionsForClefType(clefType, staffTop, lineSpacing);

    final positions = isSharp ? sharpPositions : flatPositions;
    //final double symbolSpacing = 12.0; // Horizontal spacing between symbols
    final double symbolSpacing = size.width / (symbolCount + 1);

    // Draw the symbols
    for (int i = 0; i < symbolCount && i < positions.length; i++) {
      final symbolPainter = TextPainter(
        text: TextSpan(
          text: symbol,
          style: TextStyle(
            fontFamily: 'Bravura',
            fontSize: 36,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      symbolPainter.layout();

      final double symbolX = 10 + (i * math.min(symbolSpacing, 12));
      final double symbolY = positions[i] - (symbolPainter.height / 2);

      symbolPainter.paint(canvas, Offset(symbolX, symbolY));
    }
/*
    // Calculate symbol positions
    final double symbolSpacing = size.width / (symbolCount + 1);
    final double symbolSize = 24.0;

    for (int i = 0; i < symbolCount; i++) {
      final symbolPainter = TextPainter(
        text: TextSpan(
          text: symbol,
          style: TextStyle(
            fontFamily: 'Bravura',
            fontSize: symbolSize,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      symbolPainter.layout();

      // Calculate X position
      final double symbolX =
          symbolSpacing * (i + 1) - (symbolPainter.width / 2);

      // Calculate Y position with zigzag pattern
      double symbolY = startingY;

      // Apply zigzag pattern - alternate up and down
      if (i > 0) {
        final double zigzagOffset = lineSpacing * 0.5; // Half a line spacing
        if (zigzagUp) {
          symbolY += (i % 2 == 0) ? 0 : -zigzagOffset;
        } else {
          symbolY += (i % 2 == 0) ? 0 : zigzagOffset;
        }
      }

      symbolPainter.paint(canvas, Offset(symbolX, symbolY));*/
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
