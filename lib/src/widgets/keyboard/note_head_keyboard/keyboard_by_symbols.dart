import 'package:flutter/material.dart';
import 'package:music_keyboard/src/utils/keyboard_utils/unicode_mapper.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';
import 'package:provider/provider.dart';
import 'package:music_keyboard/src/providers/selected_accidental_provider.dart';
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

    // For notes with accidentals, we need to draw both the accidental and the note
    bool isAccidental = unicodeCharacter == '\ue260' || // flat
        unicodeCharacter == '\ue261' || // natural
        unicodeCharacter == '\ue262' || // sharp
        unicodeCharacter == '\ue263' || // flat
        unicodeCharacter == '\ue264' || // sharp
        unicodeCharacter == '\ue265' || // flat
        unicodeCharacter == '\ue266' || // sharp
        unicodeCharacter == '\ue267' || // flat
        unicodeCharacter == '\ue268' || // sharp
        unicodeCharacter == '\ue269'; // natural

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
}
