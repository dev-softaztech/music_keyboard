import 'package:flutter/material.dart';
import 'package:music_keyboard/models/note_unicode_characters.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:provider/provider.dart';
import 'package:music_keyboard/src/providers/selected_accidental_provider.dart';
import 'package:music_keyboard/src/widgets/keyboard/sheet_keyboard_widgets/keyboard_symbols_music_staff_painter.dart';

class MusicKey extends StatefulWidget {
  final NoteUnicodeCharacters unicodeCharacter;
  final String pitch;
  final int octave;
  final NoteType type;
  final bool isConnected;
  final void Function(MusicalNote note)? onTap;
  final int index;
  final bool isDisabled;
  final bool isChordAdded;

  const MusicKey(
      {super.key,
      required this.unicodeCharacter,
      required this.pitch,
      required this.octave,
      required this.type,
      required this.isConnected,
      required this.onTap,
      required this.index,
      this.isDisabled = false,
      this.isChordAdded = false});

  @override
  _MusicKeyState createState() => _MusicKeyState();
}

class _MusicKeyState extends State<MusicKey> {
  bool isPressed = false;

  void _handleTap() {
    if (widget.isDisabled || widget.onTap == null) return;

    setState(() {
      isPressed = true;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          isPressed = false;
        });
      }
    });

    widget.onTap!(MusicalNote(
        pitch: widget.pitch,
        octave: widget.octave,
        type: widget.type,
        isBeamed: widget.isConnected,
        unicodeCharacter: widget.unicodeCharacter.normal));
  }

  @override
  Widget build(BuildContext context) {
    final selectedAccidental =
        context.watch<SelectedAccidentalProvider>().selectedAccidental;

    return GestureDetector(
      onTap: widget.isDisabled ? null : _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: widget.isDisabled
              ? Colors.grey[300]
              : isPressed
                  ? Colors.grey[400]
                  : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isDisabled
                ? Colors.grey[400]!
                : widget.isChordAdded
                    ? Colors.blue
                    : const Color.fromARGB(255, 130, 130, 130),
            width: widget.isChordAdded ? 2.0 : 1.0,
          ),
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
            isDisabled: widget.isDisabled,
          ),
        ),
      ),
    );
  }
}
