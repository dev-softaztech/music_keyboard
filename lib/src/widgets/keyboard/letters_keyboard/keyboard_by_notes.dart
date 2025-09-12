import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/providers/is_connected_provider.dart';
import 'package:music_keyboard/src/providers/selected_unicode_provider.dart';
import 'package:music_keyboard/src/utils/keyboard_utils/unicode_mapper.dart';
import 'package:provider/provider.dart';
import 'package:music_keyboard/src/providers/selected_number_provider.dart';
import 'number_selector_radio_buttons.dart';

class KeyboardByNotes extends StatelessWidget {
  final void Function(MusicalNote note) onKeyPress;
  final String keyType;

  const KeyboardByNotes(
      {super.key, required this.onKeyPress, required this.keyType});

  @override
  Widget build(BuildContext context) {
    final List<String> keysFirstRow = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
    final selectedNumberProvider = Provider.of<SelectedNumberProvider>(context);
    final isConnected = context.watch<IsConnectedProvider>().isConnected;
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

    return Column(
      children: [
        NumberSelectorRadioButtons(),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: keysFirstRow.map((key) {
            return SizedBox(
              width: 35, // Set fixed width
              height: 50, // Set fixed height
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.zero, // Remove default padding
                ),
                onPressed: () {
                  final note = MusicalNote(
                      pitch: key,
                      octave: selectedNumberProvider.selectedNumber,
                      type: noteType,
                      isBeamed: isConnected,
                      unicodeCharacter: selectedCharacter);

                  onKeyPress(note);
                },
                child: Text(
                  key,
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
