import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/providers/is_connected_provider.dart';
import 'package:music_keyboard/src/widgets/keyboard/letters_keyboard/keyboard_by_notes.dart';
import 'package:music_keyboard/src/widgets/keyboard/note_head_keyboard/keyboard_by_symbols.dart';
import 'package:music_keyboard/src/providers/selected_unicode_provider.dart';
import 'package:provider/provider.dart';

class NotesKeyboardLayout extends StatelessWidget {
  final bool showNotesKeyboard;
  final void Function(bool) onToggleKeyboard;
  final void Function(MusicalNote) onKeyPress;
  final String keyType;

  const NotesKeyboardLayout(
      {super.key,
      required this.showNotesKeyboard,
      required this.onToggleKeyboard,
      required this.onKeyPress,
      required this.keyType});

  @override
  Widget build(BuildContext context) {
    List<String> unicodeCharacters = [];

    if (keyType == "meters") {
      unicodeCharacters = [
        '\uf5f9',
        '\uf5fa',
        '\uf5fb',
        '\uf5fc',
        '\uf5fd',
        '\uf5fe',
        '\uf5ff',
        '\uf600',
        '\uf601',
        '\uf602',
        '\uf603',
        '\uf604',
        '\uf605',
        '\uf510',
        '\uf511',
      ];
    } else if (keyType == "rests") {
      unicodeCharacters = [
        '\ue1b3',
        '\ue4e3',
        '\ue4e4',
        '\ue4e5',
        '\ue4e6',
        '\ue4e7',
        '\ue4e8',
        '\ue4e9',
        //'\ue4ea',
        //'\ue4eb',
        //'\ue4ec',
        //'\ue4ed',
      ];
    } else if (keyType == "accidentals") {
      unicodeCharacters = [
        '\ue260',
        '\ue261',
        '\ue262',
        '\ue263',
        '\ue264',
        '\ue265',
        '\ue266',
        '\ue267',
        '\ue268',
        '\ue269',
      ];
    } else if (keyType == "notes") {
      unicodeCharacters = [
        '\ue1d2',
        '\ue1d3',
        '\ue1d5',
        '\ue1d7',
        '\ue1d9',
        '\ue1db',
        '\ue1dd',
      ];
    }

    /*WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<SelectedUnicodeProvider>()
          .updateSelectedCharacter(unicodeCharacters[0]);
    });*/

    return Container(
      height: 280, // Fixed height for the keyboard area
      padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
      child: Column(
        children: [
          // Unicode Character Selection (Horizontal Scroll)
          Consumer<SelectedUnicodeProvider>(
            builder: (context, provider, _) => Container(
              height: 50,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: unicodeCharacters.length,
                itemBuilder: (context, index) {
                  final character = unicodeCharacters[index];
                  final isSelected = provider.selectedCharacter == character;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0),
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: ElevatedButton(
                        onPressed: () {
                          provider.updateSelectedCharacter(character);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? Colors.orange[700]
                              : Colors.orange[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Transform.translate(
                          offset: keyType == "notes"
                              ? const Offset(0, 16)
                              : keyType == "accidentals"
                                  ? const Offset(0, 4)
                                  : const Offset(0, 0),
                          child: Text(
                            character,
                            style: const TextStyle(
                              fontFamily: 'Bravura',
                              fontSize: 30,
                              color: Color(0xFF242038),
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Connect Notes Toggle & Keyboard Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Padding(padding: EdgeInsets.fromLTRB(5, 0, 0, 0)),
                  const Text("Beam Notes", style: TextStyle(fontSize: 10)),
                  Consumer<IsConnectedProvider>(
                    builder: (context, provider, _) => Transform.scale(
                      scale: 0.7,
                      child: Switch(
                        inactiveThumbColor: const Color(0xFF242038),
                        inactiveTrackColor: Colors.white,
                        activeColor: const Color(0xFF242038),
                        activeTrackColor: Colors.orange,
                        value: provider.isConnected,
                        onChanged: (value) {
                          provider.toggleConnection(value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                child: ToggleButtons(
                  textStyle: const TextStyle(fontSize: 10),
                  isSelected: [!showNotesKeyboard, showNotesKeyboard],
                  onPressed: (int index) {
                    onToggleKeyboard(index == 1);
                  },
                  borderRadius: BorderRadius.circular(8.0),
                  selectedColor: Colors.white,
                  fillColor: Colors.orange,
                  color: Colors.black,
                  constraints: const BoxConstraints(
                    minHeight: 23.0,
                    minWidth: 60.0,
                  ),
                  children: const [
                    Text("Note heads"),
                    Text("Letters"),
                  ],
                ),
              ),
            ],
          ),

          // Show the appropriate keyboard based on the toggle
          if (showNotesKeyboard)
            KeyboardByNotes(onKeyPress: onKeyPress, keyType: keyType)
          else
            KeyboardBySymbols(onKeyPress: onKeyPress, keyType: keyType),
        ],
      ),
    );
  }
}
