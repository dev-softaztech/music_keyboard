import 'package:flutter/material.dart';
import 'package:music_keyboard/src/utils/keyboard_utils/unicode_mapper.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';
import 'package:provider/provider.dart';
import 'package:music_keyboard/src/providers/selected_unicode_provider.dart';
import 'package:music_keyboard/src/providers/is_connected_provider.dart';
import 'package:music_keyboard/models/music_note.dart';

class KeyboardBySymbols extends StatelessWidget {
  final void Function(MusicalNote note) onKeyPress;
  final String keyType;

  const KeyboardBySymbols(
      {super.key, required this.onKeyPress, required this.keyType});

  @override
  Widget build(BuildContext context) {
    final isConnected = context.watch<IsConnectedProvider>().isConnected;
    double screenWidth = MediaQuery.of(context).size.width;

    final selectedCharacter =
        context.watch<SelectedUnicodeProvider>().selectedCharacter;

    NoteType noteType = NoteType.whole;
    if (keyType == "clefs") {
      noteType = NoteType.clef;
    } else if (keyType == "rests") {
      noteType = NoteType.rest;
    } else if (keyType == "accidentals") {
      noteType = NoteType.accidental;
    } else if (keyType == "notes") {
      noteType = mapUnicodeToNoteType(selectedCharacter);
    }

    return Center(
        child: SizedBox(
      height: 150,
      width: screenWidth - 10,
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 15, // Total keys in one row
            crossAxisSpacing: 2, // Space between columns
            mainAxisSpacing: 0, // Space between rows
            childAspectRatio: 0.19 // / (keyHeight / parentHeight),
            ),
        itemCount: 15, // Total number of keys
        itemBuilder: (context, index) {
          return MusicKey(
              unicodeCharacter: selectedCharacter,
              pitch: _getPitch(index),
              octave: _getOctave(index),
              type: noteType,
              isConnected: isConnected,
              //height: 150, //keyHeight, // Pass the desired height
              onTap: (note) => onKeyPress(note),
              index: index,
              selectedCharacter: selectedCharacter);
        },
      ),
    ));
  }

  // Map the index to a pitch
  String _getPitch(int index) {
    const pitches = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
    return pitches[index % pitches.length];
  }

  // Map the index to an octave
  int _getOctave(int index) {
    return 4 + (index ~/ 7); // Cycle through octaves
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
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: isPressed ? Colors.grey[400] : Colors.white, // Darken on press
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color.fromARGB(255, 130, 130, 130)),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.3), // Black with 30% opacity
              blurRadius: 3, // Blurry effect
              spreadRadius: 1, // Expands shadow
              offset: const Offset(0, 4), // Moves shadow to bottom-right
            ),
          ],
        ),
        child: CustomPaint(
          painter: KeyboardSymbolsMusicStaffPainter(
            unicodeCharacter: widget.unicodeCharacter,
            musicalNote: MusicalNote(
              pitch: widget.pitch,
              octave: widget.octave,
              type: widget.type,
              isConnected: widget.isConnected,
            ),
            index: widget.index,
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

  KeyboardSymbolsMusicStaffPainter(
      {required this.unicodeCharacter,
      required this.musicalNote,
      required this.index});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0; // Slightly thinner lines for smaller keys

    // Calculate dynamic spacing for the 5 staff lines
    final lineSpacing = size.height / 15; // Scale based on the smaller height
    final staffTop =
        (size.height - (4 * lineSpacing)) / 2; // Center the staff vertically
    final staffBottom = staffTop + (4 * lineSpacing);

    // Draw the 5 staff lines
    for (int i = 0; i < 5; i++) {
      final y = staffTop + (i * lineSpacing);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // **Draw an extra staff line below if index is 0, 1, or 2**
    if (index <= 1) {
      double extraLineY = staffBottom + lineSpacing; // Position below the staff
      canvas.drawLine(
          Offset(0, extraLineY), Offset(size.width, extraLineY), paint);
    }

    // **Draw an extra staff line above if index is 14 or higher**
    if (index >= 13) {
      double extraLineY = staffTop - lineSpacing; // Position above the staff
      canvas.drawLine(
          Offset(0, extraLineY), Offset(size.width, extraLineY), paint);
    }

    // Draw the Unicode character at the given note position
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
