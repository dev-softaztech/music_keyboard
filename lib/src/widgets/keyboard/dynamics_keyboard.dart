import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:provider/provider.dart';

class DynamicsKeyboard extends StatelessWidget {
  final VoidCallback onToggleKeyboard;
  final List<SheetRows> sheetNoteRows;

  const DynamicsKeyboard(
      {super.key, required this.onToggleKeyboard, required this.sheetNoteRows});

  @override
  Widget build(BuildContext context) {
    final currentSelectedNoteProvider =
        Provider.of<CurrentSelectedNoteProvider>(context);
    final selectedIndex = currentSelectedNoteProvider.selectedIndex;
    final selectedRow = currentSelectedNoteProvider.selectedRow;
    final selectedNote = sheetNoteRows[selectedRow].notes.length > selectedIndex
        ? sheetNoteRows[selectedRow].notes[selectedIndex]
        : null;

    final List<String> cresendoCharacters = [
      '\uE53F',
      '\uE53E',
    ];

    final List<String> dynamicCharacters = [
      '\uE530',
      '\uE52F',
      '\uE522',
      '\uE52D',
      '\uE52C',
      '\uE520',
      '\uE52B',
      '\uE52A',
      '\uE539',
    ];

    return SizedBox(
      height: 290,
      child: Row(
        children: [
          Column(
            children: [
              const SizedBox(
                height: 243,
                //width: 40,
              ),
              Container(
                margin: EdgeInsets.fromLTRB(8, 0, 0, 0),
                padding: EdgeInsets.fromLTRB(8, 0, 0, 0),
                child: SizedBox(
                  width: 30,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: onToggleKeyboard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.black, width: 1),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Transform.translate(
                      offset: Offset(0, 10),
                      child: Text(
                        '\ue1d5',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 27,
                          fontFamily: 'Bravura',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  color: Colors.white,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8.0,
                    children: cresendoCharacters.map((character) {
                      bool isSelected = false;

                      if (selectedNote != null) {
                        if (character == '\uE53F') {
                          isSelected = selectedNote.isDecrescendoStart;
                        } else if (character == '\uE53E') {
                          isSelected = selectedNote.isCrescendoStart;
                        }
                      }

                      return GestureDetector(
                        onTap: () {
                          if (selectedNote != null) {
                            final currentNoteIndex = selectedIndex;
                            if (character == '\uE53F') {
                              selectedNote.isDecrescendoStart =
                                  !selectedNote.isDecrescendoStart;
                              selectedNote.decrescendoEndIndex =
                                  selectedNote.isDecrescendoStart
                                      ? currentNoteIndex
                                      : null;
                            } else if (character == '\uE53E') {
                              selectedNote.isCrescendoStart =
                                  !selectedNote.isCrescendoStart;
                              selectedNote.crescendoEndIndex =
                                  selectedNote.isCrescendoStart
                                      ? currentNoteIndex
                                      : null;
                            } else {
                              selectedNote.dynamicCharacter = character;
                            }
                            currentSelectedNoteProvider.notifyListeners();
                          }
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: isSelected ? Colors.red : Colors.black,
                                width: 1),
                          ),
                          child: Center(
                            child: Transform.translate(
                                offset: const Offset(0, 5),
                                child: Text(
                                  character,
                                  style: const TextStyle(
                                    fontFamily: 'Bravura',
                                    fontSize: 35,
                                  ),
                                )),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(
                  height: 10,
                ),
                Container(
                  color: Colors.white,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8.0,
                    children: dynamicCharacters.map((character) {
                      bool isSelected = false;

                      if (selectedNote != null) {
                        isSelected = selectedNote.dynamicCharacter == character;
                      }

                      return GestureDetector(
                        onTap: () {
                          if (selectedNote != null) {
                            if (selectedNote.dynamicCharacter == character) {
                              selectedNote.dynamicCharacter = '';
                            } else {
                              selectedNote.dynamicCharacter = character;
                            }
                            currentSelectedNoteProvider.notifyListeners();
                          }
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.red : Colors.black,
                            ),
                          ),
                          child: Center(
                              child: Transform.translate(
                            offset: const Offset(1, 3),
                            child: Text(
                              character,
                              style: const TextStyle(
                                fontFamily: 'Bravura',
                                fontSize: 28,
                              ),
                            ),
                          )),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 40,
          )
        ],
      ),
    );
  }
}
