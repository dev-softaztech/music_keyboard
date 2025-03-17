import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
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
  //List<MusicalNote> notes = [];
  List<List<MusicalNote>> sheetNoteRows = [[]]; // Each sublist represents a row
  int maxNotesPerRow = 29;

  bool showClefs = true;
  bool showTimeSignatures = false;
  bool showAccidentals = false;
  bool showNotes = false;

  // State to control which keyboard to display
  bool showNotesKeyboard = false; // Track if Notes is selected
  bool showSymbolsKeyboard = false; // Track if Symbols2 is selected
  //bool isBeaming = false;
  bool isTieing = false;

  String keyType = "clefs";

  void handleKeyPress(MusicalNote note) {
    try {
      final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

      setState(() {
        sheetNoteRows[selectedNoteProvider.selectedRow]
            .insert(selectedNoteProvider.selectedIndex, note);

        if (sheetNoteRows[selectedNoteProvider.selectedRow].length - 1 >=
            maxNotesPerRow) {
          var isNoteEndOfRow = false;
          if (selectedNoteProvider.selectedIndex == maxNotesPerRow) {
            isNoteEndOfRow = true;
          }
          //line is being added for every overflowed note, what can be done about this?
          // do I just make it always go onto next line and only overflowif no next line
          var overflowCount = 0;

          if (sheetNoteRows[selectedNoteProvider.selectedRow].length >
                  selectedNoteProvider.selectedRow &&
              sheetNoteRows[selectedNoteProvider.selectedRow + 1].length - 1 >=
                  maxNotesPerRow) {
            sheetNoteRows.insert(selectedNoteProvider.selectedRow + 1, []);
          }

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
              : selectedNoteProvider.selectedIndex;

          selectedNoteProvider.updateInsertionPoint(selectedRow, selectedIndex);
        } else {
          // Move cursor forward
          selectedNoteProvider.updateInsertionPoint(
              selectedNoteProvider.selectedRow,
              selectedNoteProvider.selectedIndex + 1);
        }
      });
    } catch (e) {
      print("Error adding note: $e");
    }
  }

  void forceNewRow() {
    setState(() {
      if (sheetNoteRows.isNotEmpty) {
        final selectedNoteProvider =
            context.read<CurrentSelectedNoteProvider>();

        sheetNoteRows.insert(selectedNoteProvider.selectedRow + 1, []);
      }
    });
  }

  // Remove the last note from the list
  void handleBackspacePress() {
    setState(() {
      final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

      if (sheetNoteRows[selectedNoteProvider.selectedRow].isEmpty) {
        sheetNoteRows.remove(sheetNoteRows[selectedNoteProvider.selectedRow]);

        selectedNoteProvider.updateInsertionPoint(
            selectedNoteProvider.selectedRow - 1,
            sheetNoteRows[selectedNoteProvider.selectedRow - 1].isEmpty
                ? 0
                : sheetNoteRows[selectedNoteProvider.selectedRow - 1].length);
      }

      if (sheetNoteRows[selectedNoteProvider.selectedRow].isNotEmpty) {
        if (selectedNoteProvider.selectedRow == 0 &&
            selectedNoteProvider.selectedIndex == 0) {
          return;
        }

        selectedNoteProvider.updateInsertionPoint(
            selectedNoteProvider.selectedRow,
            sheetNoteRows[selectedNoteProvider.selectedRow].indexOf(
                sheetNoteRows[selectedNoteProvider.selectedRow]
                    [selectedNoteProvider.selectedIndex - 1]));

        sheetNoteRows[selectedNoteProvider.selectedRow].remove(
            sheetNoteRows[selectedNoteProvider.selectedRow]
                [selectedNoteProvider.selectedIndex]);
      }
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
    final screenSize = MediaQuery.of(context).size;
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
          ElevatedButton(
            onPressed: () {
              context.read<CurrentSelectedNoteProvider>().enableTying();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.zero,
            ),
            child: const Text("Tie Notes"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                //isBeaming = !isBeaming;
                context.read<CurrentSelectedNoteProvider>().enableBeaming();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.zero,
            ),
            child: const Text("Beam Notes"),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<CurrentSelectedNoteProvider>().undo(sheetNoteRows);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.zero,
            ),
            child: const Text("Undo"),
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
      body: ColoredBox(
        color: const Color(0xFFF7ECE1),
        child: Stack(
          children: [
            // Music Sheet taking full available height above the keyboard
            Positioned.fill(
              child: Column(
                children: [
                  MusicSheetContainer(
                      screenSize: screenSize,
                      screenshotController: screenshotController,
                      sheetNoteRows: sheetNoteRows,
                      musicSheetWidth: musicSheetWidth),
                  const Spacer(), // Pushes the keyboard container to the bottom
                ],
              ),
            ),

            // Keyboard Section Pinned to Bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 370, // Fixed height for the keyboard area
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.orange, // Set the border color
                      width: 2.0, // Set the border width
                    ),
                  ),
                ),
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
                                  showTimeSignatures,
                                  showAccidentals,
                                  showNotes,
                                ],
                                onPressed: (int index) {
                                  setState(() {
                                    // Reset all selections first
                                    showClefs = index == 0;
                                    showTimeSignatures = index == 1;
                                    showAccidentals = index == 2;
                                    showNotes = index == 3;
                                    if (index == 0) keyType = "clefs";
                                    if (index == 1) keyType = "rests";
                                    if (index == 2) keyType = "accidentals";
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
                                  Text("Rests"),
                                  Text("Accidentals"),
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
          ],
        ),
      ),
    );
  }
}
