import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/note_unicode_characters.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/providers/selected_accidental_provider.dart';
import 'package:music_keyboard/src/widgets/keyboard/sheet_keyboard_widgets/keyboard_by_symbols.dart';
import 'package:music_keyboard/src/providers/selected_unicode_provider.dart';
import 'package:music_keyboard/src/widgets/keyboard/sheet_keyboard_widgets/time_signature_popup.dart';
import 'package:music_keyboard/src/widgets/keyboard/sheet_keyboard_widgets/key_signature_popup.dart';
import 'package:music_keyboard/src/widgets/shared/popup_theme.dart';
import 'package:music_keyboard/src/utils/haptic_feedback_utils.dart';
import 'package:provider/provider.dart';

class NotesKeyboardLayout extends StatefulWidget {
  final bool showNotesKeyboard;
  final void Function(bool) onToggleKeyboard;
  final void Function(MusicalNote) onKeyPress;
  final void Function(MusicalNote)? onAddToChord;
  final void Function(MusicalNote)? onRemoveFromChord;
  final void Function(MusicalNote)? onConvertToChord;
  final List<SheetRows> sheetNoteRows;
  final SheetFormat sheetFormat;

  const NotesKeyboardLayout({
    super.key,
    required this.showNotesKeyboard,
    required this.onToggleKeyboard,
    required this.onKeyPress,
    this.onAddToChord,
    this.onRemoveFromChord,
    this.onConvertToChord,
    required this.sheetNoteRows,
    required this.sheetFormat,
  });

  @override
  State<NotesKeyboardLayout> createState() => _NotesKeyboardLayoutState();
}

class _NotesKeyboardLayoutState extends State<NotesKeyboardLayout> {
  String _selectedRestUnicode = '\ue4e5'; // Default rest unicode, whole note
  String _selectedClefUnicode = '\uf472'; // Default clef unicode, treble clef
  String _selectedClefType = 'Treble'; // Default clef type
  // Track which shift button is currently showing its popup
  String? _activeShiftButton;
  // Overlay entry for the popup
  OverlayEntry? _overlayEntry;
  // Global keys to get the positions of the shift buttons
  final Map<String, GlobalKey> _shiftButtonKeys = {
    'sharp': GlobalKey(),
    'flat': GlobalKey(),
    'natural': GlobalKey(),
    'clef': GlobalKey(),
  };

  int _sharpState = 0; // 0: off, 1: sharp, 2: double sharp
  int _flatState = 0; // 0: off, 1: flat, 2: double flat
  int _naturalState = 0; // 0: off, 1: natural
  int _dottedRestState = 0;

  // Octave pair state - false = Middle+Top pair, true = Bottom+Middle pair
  bool showLowerPair = false;

  // Chord mode state
  bool _isChordsActive = false;

  void _toggleOctavePair() {
    setState(() {
      showLowerPair = !showLowerPair;
    });
  }

  /// Routes key presses through chord-mode logic when active.
  /// In chord mode, tapping a note adds it as a child of the current
  /// selected note (which must be a NoteType.chord). If the current
  /// selected note is not yet a chord, a new empty chord is inserted
  /// first, then the tapped note is added to it.
  void _handleKeyPress(MusicalNote note) {
    if (!_isChordsActive) {
      widget.onKeyPress(note);
      return;
    }

    final selectedNoteProvider =
        Provider.of<CurrentSelectedNoteProvider>(context, listen: false);
    final selectedIndex = selectedNoteProvider.selectedIndex;
    final selectedRow = selectedNoteProvider.selectedRow;

    // Check if the current selected note is already a chord container
    bool currentNoteIsChord = false;
    if (widget.sheetNoteRows.isNotEmpty &&
        selectedRow >= 0 &&
        selectedRow < widget.sheetNoteRows.length &&
        selectedIndex >= 0 &&
        selectedIndex < widget.sheetNoteRows[selectedRow].chords.length) {
      currentNoteIsChord =
          widget.sheetNoteRows[selectedRow].chords[selectedIndex].type ==
              NoteType.chord;
    }

    if (currentNoteIsChord) {
      // Check whether this pitch+octave is already a child note.
      // If so, remove it (toggle off); otherwise add it.
      final currentChord =
          widget.sheetNoteRows[selectedRow].chords[selectedIndex];
      final alreadyAdded = currentChord.childNotes?.any((child) =>
              child.pitch == note.pitch && child.octave == note.octave) ??
          false;

      if (alreadyAdded) {
        widget.onRemoveFromChord?.call(note);
      } else {
        widget.onAddToChord?.call(note);
      }
    } else {
      // Convert the currently selected note into a chord, preserving its
      // properties as the first child, and add the tapped note as a child.
      widget.onConvertToChord?.call(note);
    }
  }

  /// Build the chords toggle button shown above the note selector.
  Widget _buildChordsToggleButton() {
    return SizedBox(
      width: 44,
      height: 34,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _isChordsActive = !_isChordsActive;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _isChordsActive ? Colors.black : Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.black, width: 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          'Chord',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: _isChordsActive ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
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

  void _showPopup(String buttonType, BuildContext context) {
    _removeOverlay();

    // Trigger haptic feedback for clef and rest buttons
    if (buttonType == 'clef' || buttonType == 'rest') {
      HapticFeedbackUtils.lightVibration();
    }

    setState(() {
      _activeShiftButton = buttonType;
    });

    List<String> unicodeOptions = _getUnicodeOptions(buttonType);
    int itemCount = unicodeOptions.length;

    double popupWidth = 200.0;
    double buttonSize = 80.0;
    int crossAxisCount = 3;
    int rowCount = (itemCount / crossAxisCount).ceil();
    double popupHeight = (buttonSize * rowCount) + 32.0;

    double? bottom = 85;

    if (buttonType == 'clef') {
      bottom = 130;
    }

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
            bottom: bottom,
            child: Material(
              elevation: 0,
              borderRadius: BorderRadius.circular(PopupTheme.borderRadius),
              child: Container(
                padding: const EdgeInsets.all(PopupTheme.standardPadding),
                decoration: PopupTheme.dialogDecoration,
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
    } else if (buttonType == 'clef') {
      return [
        '\uf472', // Treble clef
        '\uf474', // Bass clef
        '\uf473', // Alto clef
        '\uf473', // Tenor clef (same unicode as Alto)
      ];
    }
    return [];
  }

  // Get clef data with names
  List<Map<String, String>> _getClefOptions() {
    return [
      {'unicode': '\uf472', 'name': 'Treble'},
      {'unicode': '\uf474', 'name': 'Bass'},
      {'unicode': '\uf473', 'name': 'Alto'},
      {'unicode': '\uf473', 'name': 'Tenor'},
    ];
  }

  // Build the content of the popup based on the button type
  Widget _buildPopupContent(String buttonType, BuildContext context) {
    if (buttonType == 'clef') {
      List<Map<String, String>> clefOptions = _getClefOptions();

      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2x2 grid for 4 clefs
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.3,
        ),
        itemCount: clefOptions.length,
        itemBuilder: (context, index) {
          final clef = clefOptions[index];
          final unicode = clef['unicode']!;
          final name = clef['name']!;

          return InkWell(
            onTap: () {
              setState(() {
                _selectedClefUnicode = unicode;
                _selectedClefType = name;
              });
              widget.onKeyPress(MusicalNote(
                pitch: "D",
                octave: 5,
                type: NoteType.clef,
                isBeamed: false,
                unicodeCharacter: unicode,
                clefType: name,
              ));
              _removeOverlay();
            },
            child: Container(
              decoration: PopupTheme.gridItemDecoration,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    unicode,
                    style: const TextStyle(
                      fontFamily: 'Bravura',
                      fontSize: 22,
                      color: PopupTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: PopupTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // Rest popup (existing functionality)
      List<String> unicodeOptions = _getUnicodeOptions(buttonType);

      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.9,
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
                context
                    .read<SelectedAccidentalProvider>()
                    .updateSelectedAccidental(unicode);
              }
              _removeOverlay();
            },
            child: Container(
              decoration: PopupTheme.gridItemDecoration,
              child: Center(
                child: Text(
                  unicode,
                  style: const TextStyle(
                    fontFamily: 'Bravura',
                    fontSize: 40,
                    color: PopupTheme.textPrimary,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
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
            } else if (buttonType == 'clef') {
              widget.onKeyPress(MusicalNote(
                pitch: "D",
                octave: 5,
                type: NoteType.clef,
                isBeamed: false,
                unicodeCharacter: _selectedClefUnicode,
                clefType: _selectedClefType,
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
          child: Transform.translate(
            offset: buttonType == 'clef' && _selectedClefUnicode == '\uf472'
                ? const Offset(0, 4)
                : const Offset(0, 0),
            child: Text(
              buttonType == 'rest'
                  ? _selectedRestUnicode
                  : _selectedClefUnicode,
              style: TextStyle(
                fontFamily: 'Bravura',
                fontSize: buttonType == 'clef' ? 20 : 30,
                color: const Color(0xFF242038),
              ),
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
            _dottedRestState = (_dottedRestState + 1) % 2;
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
            widget.sheetNoteRows[selectedRow].chords.isNotEmpty &&
            widget.sheetNoteRows[selectedRow].chords.length >
                selectedNoteIndex &&
            selectedNoteIndex != -1)
        ? widget.sheetNoteRows[selectedRow].chords[selectedNoteIndex]
        : null;

    List<NoteUnicodeCharacters> unicodeCharacters = [
      NoteUnicodeCharacters(normal: '\ue1d2', upsideDown: '\ue1d2'), //whole
      NoteUnicodeCharacters(normal: '\ue1d3', upsideDown: '\ue1d4'), //half
      NoteUnicodeCharacters(normal: '\ue1d5', upsideDown: '\ue1d6'), //quarter
      NoteUnicodeCharacters(normal: '\ue1d7', upsideDown: '\ue1d8'), //eigth
      NoteUnicodeCharacters(normal: '\ue1d9', upsideDown: '\ue1da'), //sixteenth
      NoteUnicodeCharacters(
          normal: '\ue1db', upsideDown: '\ue1dc'), //thirtysecond
      NoteUnicodeCharacters(
          normal: '\ue1dd', upsideDown: '\ue1de'), //sixtyfouth
    ];

    return Container(
      height: 270, // Increased height to accommodate the arrows
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Column(
        children: [
          // Note selector row with optional chord toggle and nav buttons
          if (unicodeCharacters.isNotEmpty)
            Row(
              children: [
                const SizedBox(width: 12),
                // Chords toggle button (always visible)
                _buildChordsToggleButton(),
                const SizedBox(width: 4),
                // Unicode note-type selector
                Expanded(
                  child: Consumer<SelectedUnicodeProvider>(
                    builder: (context, provider, _) => LayoutBuilder(
                      builder: (context, constraints) {
                        final itemCount = unicodeCharacters.length;
                        final itemWidth = constraints.maxWidth / itemCount;

                        return SizedBox(
                          height: 34,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: itemCount,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final character = unicodeCharacters[index];
                              final isSelected =
                                  provider.selectedCharacter == character;

                              return SizedBox(
                                width: itemWidth,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(5, 1, 5, 1),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      provider
                                          .updateSelectedCharacter(character);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isSelected
                                          ? Colors.black
                                          : Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Transform.translate(
                                      offset: character.normal == "\ue1d2"
                                          ? const Offset(0, 2)
                                          : const Offset(0, 10),
                                      child: Text(
                                        character.normal,
                                        style: TextStyle(
                                          fontFamily: 'Bravura',
                                          fontSize: 20,
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
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 12),
              ],
            ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: EdgeInsets.fromLTRB(0, 0, 5, 0),
                padding: EdgeInsets.fromLTRB(0, 0, 5, 0),
                child: Column(
                  children: [
                    //Clefs
                    _buildShiftButton('clef', 'Clef', context),
                    const SizedBox(height: 5),
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
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return KeySignaturePopup(
                                onKeySignatureSelected: (note) {
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
                    //Triplets button
                    SizedBox(
                      width: 30,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {
                          if (selectedNote != null) {
                            setState(() {
                              selectedNote.isTriplet = !selectedNote.isTriplet;
                            });
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
                    )
                  ],
                ),
              ),
              KeyboardBySymbols(
                  onKeyPress: _handleKeyPress,
                  showLowerPair: showLowerPair,
                  sheetNoteRows: widget.sheetNoteRows,
                  sheetFormat: widget.sheetFormat,
                  // When chord mode is active, pass child notes so already-added
                  // keys get a blue border. If the note isn't a chord yet, wrap
                  // it in a list so its own key is pre-highlighted.
                  chordChildNotes: _isChordsActive
                      ? (selectedNote?.type == NoteType.chord
                          ? selectedNote?.childNotes
                          : (selectedNote != null &&
                                  selectedNote.type != NoteType.space
                              ? [selectedNote]
                              : null))
                      : null),
              Container(
                margin: EdgeInsets.fromLTRB(5, 0, 0, 0),
                padding: EdgeInsets.fromLTRB(5, 0, 0, 0),
                child: Column(
                  children: [
                    const SizedBox(height: 5),
                    // Shift buttons
                    _buildSharpButton(context),
                    const SizedBox(height: 5),
                    _buildNaturalButton(context),
                    const SizedBox(height: 5),
                    _buildFlatButton(context),
                    const SizedBox(height: 5),
                    _buildDottedRestButton(context),
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
