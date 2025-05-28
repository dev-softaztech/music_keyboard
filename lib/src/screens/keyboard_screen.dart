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
  int maxNotesPerRow = 19;
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
        // Add the note first
        selectedNoteProvider.addNote(noteWithAccidental, sheetNoteRows);

        // Check if we need to handle row overflow
        if (sheetNoteRows[selectedNoteProvider.selectedRow].length - 1 >=
            maxNotesPerRow) {
          // Check if there are any bar notes in the current row
          bool hasBarNotes = false;
          for (var note in sheetNoteRows[selectedNoteProvider.selectedRow]) {
            if (note.type == NoteType.bar) {
              hasBarNotes = true;
              break;
            }
          }

          if (!hasBarNotes) {
            // If there are no bar notes, just add a new empty row and move the cursor there
            // Create a new row
            sheetNoteRows.insert(selectedNoteProvider.selectedRow + 1, []);
            rowSpacingList.insert(
                selectedNoteProvider.selectedRow + 1, defaultNoteSpacing);
            rowSpacingProvider.updateRowSpacingList(rowSpacingList);

            // Update spacing for the current row
            updateRowSpacing(selectedNoteProvider.selectedRow);

            // Move the cursor to the beginning of the new row
            selectedNoteProvider.updateInsertionPoint(
                selectedNoteProvider.selectedRow + 1, 0);
          } else {
            // If there are bar notes, handle bar movement as before
            // Find the current bar boundaries
            int currentBarStartIndex = 0;
            int currentBarEndIndex =
                sheetNoteRows[selectedNoteProvider.selectedRow].length - 1;

            // Find the start of the current bar (either after the last bar line or at the beginning of the row)
            for (int i = selectedNoteProvider.insertionIndex - 1; i >= 0; i--) {
              if (sheetNoteRows[selectedNoteProvider.selectedRow][i].type ==
                  NoteType.bar) {
                currentBarStartIndex = i + 1;
                break;
              }
            }

            // Find the end of the current bar (either before the next bar line or at the end of the row)
            for (int i = selectedNoteProvider.insertionIndex;
                i < sheetNoteRows[selectedNoteProvider.selectedRow].length;
                i++) {
              if (sheetNoteRows[selectedNoteProvider.selectedRow][i].type ==
                  NoteType.bar) {
                currentBarEndIndex = i - 1;
                break;
              }
            }

            // Calculate the number of notes in the current bar
            int notesInCurrentBar =
                currentBarEndIndex - currentBarStartIndex + 1;

            // Ensure we have a next row to move to
            if (sheetNoteRows.length - 1 <= selectedNoteProvider.selectedRow) {
              // Create a new row if we're at the last row
              sheetNoteRows.insert(selectedNoteProvider.selectedRow + 1, []);
              rowSpacingList.insert(rowSpacingList.length, defaultNoteSpacing);
              rowSpacingProvider.updateRowSpacingList(rowSpacingList);
            } else if (sheetNoteRows[selectedNoteProvider.selectedRow + 1]
                        .length +
                    notesInCurrentBar >
                maxNotesPerRow) {
              // If the next row doesn't have enough space, create a new row
              sheetNoteRows.insert(selectedNoteProvider.selectedRow + 1, []);
              rowSpacingList.insert(rowSpacingList.length, defaultNoteSpacing);
              rowSpacingProvider.updateRowSpacingList(rowSpacingList);
            }

            // Save state for undo before moving the bar
            selectedNoteProvider.saveState(sheetNoteRows);

            // Move the entire bar to the next row
            List<MusicalNote> notesToMove = [];

            // Collect all notes in the current bar
            for (int i = currentBarStartIndex; i <= currentBarEndIndex; i++) {
              notesToMove
                  .add(sheetNoteRows[selectedNoteProvider.selectedRow][i]);
            }

            // Remove the notes from the current row (in reverse order to maintain indices)
            for (int i = currentBarEndIndex; i >= currentBarStartIndex; i--) {
              sheetNoteRows[selectedNoteProvider.selectedRow].removeAt(i);
            }

            // Insert the notes at the beginning of the next row
            for (int i = 0; i < notesToMove.length; i++) {
              sheetNoteRows[selectedNoteProvider.selectedRow + 1]
                  .insert(i, notesToMove[i]);
            }

            // Update spacing for both the current row and the next row
            updateRowSpacing(selectedNoteProvider.selectedRow);
            updateRowSpacing(selectedNoteProvider.selectedRow + 1);

            // Update the insertion point to the next row
            selectedNoteProvider.updateInsertionPoint(
                selectedNoteProvider.selectedRow + 1, notesToMove.length);
          }
        } else {
          // If no row overflow, just update the current row spacing
          updateRowSpacing(selectedNoteProvider.selectedRow);
        }
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
      rowSpacingList[rowIndex] = 74;
    } else if (sheetNoteRows[rowIndex].length < 13) {
      rowSpacingList[rowIndex] = 66;
    } else if (sheetNoteRows[rowIndex].length < 14) {
      rowSpacingList[rowIndex] = 60;
    } else if (sheetNoteRows[rowIndex].length < 15) {
      rowSpacingList[rowIndex] = 55;
    } else if (sheetNoteRows[rowIndex].length < 16) {
      rowSpacingList[rowIndex] = 51;
    } else if (sheetNoteRows[rowIndex].length < 17) {
      rowSpacingList[rowIndex] = 46;
    } else if (sheetNoteRows[rowIndex].length < 18) {
      rowSpacingList[rowIndex] = 43;
    } else if (sheetNoteRows[rowIndex].length < 19) {
      rowSpacingList[rowIndex] = 41;
    } else if (sheetNoteRows[rowIndex].length < 20) {
      rowSpacingList[rowIndex] = 38;
    } else if (sheetNoteRows[rowIndex].length < 21) {
      rowSpacingList[rowIndex] = 36;
    } else if (sheetNoteRows[rowIndex].length < 22) {
      rowSpacingList[rowIndex] = 35;
    } else if (sheetNoteRows[rowIndex].length < 23) {
      rowSpacingList[rowIndex] = 31;
    } else if (sheetNoteRows[rowIndex].length < 24) {
      rowSpacingList[rowIndex] = 29;
    } else if (sheetNoteRows[rowIndex].length < 25) {
      rowSpacingList[rowIndex] = 27;
    } else if (sheetNoteRows[rowIndex].length < 26) {
      rowSpacingList[rowIndex] = 26;
    } else if (sheetNoteRows[rowIndex].length < 27) {
      rowSpacingList[rowIndex] = 25;
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
            color: Colors.black, // Border color
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
              color: const Color.fromARGB(255, 255, 253, 253),
              child: Container(
                height: 440,
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
                                fillColor: Colors.black,
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
