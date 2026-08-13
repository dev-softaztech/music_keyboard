import 'package:flutter/material.dart';
import 'package:music_keyboard/models/note_unicode_characters.dart';
import 'package:music_keyboard/src/utils/keyboard_utils/unicode_mapper.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';
import 'package:provider/provider.dart';
import 'package:music_keyboard/src/providers/selected_unicode_provider.dart';
import 'package:music_keyboard/src/providers/is_connected_provider.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/widgets/keyboard/sheet_keyboard_widgets/music_key.dart';

class KeyboardBySymbols extends StatefulWidget {
  final void Function(MusicalNote note) onKeyPress;
  final bool showLowerPair;
  final List<SheetRows> sheetNoteRows;
  final SheetFormat sheetFormat;
  final List<MusicalNote>? chordChildNotes;

  const KeyboardBySymbols(
      {super.key,
      required this.onKeyPress,
      required this.showLowerPair,
      required this.sheetNoteRows,
      required this.sheetFormat,
      this.chordChildNotes});

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
          SizedBox(
            height: 220,
            width: screenWidth - 105,
            child: Column(
              children: [
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
                const SizedBox(height: 5),
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

  bool _isChordAdded(String pitch, int octave) {
    final childNotes = widget.chordChildNotes;
    if (childNotes == null) return false;
    return childNotes.any((n) => n.pitch == pitch && n.octave == octave);
  }

  Widget _buildKeyboardGrid({
    required NoteUnicodeCharacters selectedCharacter,
    required NoteType noteType,
    required bool isConnected,
    required KeyboardRow row,
  }) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Container(
        color: Colors.transparent,
        margin: EdgeInsets.zero,
        child: GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 9,
              crossAxisSpacing: 2,
              mainAxisSpacing: 0,
              childAspectRatio: 0.30),
          itemCount: 9,
          itemBuilder: (context, index) {
            final pitch = _getPitch(index, row);
            final octave = _getOctave(index, row);
            final isKeyDisabled = _isKeyDisabled(pitch, octave, row);

            final bool isChordAdded = _isChordAdded(pitch, octave);

            return MusicKey(
                unicodeCharacter: selectedCharacter,
                pitch: pitch,
                octave: octave,
                type: noteType,
                isConnected: isConnected,
                onTap: isKeyDisabled ? null : (note) => widget.onKeyPress(note),
                index: index,
                isDisabled: isKeyDisabled,
                isChordAdded: isChordAdded);
          },
        ),
      ),
    );
  }

  String _getPitch(int index, KeyboardRow row) {
    const pitches = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

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

    int pitchIndex = (startPitchIndex + index) % pitches.length;
    return pitches[pitchIndex];
  }

  int _getOctave(int index, KeyboardRow row) {
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

    const pitches = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
    int startPitchIndex;
    switch (row) {
      case KeyboardRow.top:
        startPitchIndex = 5; // Start with 'A' for top row

        if ((startPitchIndex + index) >= pitches.length) {
          return baseOctave + ((startPitchIndex + index) ~/ pitches.length);
        }
        break;
      case KeyboardRow.middle:
        startPitchIndex = 3; // Start with 'F' for middle row

        if ((startPitchIndex + index) >= pitches.length) {
          return baseOctave + ((startPitchIndex + index) ~/ pitches.length);
        }
        break;
      case KeyboardRow.bottom:
        startPitchIndex = 1; // Start with 'D' for bottom row

        if ((startPitchIndex + index) >= pitches.length) {
          return baseOctave + ((startPitchIndex + index) ~/ pitches.length);
        }
        break;
    }

    return baseOctave;
  }

  bool _isKeyDisabled(String pitch, int octave, KeyboardRow row) {
    if (widget.sheetFormat != SheetFormat.twoRows) {
      return false;
    }

    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    if (widget.sheetNoteRows.isEmpty) {
      return false;
    }

    final selectedRow = selectedNoteProvider.selectedRow;
    final rowsPerGroup = widget.sheetFormat.rowsPerGroup;
    final groupStartRow = (selectedRow ~/ rowsPerGroup) * rowsPerGroup;

    final isCursorOnTrebleRow = (selectedRow - groupStartRow) == 0;

    const double lineSpacing = 10.0; // Approximate line spacing
    const double staffTop = 20.0; // Approximate staff top
    const double rowHeight = (4 * lineSpacing);
    const double staffBottom = staffTop + rowHeight;

    final double noteY =
        calculateNoteYVerticalKeyboard(pitch, octave, lineSpacing, staffTop);

    if (isCursorOnTrebleRow) {
      final double firstLedgerLineBelowStaff = staffBottom + rowHeight;
      return noteY > firstLedgerLineBelowStaff;
    }

    if (!isCursorOnTrebleRow) {
      final double firstLedgerLineAboveStaff = staffTop - rowHeight;
      return noteY < firstLedgerLineAboveStaff;
    }

    return false;
  }
}
