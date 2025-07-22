import 'package:flutter/material.dart';
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

    NoteType noteType = mapUnicodeToNoteType(selectedCharacter);

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
    required String selectedCharacter,
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
              index: index,
              selectedCharacter: selectedCharacter,
            );
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
  final String unicodeCharacter;
  final String pitch;
  final int octave;
  final NoteType type;
  final bool isConnected;
  final void Function(MusicalNote note) onTap;
  final int index;
  final String selectedCharacter;

  const MusicKey(
      {super.key,
      required this.unicodeCharacter,
      required this.pitch,
      required this.octave,
      required this.type,
      required this.isConnected,
      required this.onTap,
      required this.index,
      required this.selectedCharacter});

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
        isConnected: widget.isConnected,
        unicodeCharacter: widget.selectedCharacter));
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
            unicodeCharacter: widget.type != NoteType.clef &&
                    widget.type != NoteType.rest &&
                    widget.type != NoteType.accidental &&
                    selectedAccidental.isNotEmpty
                ? selectedAccidental // Use the selected accidental for notes
                : widget.unicodeCharacter,
            musicalNote: MusicalNote(
              pitch: widget.pitch,
              octave: widget.octave,
              type: widget.type,
              isConnected: widget.isConnected,
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
  final String unicodeCharacter; // Unicode character to draw
  final MusicalNote musicalNote; // Vertical position of the character
  final int index;
  final BuildContext? context;

  KeyboardSymbolsMusicStaffPainter({
    required this.unicodeCharacter,
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

    // Draw the 5 staff lines
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
    drawLedgerLines(
        canvas, paint, noteY, size.width / 2, noteWidth, lineSpacing, staffTop);

    // For notes with accidentals, we need to draw both the accidental and the note
    bool isAccidental = unicodeCharacter == '\uF4DE' || // sharp
        unicodeCharacter == '\uF4DF' || // sharp
        unicodeCharacter == '\uF4DC' || // flat
        unicodeCharacter == '\uF4E0' || // flat
        unicodeCharacter == '\uF4DD'; // natural

    if (musicalNote.type == NoteType.accidental ||
        (musicalNote.type != NoteType.clef &&
            musicalNote.type != NoteType.rest &&
            isAccidental)) {
      // Draw the accidental
      final accidentalPainter = TextPainter(
        text: TextSpan(
          text: unicodeCharacter,
          style: TextStyle(
            fontFamily: 'Bravura',
            fontSize: size.height / 5.0, // Slightly smaller than the note
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      // Use the selected unicode character for the note symbol
      String noteSymbol;

      // If it's an accidental, we need to use the note symbol from the selected unicode
      if (isAccidental) {
        // These are the note symbols
        if (musicalNote.type == NoteType.whole) {
          noteSymbol = '\ue1d2'; // Whole note
        } else if (musicalNote.type == NoteType.half) {
          noteSymbol = '\ue1d3'; // Half note
        } else if (musicalNote.type == NoteType.quarter) {
          noteSymbol = '\ue1d5'; // Quarter note
        } else if (musicalNote.type == NoteType.eighth) {
          noteSymbol = '\ue1d7'; // Eighth note
        } else if (musicalNote.type == NoteType.sixteenth) {
          noteSymbol = '\ue1d9'; // Sixteenth note
        } else if (musicalNote.type == NoteType.thirtySecond) {
          noteSymbol = '\ue1db'; // Thirty-second note
        } else if (musicalNote.type == NoteType.sixtyFourth) {
          noteSymbol = '\ue1dd'; // Sixty-fourth note
        } else {
          noteSymbol = '\ue1d5'; // Default to quarter note
        }
      } else {
        // If it's not an accidental, use the selected unicode character
        noteSymbol = unicodeCharacter;
      }

      final notePainter = TextPainter(
        text: TextSpan(
          text: noteSymbol,
          style: TextStyle(
            fontFamily: 'Bravura',
            fontSize: size.height / 4.4,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      accidentalPainter.layout();
      notePainter.layout();

      // Calculate positions
      final noteY = (calculateNoteYVerticalKeyboard(
              musicalNote.pitch, musicalNote.octave, lineSpacing, staffTop)) -
          (notePainter.height / 2) +
          0.5;

      // Position the accidental to the left of the note
      final accidentalX =
          (size.width - notePainter.width) / 2 - accidentalPainter.width * 0.8;
      final noteX =
          (size.width - notePainter.width) / 2 + accidentalPainter.width * 0.2;

      // Draw the accidental and the note
      accidentalPainter.paint(canvas, Offset(accidentalX, noteY));
      notePainter.paint(canvas, Offset(noteX, noteY));
    } else {
      // For other types, just draw the unicode character
      final textPainter = TextPainter(
        text: TextSpan(
          text: unicodeCharacter,
          style: TextStyle(
            fontFamily: 'Bravura',
            fontSize: size.height / 4.4, // Dynamically scale Unicode size
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      final x = (size.width - textPainter.width) / 2; // Center horizontally
      final y = (calculateNoteYVerticalKeyboard(
              musicalNote.pitch, musicalNote.octave, lineSpacing, staffTop)) -
          (textPainter.height / 2) +
          0.5; // Position vertically

      textPainter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;

  // Draw ledger lines for notes that are above or below the staff
  void drawLedgerLines(Canvas canvas, Paint paint, double noteY, double noteX,
      double noteWidth, double lineSpacing, double staffTop) {
    final double staffBottom =
        staffTop + (4 * lineSpacing); // Bottom staff line

    // Determine if the note is above or below the staff
    if (noteY < staffTop) {
      // Draw ledger lines above the staff
      for (double y = staffTop - lineSpacing;
          y >= noteY - lineSpacing / 2;
          y -= lineSpacing) {
        canvas.drawLine(
          Offset(noteX - (noteWidth / 3) - 7, y),
          Offset(noteX + (noteWidth / 3) + 7, y),
          paint..strokeWidth = 1.0,
        );
      }
    } else if (noteY > staffBottom) {
      // Draw ledger lines below the staff
      for (double y = staffBottom + lineSpacing;
          y <= noteY + lineSpacing / 2;
          y += lineSpacing) {
        canvas.drawLine(
          Offset(noteX - (noteWidth / 2) - 7, y),
          Offset(noteX + (noteWidth / 2) + 7, y),
          paint..strokeWidth = 1.0,
        );
      }
    }
  }
}
