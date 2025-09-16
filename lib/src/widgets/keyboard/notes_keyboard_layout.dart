import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/providers/selected_accidental_provider.dart';
import 'package:music_keyboard/src/widgets/keyboard/note_head_keyboard/keyboard_by_symbols.dart';
import 'package:music_keyboard/src/providers/selected_unicode_provider.dart';
import 'package:music_keyboard/src/widgets/keyboard/time_signature_popup.dart';
import 'package:provider/provider.dart';

class NotesKeyboardLayout extends StatefulWidget {
  final bool showNotesKeyboard;
  final void Function(bool) onToggleKeyboard;
  final void Function(MusicalNote) onKeyPress;
  final VoidCallback onToggleDynamicsKeyboard;
  final List<SheetRows> sheetNoteRows;

  const NotesKeyboardLayout({
    super.key,
    required this.showNotesKeyboard,
    required this.onToggleKeyboard,
    required this.onKeyPress,
    required this.onToggleDynamicsKeyboard,
    required this.sheetNoteRows,
  });

  @override
  State<NotesKeyboardLayout> createState() => _NotesKeyboardLayoutState();
}

class _NotesKeyboardLayoutState extends State<NotesKeyboardLayout> {
  String _selectedRestUnicode = '\ue4e5'; // Default rest unicode, whole note
  // Track which shift button is currently showing its popup
  String? _activeShiftButton;
  // Overlay entry for the popup
  OverlayEntry? _overlayEntry;
  // Global keys to get the positions of the shift buttons
  final Map<String, GlobalKey> _shiftButtonKeys = {
    'sharp': GlobalKey(),
    'flat': GlobalKey(),
    'natural': GlobalKey(),
  };

  int _sharpState = 0; // 0: off, 1: sharp, 2: double sharp
  int _flatState = 0; // 0: off, 1: flat, 2: double flat
  int _naturalState = 0; // 0: off, 1: natural
  int _dottedRestState = 0;

  // Octave pair state - false = Middle+Top pair, true = Bottom+Middle pair
  bool showLowerPair = false;

  void _toggleOctavePair() {
    setState(() {
      showLowerPair = !showLowerPair;
    });
  }

  @override
  void dispose() {
    // Make sure to remove any active overlay when disposing
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    super.dispose();
  }
/*
  @override
  void didUpdateWidget(NotesKeyboardLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the keyType changes (tab switch), remove any active overlay
    if (oldWidget.keyType != widget.keyType) {
      if (_overlayEntry != null) {
        _overlayEntry!.remove();
        _overlayEntry = null;
        _activeShiftButton = null;
      }
    }
  }*/

  // Show the popup for a specific shift button
  void _showPopup(String buttonType, BuildContext context) {
    // Remove any existing overlay first
    _removeOverlay();

    // Set the active shift button
    setState(() {
      _activeShiftButton = buttonType;
    });

    // Get the screen size
    final Size screenSize = MediaQuery.of(context).size;

    // Calculate the number of items to determine the popup height
    List<String> unicodeOptions = _getUnicodeOptions(buttonType);
    int itemCount = unicodeOptions.length;

    // Calculate the popup size based on content
    // Fixed width for consistency, but height depends on number of items
    double popupWidth = 200.0;
    double buttonSize = 80.0; // Fixed size for each button
    int crossAxisCount = 3; // Always 2 columns
    int rowCount = (itemCount / crossAxisCount).ceil();
    double popupHeight = (buttonSize * rowCount) + 32.0; // Add padding

    // Create the overlay entry
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Invisible full-screen button to detect taps outside
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // The actual popup - centered on screen
          Positioned(
            left: 50,
            bottom: 85,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white),
                ),
                width: popupWidth,
                height: popupHeight,
                child: _buildPopupContent(buttonType, context),
              ),
            ),
          ),
        ],
      ),
    );

    // Add the overlay to the overlay
    Overlay.of(context).insert(_overlayEntry!);
  }

  // Remove the overlay
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _activeShiftButton = null;
    });
  }

  // Get unicode options based on button type
  List<String> _getUnicodeOptions(String buttonType) {
    if (buttonType == 'rest') {
      return [
        '\ue4e5', // Whole rest
        '\ue4e6', // Half rest
        '\ue4e4', // Quarter rest
        '\ue4e7', // 8th rest
        '\ue4e8', // 16th rest
        '\ue4e9', // 32nd rest
        '\ue1b3', // 64th rest
      ]; // Rest variants
    }
    return [];
  }

  // Build the content of the popup based on the button type
  Widget _buildPopupContent(String buttonType, BuildContext context) {
    List<String> unicodeOptions = _getUnicodeOptions(buttonType);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(), // Disable scrolling
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.9, // Slightly wider than tall
      ),
      itemCount: unicodeOptions.length,
      itemBuilder: (context, index) {
        final unicode = unicodeOptions[index];
        return InkWell(
          onTap: () {
            if (buttonType == 'rest') {
              setState(() {
                _selectedRestUnicode = unicode;
              });
              widget.onKeyPress(MusicalNote(
                pitch: "D",
                octave: 5,
                type: NoteType.rest,
                isBeamed: false,
                unicodeCharacter: unicode,
              ));
            } else {
              // Update the selected accidental in the provider
              context
                  .read<SelectedAccidentalProvider>()
                  .updateSelectedAccidental(unicode);
            }
            // Remove the overlay
            _removeOverlay();
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                unicode,
                style: const TextStyle(
                  fontFamily: 'Bravura',
                  fontSize: 40, // Even smaller
                  color: Color(0xFF242038),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShiftButton(
      String buttonType, String label, BuildContext context) {
    final isActive = _activeShiftButton == buttonType;

    return SizedBox(
      width: 30,
      height: 40,
      child: GestureDetector(
        onLongPress: () {
          _showPopup(buttonType, context);
        },
        child: ElevatedButton(
          key: _shiftButtonKeys[buttonType],
          onPressed: () {
            if (isActive) {
              _removeOverlay();
            } else if (buttonType == 'rest') {
              widget.onKeyPress(MusicalNote(
                pitch: "D",
                octave: 5,
                type: NoteType.rest,
                isBeamed: false,
                unicodeCharacter: _selectedRestUnicode,
              ));
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? Colors.grey[500] : Colors.grey[100],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.black, width: 1),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Text(
            _selectedRestUnicode,
            style: const TextStyle(
              fontFamily: 'Bravura',
              fontSize: 30,
              color: Color(0xFF242038),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSharpButton(BuildContext context) {
    String displayUnicode;
    switch (_sharpState) {
      case 1:
        displayUnicode = '\uF4DE'; // Sharp
        break;
      case 2:
        displayUnicode = '\uF4DF'; // Double Sharp
        break;
      default:
        displayUnicode = '\uF4DE'; // Default to sharp
    }

    return SizedBox(
      width: 30,
      height: 40,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _sharpState = (_sharpState + 1) % 3;
            _flatState = 0;
            _naturalState = 0;
            _dottedRestState = 0;
            String accidental = '';
            if (_sharpState == 1) {
              accidental = '\uF4DE';
            } else if (_sharpState == 2) {
              accidental = '\uF4DF';
            }
            context
                .read<SelectedAccidentalProvider>()
                .updateSelectedAccidental(accidental);
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _sharpState != 0 ? Colors.grey[300] : Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.black, width: 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Transform.translate(
          offset: const Offset(0, 10),
          child: Text(
            displayUnicode,
            style: const TextStyle(
              fontFamily: 'Bravura',
              fontSize: 28,
              color: Color(0xFF242038),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlatButton(BuildContext context) {
    String displayUnicode;
    switch (_flatState) {
      case 1:
        displayUnicode = '\uF4DC'; // Flat
        break;
      case 2:
        displayUnicode = '\uF4E0'; // Double Flat
        break;
      default:
        displayUnicode = '\uF4DC'; // Default to flat
    }

    return SizedBox(
      width: 30,
      height: 40,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _flatState = (_flatState + 1) % 3;
            _sharpState = 0;
            _naturalState = 0;
            _dottedRestState = 0;
            String accidental = '';
            if (_flatState == 1) {
              accidental = '\uF4DC';
            } else if (_flatState == 2) {
              accidental = '\uF4E0';
            }
            context
                .read<SelectedAccidentalProvider>()
                .updateSelectedAccidental(accidental);
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _flatState != 0 ? Colors.grey[300] : Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.black, width: 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Transform.translate(
          offset: const Offset(0, 10),
          child: Text(
            displayUnicode,
            style: const TextStyle(
              fontFamily: 'Bravura',
              fontSize: 28,
              color: Color(0xFF242038),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNaturalButton(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 40,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _naturalState = (_naturalState + 1) % 2;
            _sharpState = 0;
            _flatState = 0;
            _dottedRestState = 0;
            String accidental = '';
            if (_naturalState == 1) {
              accidental = '\uF4DD';
            }
            context
                .read<SelectedAccidentalProvider>()
                .updateSelectedAccidental(accidental);
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _naturalState != 0 ? Colors.grey[300] : Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.black, width: 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Transform.translate(
          offset: const Offset(0, 10),
          child: const Text(
            '\uF4DD',
            style: TextStyle(
              fontFamily: 'Bravura',
              fontSize: 28,
              color: Color(0xFF242038),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDottedRestButton(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 40,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _naturalState = 0;
            _sharpState = 0;
            _flatState = 0;
            _dottedRestState = (_naturalState + 1) % 2;
            String accidental = '';
            if (_dottedRestState == 1) {
              accidental = 'dotted_rest';
            }
            context
                .read<SelectedAccidentalProvider>()
                .updateSelectedAccidental(accidental);
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _dottedRestState != 0 ? Colors.grey[300] : Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.black, width: 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Transform.translate(
          offset: const Offset(7, 8),
          child: Row(
            children: [
              Text(
                '\uE1F0 ',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Bravura',
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -2),
                child: Text(
                  '\uE110',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Bravura',
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSelectedNoteProvider =
        Provider.of<CurrentSelectedNoteProvider>(context);
    final selectedNoteIndex = currentSelectedNoteProvider.selectedIndex;
    final selectedRow = currentSelectedNoteProvider.selectedRow;
    final selectedNote = (widget.sheetNoteRows.isNotEmpty &&
            widget.sheetNoteRows[selectedRow].notes.length > selectedNoteIndex)
        ? widget.sheetNoteRows[selectedRow].notes[selectedNoteIndex]
        : null;

    List<String> unicodeCharacters = [
      '\ue1d2',
      '\ue1d3',
      '\ue1d5',
      '\ue1d7',
      '\ue1d9',
      '\ue1db',
      '\ue1dd',
    ];

    return Container(
      height: 294, // Increased height to accommodate the arrows
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Column(
        children: [
          // For notes, show the horizontal scroll of unicode characters
          if (unicodeCharacters.isNotEmpty)
            Row(
              children: [
                Container(
                  margin: EdgeInsets.fromLTRB(8, 0, 0, 0),
                  padding: EdgeInsets.fromLTRB(8, 0, 0, 0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () {
                            widget.onKeyPress(MusicalNote(
                                pitch: "D",
                                octave: 5,
                                type: NoteType.clef,
                                isBeamed: false,
                                unicodeCharacter: "\uf472"));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.black, width: 1),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Transform.translate(
                            offset: const Offset(0, 4),
                            child: Text(
                              '\uf472',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 20,
                                //fontWeight: FontWeight.bold,
                                fontFamily: 'Bravura',
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      //Bass clef
                      SizedBox(
                        width: 30,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () {
                            widget.onKeyPress(MusicalNote(
                                pitch: "D",
                                octave: 5,
                                type: NoteType.clef,
                                isBeamed: false,
                                unicodeCharacter: "\uf474"));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.black, width: 1),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            '\uf474',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              //fontWeight: FontWeight.bold,
                              fontFamily: 'Bravura',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Consumer<SelectedUnicodeProvider>(
                    builder: (context, provider, _) => Container(
                      height: 40,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: unicodeCharacters.length,
                        itemBuilder: (context, index) {
                          final character = unicodeCharacters[index];
                          final isSelected =
                              provider.selectedCharacter == character;
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 5.0),
                            child: SizedBox(
                              width: 35,
                              height: 30,
                              child: ElevatedButton(
                                onPressed: () {
                                  provider.updateSelectedCharacter(character);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isSelected ? Colors.black : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Transform.translate(
                                  offset: const Offset(0, 14),
                                  child: Text(
                                    character,
                                    style: TextStyle(
                                      fontFamily: 'Bravura',
                                      fontSize: 26,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black,
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
                ),
              ],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: EdgeInsets.fromLTRB(0, 2, 5, 5),
                padding: EdgeInsets.fromLTRB(0, 2, 5, 5),
                child: Column(
                  children: [
                    // Time signature button
                    SizedBox(
                      width: 30,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return TimeSignaturePopup(
                                onTimeSignatureSelected: (note) {
                                  widget.onKeyPress(note);
                                },
                              );
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side:
                                const BorderSide(color: Colors.black, width: 1),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Transform.translate(
                          offset: const Offset(0, 11),
                          child: const Text(
                            '\uf5fe', // Represents time signatures in general
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 23,
                              fontFamily: 'Bravura',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    //Key signatures
                    SizedBox(
                      width: 30,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onKeyPress(MusicalNote(
                              pitch: "D",
                              octave: 5,
                              type: NoteType.clef,
                              isBeamed: false,
                              unicodeCharacter: "\uf472"));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.black, width: 1),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Column(children: [
                          Transform.translate(
                            offset: const Offset(-4, 8),
                            child: Text(
                              '\uF4DE',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 21,
                                //fontWeight: FontWeight.bold,
                                fontFamily: 'Bravura',
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(4, -12),
                            child: Text(
                              '\uF4DE',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 21,
                                //fontWeight: FontWeight.bold,
                                fontFamily: 'Bravura',
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 5),
                    _buildShiftButton('rest', 'Rest', context),
                    const SizedBox(height: 5),
                    // Octave cycle button
                    Transform.translate(
                      offset: const Offset(0, 0), //4
                      child: SizedBox(
                        width: 30,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _toggleOctavePair,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.black, width: 1),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Transform.translate(
                            offset: const Offset(0, 6),
                            child: Text(
                              '\uE511',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 24,
                                //fontWeight: FontWeight.bold,
                                fontFamily: 'Bravura',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    //Dynamics button
                    SizedBox(
                      width: 30,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: widget.onToggleDynamicsKeyboard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.black, width: 1),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Transform.translate(
                            offset: const Offset(2, 5),
                            child: Text(
                              '\uE52F',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 27,
                                //fontWeight: FontWeight.bold,
                                fontFamily: 'Bravura',
                              ),
                            )),
                      ),
                    ),
                  ],
                ),
              ),
              KeyboardBySymbols(
                  onKeyPress: widget.onKeyPress, showLowerPair: showLowerPair),
              Container(
                margin: EdgeInsets.fromLTRB(5, 0, 0, 0),
                padding: EdgeInsets.fromLTRB(5, 0, 0, 0),
                child: Column(
                  children: [
                    //Triplets button
                    SizedBox(
                      width: 30,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {
                          if (selectedNote != null) {
                            //if (selectedNoteIndex <
                            //    widget.sheetNoteRows[selectedRow].length - 2) {
                            setState(() {
                              selectedNote.isTriplet = !selectedNote.isTriplet;
                            });
                            //}
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                                color: selectedNote?.isTriplet == true
                                    ? Colors.red
                                    : Colors.black,
                                width: 1),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Transform.translate(
                          offset: const Offset(0, 22),
                          child: Text(
                            '\uE201 \uE202 \uE203',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 22,
                              //fontWeight: FontWeight.bold,
                              fontFamily: 'Bravura',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    _buildDottedRestButton(context),
                    const SizedBox(height: 5),
                    // Shift buttons
                    _buildSharpButton(context),
                    const SizedBox(height: 5),
                    _buildNaturalButton(context),
                    const SizedBox(height: 5),
                    Transform.translate(
                      offset: const Offset(-4, 0),
                      child: _buildFlatButton(context),
                    ),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}
