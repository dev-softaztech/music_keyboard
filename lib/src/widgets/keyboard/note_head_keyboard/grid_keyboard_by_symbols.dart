/*import 'package:flutter/material.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';
import 'package:provider/provider.dart';
import 'package:music_keyboard/src/providers/selected_unicode_provider.dart';
import 'package:music_keyboard/src/providers/is_connected_provider.dart';
import 'package:music_keyboard/models/music_note.dart';

class KeyboardBySymbolsGrid extends StatelessWidget {
  final void Function(MusicalNote note) onKeyPress;

  const KeyboardBySymbolsGrid({super.key, required this.onKeyPress});

  @override
  Widget build(BuildContext context) {
    final selectedCharacter =
        context.watch<SelectedUnicodeProvider>().selectedCharacter;
    final isConnected = context.watch<IsConnectedProvider>().isConnected;

    return SizedBox(
      height: 250, // Total height of the grid
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5, // 5 keys per row
          crossAxisSpacing: 5, // Spacing between columns
          mainAxisSpacing: 5, // Spacing between rows
          childAspectRatio: 1, // Square keys
        ),
        itemCount: 15, // Total number of keys (3 rows × 5 columns)
        itemBuilder: (context, index) {
          return MusicKey(
            unicodeCharacter: selectedCharacter,
            pitch: _getPitch(index),
            octave: _getOctave(index),
            type: _mapUnicodeToNoteType(selectedCharacter),
            isConnected: isConnected,
            onTap: (note) =>
                onKeyPress(note), // Pass the MusicalNote to the callback
          );
        },
      ),
    );
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

  // Map the Unicode character to a NoteType
  NoteType _mapUnicodeToNoteType(String unicodeCharacter) {
    const unicodeMap = {
      '\ue1d9': NoteType.sixteenth,
      '\ue1d7': NoteType.eighth,
      '\ue1d5': NoteType.quarter,
      '\ue1d3': NoteType.half,
      '\ue1d2': NoteType.whole,
    };

    return unicodeMap[unicodeCharacter] ??
        NoteType.quarter; // Default to Quarter
  }
}

class MusicKey extends StatelessWidget {
  final String unicodeCharacter; // Unicode character to display
  final String pitch; // The pitch of the note (e.g., C, D, E)
  final int octave; // The octave of the note (e.g., 4)
  final NoteType type; // The type of the note (whole, half, etc.)
  final bool isConnected; // Whether the note is connected to others
  final void Function(MusicalNote note) onTap; // Callback with the note

  const MusicKey({
    super.key,
    required this.unicodeCharacter,
    required this.pitch,
    required this.octave,
    required this.type,
    required this.isConnected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Create the MusicalNote and pass it to the onTap callback
    final note = MusicalNote(
      pitch: pitch,
      octave: octave,
      type: type,
      isConnected: isConnected,
    );

    return GestureDetector(
      onTap: () {
        onTap(note);
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black),
        ),
        child: CustomPaint(
          painter: KeyboardSymbolsMusicStaffPainter(
            unicodeCharacter: unicodeCharacter,
            musicalNote: note,
          ),
        ),
      ),
    );
  }
}

class KeyboardSymbolsMusicStaffPainter extends CustomPainter {
  final String unicodeCharacter; // Unicode character to draw
  final MusicalNote musicalNote; // Vertical position of the character

  KeyboardSymbolsMusicStaffPainter({
    required this.unicodeCharacter,
    required this.musicalNote,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5; // Slightly thinner lines for smaller keys

    // Calculate dynamic spacing for the 5 staff lines
    final lineSpacing = size.height / 8; // Scale based on the smaller height
    final staffTop =
        (size.height - (4 * lineSpacing)) / 2; // Center the staff vertically

    // Draw the 5 staff lines
    for (int i = 0; i < 5; i++) {
      final y = staffTop + (i * lineSpacing);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw the Unicode character at the given note position
    final textPainter = TextPainter(
      text: TextSpan(
        text: unicodeCharacter,
        style: TextStyle(
          fontFamily: 'Bravura',
          fontSize: size.height / 1, // Dynamically scale Unicode size
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    final x = (size.width - textPainter.width) / 2; // Center horizontally
    final y = (size.height / 2) +
        (calculateNoteYMainSheet(
            musicalNote.pitch, musicalNote.octave, lineSpacing, staffTop)) -
        (textPainter.height / 2); // Position vertically
    textPainter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
*/
