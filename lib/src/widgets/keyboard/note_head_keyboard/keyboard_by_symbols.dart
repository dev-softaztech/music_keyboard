import 'package:flutter/material.dart';
import 'package:music_keyboard/models/note_unicode_characters.dart';
import 'package:music_keyboard/src/utils/keyboard_utils/unicode_mapper.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';
import 'package:provider/provider.dart';
import 'package:music_keyboard/src/providers/selected_accidental_provider.dart';
import 'package:music_keyboard/src/providers/selected_unicode_provider.dart';
import 'package:music_keyboard/src/providers/is_connected_provider.dart';
import 'package:music_keyboard/models/music_note.dart';

class KeyboardBySymbols extends StatefulWidget {
  final void Function(MusicalNote note) onKeyPress;
  final bool showLowerPair;

  const KeyboardBySymbols(
      {super.key, required this.onKeyPress, required this.showLowerPair});

  @override
  State<KeyboardBySymbols> createState() => _KeyboardBySymbolsState();
}

enum KeyboardRow {
  top, // Above the staff
  middle, // On the staff
  bottom // Below the staff
}

class _KeyboardBySymbolsState extends State<KeyboardBySymbols> {
  @override
  Widget build(BuildContext context) {
    final isConnected = context.watch<IsConnectedProvider>().isConnected;
    double screenWidth = MediaQuery.of(context).size.width;

    final selectedCharacter =
        context.watch<SelectedUnicodeProvider>().selectedCharacter;

    NoteType noteType = mapUnicodeToNoteType(selectedCharacter.normal);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Two keyboard rows - always visible
          SizedBox(
            height: 210, // Double the height for two rows
            width: screenWidth - 105,
            child: Column(
              children: [
                // Top row
                Expanded(
                  child: _buildKeyboardGrid(
                    selectedCharacter: selectedCharacter,
                    noteType: noteType,
                    isConnected: isConnected,
                    row: widget.showLowerPair
                        ? KeyboardRow.middle
                        : KeyboardRow.top,
                  ),
                ),
                const SizedBox(height: 5), // Small gap between rows
                // Bottom row
                Expanded(
                  child: _buildKeyboardGrid(
                    selectedCharacter: selectedCharacter,
                    noteType: noteType,
                    isConnected: isConnected,
                    row: widget.showLowerPair
                        ? KeyboardRow.bottom
                        : KeyboardRow.middle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardGrid({
    required NoteUnicodeCharacters selectedCharacter,
    required NoteType noteType,
    required bool isConnected,
    required KeyboardRow row,
  }) {
    return Padding(
      padding: EdgeInsets.zero, // No padding
      child: Container(
        color: Colors.transparent, // No background color
        margin: EdgeInsets.zero, // No margin
        child: GridView.builder(
          padding: EdgeInsets.zero, // No internal padding in the GridView
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 9,
              crossAxisSpacing: 2, // Space between columns
              mainAxisSpacing: 0, // Space between rows
              childAspectRatio: 0.32),
          itemCount: 9,
          itemBuilder: (context, index) {
            return MusicKey(
                unicodeCharacter: selectedCharacter,
                pitch: _getPitch(index, row),
                octave: _getOctave(index, row),
                type: noteType,
                isConnected: isConnected,
                onTap: (note) => widget.onKeyPress(note),
                index: index);
          },
        ),
      ),
    );
  }

  // Map the index to a pitch based on the current row
  String _getPitch(int index, KeyboardRow row) {
    const pitches = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

    // Starting pitch index depends on the row
    int startPitchIndex;
    switch (row) {
      case KeyboardRow.top:
        startPitchIndex = 5; // Start with 'A' for top row
        break;
      case KeyboardRow.middle:
        startPitchIndex = 3; // Start with 'F' for middle row
        break;
      case KeyboardRow.bottom:
        startPitchIndex = 1; // Start with 'D' for bottom row
        break;
    }

    // Calculate the pitch index by adding the starting index and the current index
    int pitchIndex = (startPitchIndex + index) % pitches.length;
    return pitches[pitchIndex];
  }

  // Map the index to an octave based on the current row
  int _getOctave(int index, KeyboardRow row) {
    // Base octave depends on which row we're showing
    int baseOctave;
    switch (row) {
      case KeyboardRow.top:
        baseOctave = 5; // Start with octave 5 for top row
        break;
      case KeyboardRow.middle:
        baseOctave = 4; // Start with octave 4 for middle row
        break;
      case KeyboardRow.bottom:
        baseOctave = 3; // Start with octave 3 for bottom row
        break;
    }

    // Calculate the pitch index to determine when to increment the octave
    const pitches = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
    int startPitchIndex;
    switch (row) {
      case KeyboardRow.top:
        startPitchIndex = 5; // Start with 'A' for top row
        // If we've gone past 'B' (index 6), increment the octave
        if ((startPitchIndex + index) >= pitches.length) {
          return baseOctave + ((startPitchIndex + index) ~/ pitches.length);
        }
        break;
      case KeyboardRow.middle:
        startPitchIndex = 3; // Start with 'F' for middle row
        // If we've gone past 'B' (index 6), increment the octave
        if ((startPitchIndex + index) >= pitches.length) {
          return baseOctave + ((startPitchIndex + index) ~/ pitches.length);
        }
        break;
      case KeyboardRow.bottom:
        startPitchIndex = 1; // Start with 'D' for bottom row
        // If we've gone past 'B' (index 6), increment the octave
        if ((startPitchIndex + index) >= pitches.length) {
          return baseOctave + ((startPitchIndex + index) ~/ pitches.length);
        }
        break;
    }

    return baseOctave;
  }
}

class MusicKey extends StatefulWidget {
  final NoteUnicodeCharacters unicodeCharacter;
  final String pitch;
  final int octave;
  final NoteType type;
  final bool isConnected;
  final void Function(MusicalNote note) onTap;
  final int index;

  const MusicKey(
      {super.key,
      required this.unicodeCharacter,
      required this.pitch,
      required this.octave,
      required this.type,
      required this.isConnected,
      required this.onTap,
      required this.index});

  @override
  _MusicKeyState createState() => _MusicKeyState();
}

class _MusicKeyState extends State<MusicKey> {
  bool isPressed = false;

  void _handleTap() {
    setState(() {
      isPressed = true;
    });

    // Delay to reset the effect
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          isPressed = false;
        });
      }
    });

    // Trigger the actual note event
    widget.onTap(MusicalNote(
        pitch: widget.pitch,
        octave: widget.octave,
        type: widget.type,
        isBeamed: widget.isConnected,
        unicodeCharacter: widget.unicodeCharacter.normal));
  }

  @override
  Widget build(BuildContext context) {
    // Get the selected accidental from the provider
    final selectedAccidental =
        context.watch<SelectedAccidentalProvider>().selectedAccidental;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: isPressed ? Colors.grey[400] : Colors.white, // Darken on press
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color.fromARGB(255, 130, 130, 130)),
        ),
        child: CustomPaint(
          painter: KeyboardSymbolsMusicStaffPainter(
            unicodeCharacter: widget.unicodeCharacter,
            accidentalCharacter: selectedAccidental,
            musicalNote: MusicalNote(
              pitch: widget.pitch,
              octave: widget.octave,
              type: widget.type,
              isBeamed: widget.isConnected,
            ),
            index: widget.index,
            context: context,
          ),
        ),
      ),
    );
  }
}

class KeyboardSymbolsMusicStaffPainter extends CustomPainter {
  final NoteUnicodeCharacters unicodeCharacter; // Unicode character to draw
  final String accidentalCharacter;
  final MusicalNote musicalNote; // Vertical position of the character
  final int index;
  final BuildContext? context;

  KeyboardSymbolsMusicStaffPainter({
    required this.unicodeCharacter,
    required this.accidentalCharacter,
    required this.musicalNote,
    required this.index,
    this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0; // Slightly thinner lines for smaller keys

    // Calculate dynamic spacing for the 5 staff lines
    final lineSpacing = size.height / 15; // Scale based on the smaller height
    final staffTop =
        (size.height - (4 * lineSpacing)) / 2; // Center the staff vertically
    final staffCenter = staffTop + (2 * lineSpacing);

    for (int i = 0; i < 5; i++) {
      final y = staffTop + (i * lineSpacing);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Determine if we need to draw ledger lines based on the note's position
    // Calculate the note's Y position
    final double noteY = calculateNoteYVerticalKeyboard(
        musicalNote.pitch, musicalNote.octave, lineSpacing, staffTop);

    // Get the width of the note for drawing ledger lines
    double noteWidth = size.width / 3; // Approximate width of the note

    // Draw ledger lines for notes above or below the staff
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
          fontSize: size.height / 4.4, // Dynamically scale Unicode size
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    double x = (size.width - textPainter.width) / 2; // Center horizontally
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
        Offset(noteX - (noteWidth / 2) - leftX, y),
        Offset(noteX + (noteWidth / 2) + rightX, y),
        paint..strokeWidth = 1.0,
      );
    }
  }
}
