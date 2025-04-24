import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/providers/list_of_spacing_for_each_row.dart';
import 'package:music_keyboard/src/providers/selected_accidental_provider.dart';
import 'package:music_keyboard/src/widgets/keyboard/bars_keyboard_layout.dart';
import 'package:music_keyboard/src/widgets/keyboard/clefs_keyboard_layout.dart';
import 'package:music_keyboard/src/widgets/keyboard/notes_keyboard_layout.dart';
import 'package:music_keyboard/src/widgets/main_sheet/music_sheet_container.dart';
import 'package:music_keyboard/src/utils/screenshot_saver.dart';
import 'package:music_keyboard/src/utils/toast_utils.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';

class KeyboardScreen extends StatelessWidget {
  const KeyboardScreen({super.key});

  static const routeName = '/';

  @override
  Widget build(BuildContext context) {
    return const NoteInputScreen();
  }
}

class NoteInputScreen extends StatefulWidget {
  const NoteInputScreen({super.key});

  @override
  _NoteInputScreenState createState() => _NoteInputScreenState();
}

class _NoteInputScreenState extends State<NoteInputScreen> {
  final ScreenshotController screenshotController = ScreenshotController();
  List<List<MusicalNote>> sheetNoteRows = [[]];
  int maxNotesPerRow = 23;
  int defaultNoteSpacing = 26;

  bool showClefs = true;
  bool showBars = false;
  bool showTimeSignatures = false;
  bool showNotes = false;

  bool showNotesKeyboard = false;
  bool showSymbolsKeyboard = false;
  bool isTieing = false;

  String keyType = "clefs";

  void handleKeyPress(MusicalNote note) {
    try {
      final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
      final rowSpacingProvider = context.read<ListOfSpacingForEachRow>();
      final accidentalProvider = context.read<SelectedAccidentalProvider>();
      var rowSpacingList = rowSpacingProvider.rowSpacingList;

      // Get the selected accidental
      final selectedAccidental = accidentalProvider.selectedAccidental;

      // Create a new note with the selected accidental
      final noteWithAccidental = MusicalNote(
        pitch: note.pitch,
        octave: note.octave,
        type: note.type,
        isConnected: note.isConnected,
        unicodeCharacter: note.unicodeCharacter,
        accidentalCharacter: selectedAccidental,
        noteY: note.noteY,
      );

      setState(() {
        // Use the addNote method from CurrentSelectedNoteProvider to handle automatic bar line placement
        selectedNoteProvider.addNote(noteWithAccidental, sheetNoteRows);
        //NEXT WORK OUT WHAT IS WRONG HERE, AT END OF ROW CURSOR IS NOT BEING MOVED TO NEXT ROW.
        if (sheetNoteRows[selectedNoteProvider.selectedRow].length - 1 >=
            maxNotesPerRow) {
          var isNoteEndOfRow = false;
          if (selectedNoteProvider.insertionIndex >= maxNotesPerRow) {
            isNoteEndOfRow = true;
          }

          if (sheetNoteRows.length - 1 > selectedNoteProvider.selectedRow) {
            if (sheetNoteRows[selectedNoteProvider.selectedRow + 1].length -
                    1 >=
                maxNotesPerRow) {
              sheetNoteRows.insert(selectedNoteProvider.selectedRow + 1, []);

              rowSpacingList.insert(rowSpacingList.length, defaultNoteSpacing);
              rowSpacingProvider.updateRowSpacingList(rowSpacingList);
            }
          } else {
            sheetNoteRows.insert(selectedNoteProvider.selectedRow + 1, []);

            rowSpacingList.insert(rowSpacingList.length, defaultNoteSpacing);
            rowSpacingProvider.updateRowSpacingList(rowSpacingList);
          }

          var overflowCount = 0;

          for (int index = 0;
              index < sheetNoteRows[selectedNoteProvider.selectedRow].length;
              index++) {
            if (index > maxNotesPerRow) {
              var note = sheetNoteRows[selectedNoteProvider.selectedRow][index];
              sheetNoteRows[selectedNoteProvider.selectedRow + 1]
                  .insert(0, note);

              sheetNoteRows[selectedNoteProvider.selectedRow].remove(
                  sheetNoteRows[selectedNoteProvider.selectedRow][index]);

              overflowCount++;
            }
          }

          var selectedRow = isNoteEndOfRow
              ? selectedNoteProvider.selectedRow + 1
              : selectedNoteProvider.selectedRow;
          var selectedIndex = isNoteEndOfRow
              ? overflowCount
              : selectedNoteProvider.insertionIndex;

          selectedNoteProvider.updateInsertionPoint(selectedRow, selectedIndex);
        }

        updateRowSpacing(selectedNoteProvider.selectedRow);
      });
    } catch (e) {
      print("Error adding note: $e");
    }
  }

  void updateRowSpacing(int rowIndex) {
    final rowSpacingProvider = context.read<ListOfSpacingForEachRow>();
    var rowSpacingList = rowSpacingProvider.rowSpacingList;

    //here work out how many clefs/time signatures and affect the spacing in some way based on this?

    if (sheetNoteRows[rowIndex].length < 12) {
      rowSpacingList[rowIndex] = 82;
    } else if (sheetNoteRows[rowIndex].length < 13) {
      rowSpacingList[rowIndex] = 74;
    } else if (sheetNoteRows[rowIndex].length < 14) {
      rowSpacingList[rowIndex] = 67;
    } else if (sheetNoteRows[rowIndex].length < 15) {
      rowSpacingList[rowIndex] = 61;
    } else if (sheetNoteRows[rowIndex].length < 16) {
      rowSpacingList[rowIndex] = 54;
    } else if (sheetNoteRows[rowIndex].length < 17) {
      rowSpacingList[rowIndex] = 53;
    } else if (sheetNoteRows[rowIndex].length < 18) {
      rowSpacingList[rowIndex] = 48;
    } else if (sheetNoteRows[rowIndex].length < 19) {
      rowSpacingList[rowIndex] = 44;
    } else if (sheetNoteRows[rowIndex].length < 20) {
      rowSpacingList[rowIndex] = 42;
    } else if (sheetNoteRows[rowIndex].length < 21) {
      rowSpacingList[rowIndex] = 40;
    } else if (sheetNoteRows[rowIndex].length < 22) {
      rowSpacingList[rowIndex] = 38;
    } else if (sheetNoteRows[rowIndex].length < 23) {
      rowSpacingList[rowIndex] = 36;
    } else if (sheetNoteRows[rowIndex].length < 24) {
      rowSpacingList[rowIndex] = 34;
    } else if (sheetNoteRows[rowIndex].length < 25) {
      rowSpacingList[rowIndex] = 33;
    } else if (sheetNoteRows[rowIndex].length < 26) {
      rowSpacingList[rowIndex] = 32;
    } else if (sheetNoteRows[rowIndex].length < 27) {
      rowSpacingList[rowIndex] = 31;
    } //else if (sheetNoteRows[rowIndex].length < 30) {
    //rowSpacingList[rowIndex] = 26;
    //}

    rowSpacingProvider.updateRowSpacingList(rowSpacingList);
  }

  void forceNewRow() {
    setState(() {
      if (sheetNoteRows.isNotEmpty) {
        final selectedNoteProvider =
            context.read<CurrentSelectedNoteProvider>();
        final rowSpacingProvider = context.read<ListOfSpacingForEachRow>();
        var rowSpacingList = rowSpacingProvider.rowSpacingList;

        sheetNoteRows.insert(selectedNoteProvider.selectedRow + 1, []);
        rowSpacingList.insert(rowSpacingList.length, defaultNoteSpacing);
        rowSpacingProvider.updateRowSpacingList(rowSpacingList);
      }
    });
  }

  // Remove the last note from the list
  void handleBackspacePress() {
    setState(() {
      final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

      if (selectedNoteProvider.selectedRow == 0 &&
          selectedNoteProvider.insertionIndex == 0) {
        return;
      }

      final rowSpacingProvider = context.read<ListOfSpacingForEachRow>();
      var rowSpacingList = rowSpacingProvider.rowSpacingList;

      if (sheetNoteRows[selectedNoteProvider.selectedRow].isEmpty) {
        sheetNoteRows.remove(sheetNoteRows[selectedNoteProvider.selectedRow]);

        rowSpacingList.remove(rowSpacingList[selectedNoteProvider.selectedRow]);
        rowSpacingProvider.updateRowSpacingList(rowSpacingList);

        selectedNoteProvider.updateInsertionPoint(
            selectedNoteProvider.selectedRow - 1,
            sheetNoteRows[selectedNoteProvider.selectedRow - 1].isEmpty
                ? 0
                : sheetNoteRows[selectedNoteProvider.selectedRow - 1].length);
      } else if (sheetNoteRows[selectedNoteProvider.selectedRow].isNotEmpty &&
          selectedNoteProvider.insertionIndex > 0) {
        // Get the note that will be removed
        MusicalNote noteToRemove =
            sheetNoteRows[selectedNoteProvider.selectedRow]
                [selectedNoteProvider.insertionIndex - 1];

        // Update cursor position before removing the note
        selectedNoteProvider.updateInsertionPoint(
            selectedNoteProvider.selectedRow,
            selectedNoteProvider.insertionIndex - 1);

        // Handle slur indices
        for (var note in sheetNoteRows[selectedNoteProvider.selectedRow]) {
          if (note.slurEndIndex == selectedNoteProvider.insertionIndex) {
            note.slurEndIndex = null;
          }
        }

        // Save state for undo before removing the note
        selectedNoteProvider.saveState(sheetNoteRows);

        // Remove the note
        sheetNoteRows[selectedNoteProvider.selectedRow].remove(noteToRemove);
      }

      updateRowSpacing(selectedNoteProvider.selectedRow);
    });
  }

  // Save the current screenshot to the gallery and show a toast
  Future<void> handleSavePress() async {
    final image = await screenshotController.capture();
    if (image != null) {
      await saveImageToGallery(image);
      ToastUtils.showToast("Saved to Camera Roll!");
    } else {
      ToastUtils.showToast("Screenshot capture failed!", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = MediaQuery.of(context).size;
    final statusBarHeight = mediaQuery.padding.top;
    const double noteWidth = 27.0;
    const int maxNotes = 30;
    const double musicSheetWidth = noteWidth * maxNotes;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: handleSavePress,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: forceNewRow,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.0), // Border thickness
          child: Container(
            color: Colors.orange, // Border color
            height: 2.0, // Border height
          ),
        ),
      ),
      body: Stack(
        children: [
          // Music Sheet taking full available height above the keyboard
          Positioned.fill(
            child: Column(
              children: [
                MusicSheetContainer(
                    screenSize: screenSize,
                    screenshotController: screenshotController,
                    sheetNoteRows: sheetNoteRows,
                    musicSheetWidth: musicSheetWidth,
                    statusBarHeight: statusBarHeight),
                const Spacer(), // Pushes the keyboard container to the bottom
              ],
            ),
          ),

          // Keyboard Section Pinned to Bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ColoredBox(
              color: const Color(0xFFF7ECE1),
              child: Container(
                height: 400, // Fixed height for the keyboard area
                /*decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.orange, // Set the border color
                      width: 2.0, // Set the border width
                    ),
                  ),
                ),*/
                padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                child: Column(
                  children: [
                    // Toggle Buttons for Keyboard Selection and Backspace
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 5),
                              child: ToggleButtons(
                                textStyle: const TextStyle(
                                  fontSize: 11,
                                ),
                                isSelected: [
                                  showClefs,
                                  showBars,
                                  showTimeSignatures,
                                  showNotes,
                                ],
                                onPressed: (int index) {
                                  setState(() {
                                    // Reset all selections first
                                    showClefs = index == 0;
                                    showBars = index == 1;
                                    showTimeSignatures = index == 2;
                                    showNotes = index == 3;
                                    if (index == 0) keyType = "clefs";
                                    if (index == 1) keyType = "bars";
                                    if (index == 2) keyType = "rests";
                                    if (index == 3) keyType = "notes";
                                  });
                                },
                                borderRadius: BorderRadius.circular(8.0),
                                selectedColor: Colors.white,
                                fillColor: Colors.orange,
                                color: Colors.black,
                                constraints: const BoxConstraints(
                                  minHeight: 28.0,
                                  minWidth: 70.0,
                                ),
                                children: const [
                                  Text("Clefs"),
                                  Text("Bars"),
                                  Text("Rests"),
                                  Text("Notes"),
                                ],
                              ))
                        ]),
                        Row(
                          children: [
                            IconButton(
                              onPressed: handleBackspacePress,
                              icon: const Icon(Icons.backspace,
                                  color: Color(0xFF242038)),
                              iconSize: 25.0,
                            ),
                            const Padding(
                                padding: EdgeInsets.fromLTRB(0, 0, 5, 0))
                          ],
                        ),
                      ],
                    ),
                    Stack(
                      children: [
                        keyType == "clefs"
                            ? ClefsKeyboardLayout(onKeyPress: handleKeyPress)
                            : keyType == "bars"
                                ? BarsKeyboardLayout(onKeyPress: handleKeyPress)
                                : NotesKeyboardLayout(
                                    showNotesKeyboard: showNotesKeyboard,
                                    onToggleKeyboard: (isNotes) {
                                      setState(() {
                                        showNotesKeyboard = isNotes;
                                      });
                                    },
                                    onKeyPress: handleKeyPress,
                                    keyType: keyType,
                                  ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
