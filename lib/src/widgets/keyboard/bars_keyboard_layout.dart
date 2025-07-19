import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';

class BarsKeyboardLayout extends StatelessWidget {
  final void Function(MusicalNote note) onKeyPress;

  const BarsKeyboardLayout({super.key, required this.onKeyPress});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    List<(String unicodeCharacter, double offset)> barUnicodeCharacters = [
      ('\ue030', 20.0),
      ('\ue031', 20.0),
      ('\ue032', 20.0),
      ('\ue033', 20.0),
      ('\ue034', 20.0),
      ('\uf45c', 20.0),
      ('\ue032', 20.0),
      //('\uf473', 0.0),
    ];

    return Center(
        child: SizedBox(
      height: 320,
      width: screenWidth - 10,
      child: Row(
        children: [
          SizedBox(
            width: (screenWidth - 10) * 0.55,
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, // Total keys in one row
                  crossAxisSpacing: 5, // Space between columns
                  mainAxisSpacing: 5, // Space between rows
                  childAspectRatio: 0.77 // / (keyHeight / parentHeight),
                  ),
              itemCount: barUnicodeCharacters.length, // Total number of keys
              itemBuilder: (context, index) {
                return MusicKey(
                    onTap: (note) => onKeyPress(note),
                    index: index,
                    unicodeCharacter: barUnicodeCharacters[index].$1,
                    characterOffset: barUnicodeCharacters[index].$2);
              },
            ),
          )
        ],
      ),
    ));
  }
}

class MusicKey extends StatefulWidget {
  final void Function(MusicalNote note) onTap;
  final int index;
  final String unicodeCharacter;
  final double characterOffset;

  const MusicKey(
      {super.key,
      required this.onTap,
      required this.index,
      required this.unicodeCharacter,
      required this.characterOffset});

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
        pitch: "",
        octave: 0,
        type: NoteType.bar,
        isConnected: false,
        unicodeCharacter: widget.unicodeCharacter));
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
            characterOffset: widget.characterOffset,
            index: widget.index,
          ),
        ),
      ),
    );
  }
}

class KeyboardSymbolsMusicStaffPainter extends CustomPainter {
  final String unicodeCharacter;
  final double characterOffset;
  final int index;

  KeyboardSymbolsMusicStaffPainter(
      {required this.unicodeCharacter,
      required this.characterOffset,
      required this.index});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 0.7; // Slightly thinner lines for smaller keys

    // Calculate dynamic spacing for the 5 staff lines
    final lineSpacing =
        10.0; //size.height / 9; // Scale based on the smaller height
    final staffTop =
        (size.height - (4 * lineSpacing)) / 2; // Center the staff vertically
    final double staffHeight = 4 * lineSpacing;

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
          fontSize: lineSpacing *
              4, //size.height / 2.5, // Dynamically scale Unicode size
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    final double x = (size.width - textPainter.width) / 2;
    final double y = staffTop +
        characterOffset +
        (staffHeight / 2) -
        (textPainter.height / 2); // Center dynamically

    textPainter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
