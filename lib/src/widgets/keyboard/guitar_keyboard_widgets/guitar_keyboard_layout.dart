import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GuitarKeyboardLayout extends StatefulWidget {
  final bool showNotesKeyboard;
  final void Function(bool) onToggleKeyboard;
  final void Function(MusicalNote) onKeyPress;
  final List<SheetRows> sheetNoteRows;
  final SheetFormat sheetFormat;

  const GuitarKeyboardLayout({
    super.key,
    required this.showNotesKeyboard,
    required this.onToggleKeyboard,
    required this.onKeyPress,
    required this.sheetNoteRows,
    required this.sheetFormat,
  });

  @override
  State<GuitarKeyboardLayout> createState() => _GuitarKeyboardLayoutState();
}

class _GuitarKeyboardLayoutState extends State<GuitarKeyboardLayout> {
  // Overlay entry for the popup
  OverlayEntry? _overlayEntry;

  // Octave pair state - false = Middle+Top pair, true = Bottom+Middle pair
  bool showLowerPair = false;

  // Currently selected string (0-5 for E, B, G, D, A, E from top to bottom)
  int _selectedStringIndex = 0;

  // String names in order from top to bottom
  final List<String> _stringNames = ['E', 'B', 'G', 'D', 'A', 'E'];

  bool _isBendActive = false;
  bool _isPreBendActive = false;
  bool _isBendReleaseActive = false;
  bool _isPreBendReleaseActive = false;

  // Track previous selected note to detect changes
  int _previousSelectedRow = -1;
  int _previousSelectedIndex = -1;

  // Flag to indicate if navigation was from Next button (preserve lock state)
  bool _navigatedViaNextButton = false;

  @override
  void dispose() {
    // Make sure to remove any active overlay when disposing
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    super.dispose();
  }

  // Helper: Get current chord being edited
  MusicalNote? _getCurrentChord(int selectedRow, int selectedNoteIndex) {
    if (widget.sheetNoteRows.isEmpty) return null;
    if (selectedRow >= widget.sheetNoteRows.length) return null;
    if (widget.sheetNoteRows[selectedRow].chords.isEmpty) return null;
    if (selectedNoteIndex < 0 ||
        selectedNoteIndex >= widget.sheetNoteRows[selectedRow].chords.length) {
      return null;
    }
    return widget.sheetNoteRows[selectedRow].chords[selectedNoteIndex];
  }

  // Helper: Get fret number for a specific string in current chord
  String? _getFretForString(MusicalNote? chord, int stringIndex) {
    if (chord?.childNotes == null) return null;

    for (var childNote in chord!.childNotes!) {
      if (childNote.octave == stringIndex) {
        return childNote.unicodeCharacter;
      }
    }
    return null;
  }

  // Helper: Update fret for a specific string
  void _updateFretForString(
      int selectedRow, int selectedNoteIndex, int stringIndex, int fretNumber) {
    final chord = _getCurrentChord(selectedRow, selectedNoteIndex);

    if (chord == null) {
      // No chord exists at this position, cannot update
      return;
    }

    // Initialize childNotes if null
    chord.childNotes ??= [];

    // Find existing childNote for this string or create new one
    bool found = false;
    for (int i = 0; i < chord.childNotes!.length; i++) {
      if (chord.childNotes![i].octave == stringIndex) {
        // Update existing childNote
        chord.childNotes![i] = MusicalNote(
          pitch: _stringNames[stringIndex],
          octave: stringIndex,
          type: NoteType.fret,
          unicodeCharacter: fretNumber.toString(),
          duration: 0.0,
        );
        found = true;
        break;
      }
    }

    if (!found) {
      // Add new childNote for this string
      chord.childNotes!.add(MusicalNote(
        pitch: _stringNames[stringIndex],
        octave: stringIndex,
        type: NoteType.fret,
        unicodeCharacter: fretNumber.toString(),
        duration: 0.0,
      ));
    }

    // Trigger UI update
    setState(() {});
  }

  // Build a technique button (for top two rows)
  Widget _buildTechniqueButton(String identifer, String label,
      {bool isUnicode = true,
      String? svgAssetPath,
      VoidCallback? onPressed,
      bool isActive = false,
      bool isLocked = false}) {
    return SizedBox(
      width: 32,
      height: 32,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? (isLocked ? Colors.blue[300] : Colors.blue[100])
              : Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: BorderSide(
                color: isActive ? Colors.blue : Colors.black,
                width: isActive ? 2 : 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Stack(
          children: [
            Center(
              child: svgAssetPath != null
                  ? SvgPicture.asset(svgAssetPath,
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.linearToSrgbGamma())
                  : Text(
                      label,
                      style: TextStyle(
                        fontFamily: isUnicode ? 'Bravura' : null,
                        fontSize: isUnicode ? 30 : 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
            if (isLocked)
              Positioned(
                bottom: 1,
                right: 1,
                child: Icon(
                  Icons.lock,
                  size: 10,
                  color: Colors.blue[900],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper: Check if current chord has bend start property set
  bool _checkIfCurrentChordHasBend(
      String bendType, int selectedRow, int selectedNoteIndex) {
    final chord = _getCurrentChord(selectedRow, selectedNoteIndex);
    if (chord == null) return false;

    switch (bendType) {
      case 'bend':
        return chord.isBendStart;
      case 'pre-bend':
        return chord.isPreBendStart;
      case 'bend-release':
        return chord.isBendReleaseStart;
      case 'pre-bend-release':
        return chord.isPreBendReleaseStart;
      default:
        return false;
    }
  }

  // Helper: Check if current note is within a bend range from a preceding note
  bool _isWithinBendRange(
      String bendType, int selectedRow, int selectedNoteIndex) {
    if (selectedRow < 0 || selectedRow >= widget.sheetNoteRows.length) {
      return false;
    }

    final chords = widget.sheetNoteRows[selectedRow].chords;

    // Look for a preceding note with an active bend that includes current index
    for (int i = 0; i < chords.length && i <= selectedNoteIndex; i++) {
      final chord = chords[i];

      switch (bendType) {
        case 'bend':
          if (chord.isBendStart &&
              chord.bendEndIndex != null &&
              i <= selectedNoteIndex &&
              selectedNoteIndex <= chord.bendEndIndex!) {
            return true;
          }
          break;
        case 'pre-bend':
          if (chord.isPreBendStart &&
              chord.preBendEndIndex != null &&
              i <= selectedNoteIndex &&
              selectedNoteIndex <= chord.preBendEndIndex!) {
            return true;
          }
          break;
        case 'bend-release':
          if (chord.isBendReleaseStart &&
              chord.bendReleaseEndIndex != null &&
              i <= selectedNoteIndex &&
              selectedNoteIndex <= chord.bendReleaseEndIndex!) {
            return true;
          }
          break;
        case 'pre-bend-release':
          if (chord.isPreBendReleaseStart &&
              chord.preBendReleaseEndIndex != null &&
              i <= selectedNoteIndex &&
              selectedNoteIndex <= chord.preBendReleaseEndIndex!) {
            return true;
          }
          break;
      }
    }

    return false;
  }

  // Helper: Handle bend button press
  void _handleBendButtonPress(
      String bendType, int selectedRow, int selectedNoteIndex) {
    final chord = _getCurrentChord(selectedRow, selectedNoteIndex);
    if (chord == null) return;

    setState(() {
      switch (bendType) {
        case 'bend':
          // Toggle lock state
          _isBendActive = !_isBendActive;
          // If locking, ensure bend properties are set
          if (_isBendActive) {
            chord.isBendStart = true;
            chord.bendEndIndex = selectedNoteIndex;
          }
          break;
        case 'pre-bend':
          // Toggle lock state
          _isPreBendActive = !_isPreBendActive;
          // If locking, ensure bend properties are set
          if (_isPreBendActive) {
            chord.isPreBendStart = true;
            chord.preBendEndIndex = selectedNoteIndex;
          }
          break;
        case 'bend-release':
          // Toggle lock state
          _isBendReleaseActive = !_isBendReleaseActive;
          // If locking, ensure bend properties are set
          if (_isBendReleaseActive) {
            chord.isBendReleaseStart = true;
            chord.bendReleaseEndIndex = selectedNoteIndex;
          }
          break;
        case 'pre-bend-release':
          // Toggle lock state
          _isPreBendReleaseActive = !_isPreBendReleaseActive;
          // If locking, ensure bend properties are set
          if (_isPreBendReleaseActive) {
            chord.isPreBendReleaseStart = true;
            chord.preBendReleaseEndIndex = selectedNoteIndex;
          }
          break;
      }
    });
  }

  // Build a string button (E, A, D, G, B, E)
  Widget _buildStringButton(String note, int stringIndex) {
    bool isSelected = _selectedStringIndex == stringIndex;

    return Container(
      height: 25,
      width: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8), // Match your button's shape
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            blurRadius: 5,
            spreadRadius: 0,
            offset: Offset.zero, // This centers the shadow
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedStringIndex = stringIndex;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue[100] : Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: BorderSide(
                color: isSelected
                    ? Colors.blue
                    : const Color.fromARGB(255, 218, 218, 218),
                width: isSelected ? 2 : 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          note,
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Build a fret button (numbers 1-24)
  Widget _buildFretButton(
      int fretNumber, int selectedRow, int selectedNoteIndex) {
    // Get current chord and check if this fret is assigned to selected string
    final currentChord = _getCurrentChord(selectedRow, selectedNoteIndex);
    final currentFret = _getFretForString(currentChord, _selectedStringIndex);
    bool isAssignedToCurrentString = currentFret == fretNumber.toString();

    return Container(
      height: 31,
      width: 31,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      child: ElevatedButton(
        onPressed: () {
          _updateFretForString(
              selectedRow, selectedNoteIndex, _selectedStringIndex, fretNumber);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isAssignedToCurrentString ? Colors.green[200] : Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: BorderSide(
                color: isAssignedToCurrentString ? Colors.green : Colors.black,
                width: isAssignedToCurrentString ? 2 : 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          fretNumber.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight:
                isAssignedToCurrentString ? FontWeight.bold : FontWeight.normal,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildNextLastButton(
      bool isNextNote, int selectedRow, int selectedNoteIndex) {
    double buttonWidth = MediaQuery.of(context).size.width / 2.8;

    // Validate inputs to prevent crashes
    bool isValidState = widget.sheetNoteRows.isNotEmpty &&
        selectedRow >= 0 &&
        selectedRow < widget.sheetNoteRows.length;

    return Container(
      height: 31,
      width: buttonWidth,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      child: ElevatedButton(
        onPressed: isValidState
            ? () {
                final currentSelectedNoteProvider =
                    Provider.of<CurrentSelectedNoteProvider>(context,
                        listen: false);

                if (isNextNote) {
                  // Only update bend end indices if in locked mode
                  if (_isBendActive ||
                      _isPreBendActive ||
                      _isBendReleaseActive ||
                      _isPreBendReleaseActive) {
                    final chords = widget.sheetNoteRows[selectedRow].chords;

                    for (int i = 0; i < chords.length; i++) {
                      final chord = chords[i];

                      // Update bend end indices only for locked bends
                      if (_isBendActive &&
                          chord.isBendStart &&
                          chord.bendEndIndex != null &&
                          i <= selectedNoteIndex &&
                          selectedNoteIndex <= chord.bendEndIndex!) {
                        chord.bendEndIndex = selectedNoteIndex + 1;
                        break;
                      }
                      if (_isPreBendActive &&
                          chord.isPreBendStart &&
                          chord.preBendEndIndex != null &&
                          i <= selectedNoteIndex &&
                          selectedNoteIndex <= chord.preBendEndIndex!) {
                        chord.preBendEndIndex = selectedNoteIndex + 1;
                        break;
                      }
                      if (_isBendReleaseActive &&
                          chord.isBendReleaseStart &&
                          chord.bendReleaseEndIndex != null &&
                          i <= selectedNoteIndex &&
                          selectedNoteIndex <= chord.bendReleaseEndIndex!) {
                        chord.bendReleaseEndIndex = selectedNoteIndex + 1;
                        break;
                      }
                      if (_isPreBendReleaseActive &&
                          chord.isPreBendReleaseStart &&
                          chord.preBendReleaseEndIndex != null &&
                          i <= selectedNoteIndex &&
                          selectedNoteIndex <= chord.preBendReleaseEndIndex!) {
                        chord.preBendReleaseEndIndex = selectedNoteIndex + 1;
                        break;
                      }
                    }
                  }

                  // Next button: Always add a new note
                  int nextIndex = selectedNoteIndex + 1;

                  // Create empty chord with G as default pitch
                  MusicalNote emptyChord = MusicalNote(
                    pitch: 'G',
                    octave: 4,
                    type: NoteType.fret,
                    duration: 0.0,
                    childNotes: [],
                  );
                  widget.onKeyPress(emptyChord);

                  // Set flag to preserve lock state when navigating
                  setState(() {
                    _navigatedViaNextButton = true;
                  });

                  // Move to next position (onKeyPress will update the selected index)
                  currentSelectedNoteProvider
                      .updateSelectedIndexAndInsertionPoint(
                          selectedRow, nextIndex);
                } else {
                  // Back button: Move to previous chord position
                  if (selectedNoteIndex > 0) {
                    currentSelectedNoteProvider
                        .updateSelectedIndexAndInsertionPoint(
                            selectedRow, selectedNoteIndex - 1);
                  }
                }
              }
            : null, // Disable button if state is invalid
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: isNextNote
              ? [
                  const Text('Next', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 18),
                ]
              : [
                  const Icon(Icons.arrow_back, size: 18),
                  const SizedBox(width: 4),
                  const Text('Back', style: TextStyle(fontSize: 14)),
                ],
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
            selectedRow >= 0 &&
            selectedRow < widget.sheetNoteRows.length &&
            widget.sheetNoteRows[selectedRow].chords.isNotEmpty &&
            widget.sheetNoteRows[selectedRow].chords.length >
                selectedNoteIndex &&
            selectedNoteIndex != -1)
        ? widget.sheetNoteRows[selectedRow].chords[selectedNoteIndex]
        : null;

    // Reset state variables when selected note changes (never auto-lock)
    if (_previousSelectedRow != selectedRow ||
        _previousSelectedIndex != selectedNoteIndex) {
      // Use post-frame callback to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // Only reset lock states if NOT navigated via Next button
            if (!_navigatedViaNextButton) {
              _isBendActive = false;
              _isPreBendActive = false;
              _isBendReleaseActive = false;
              _isPreBendReleaseActive = false;
            }
            // Reset the flag after checking
            _navigatedViaNextButton = false;
            _previousSelectedRow = selectedRow;
            _previousSelectedIndex = selectedNoteIndex;
          });
        }
      });
    }

    return Container(
      height: 270,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 30,
                width: 25,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(8), // Match your button's shape
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey,
                      blurRadius: 5,
                      spreadRadius: 0,
                      offset: Offset.zero, // This centers the shadow
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement string selection functionality
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                      side: const BorderSide(
                          color: Color.fromARGB(255, 218, 218, 218), width: 1),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    '\uF40A',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontFamily: 'Bravura',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _buildNextLastButton(false, selectedRow, selectedNoteIndex),
                _buildNextLastButton(true, selectedRow, selectedNoteIndex)
              ]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStringButton('E', 0),
                  const SizedBox(height: 7),
                  _buildStringButton('B', 1),
                  const SizedBox(height: 7),
                  _buildStringButton('G', 2),
                  const SizedBox(height: 7),
                  _buildStringButton('D', 3),
                  const SizedBox(height: 7),
                  _buildStringButton('A', 4),
                  const SizedBox(height: 7),
                  _buildStringButton('E', 5),
                ],
              ),
              Column(
                children: [
                  const SizedBox(height: 5),
                  // First technique row with 7 buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTechniqueButton('mute', 'P.M.', isUnicode: false),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('pinch-harmonic', 'P.H.',
                          isUnicode: false),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('vibrato', '\uE589'),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('hammer-left-hand', '\uE4BA'),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('bend', 'bend',
                          svgAssetPath: 'assets/svgs/bend.svg',
                          onPressed: () => _handleBendButtonPress(
                              'bend', selectedRow, selectedNoteIndex),
                          isActive: _isBendActive ||
                              _checkIfCurrentChordHasBend(
                                  'bend', selectedRow, selectedNoteIndex),
                          isLocked: _isBendActive),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('pre-bend', 'pre-bend',
                          svgAssetPath: 'assets/svgs/pre-bend.svg',
                          onPressed: () => _handleBendButtonPress(
                              'pre-bend', selectedRow, selectedNoteIndex),
                          isActive: _isPreBendActive ||
                              _checkIfCurrentChordHasBend(
                                  'pre-bend', selectedRow, selectedNoteIndex),
                          isLocked: _isPreBendActive),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('pick-downward', '\uE610'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Second technique row with 7 buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTechniqueButton('tap-right-hand', '\uE682 '),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('harmonic', 'Ham.',
                          isUnicode: false),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('slide-up', '\uEA6D'),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('slide-down', '\uEA6E'),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('bend-release', 'bend-release',
                          svgAssetPath: 'assets/svgs/bend-release.svg',
                          onPressed: () => _handleBendButtonPress(
                              'bend-release', selectedRow, selectedNoteIndex),
                          isActive: _isBendReleaseActive ||
                              _checkIfCurrentChordHasBend('bend-release',
                                  selectedRow, selectedNoteIndex),
                          isLocked: _isBendReleaseActive),
                      const SizedBox(width: 7),
                      _buildTechniqueButton(
                          'pre-bend-release', 'pre-bend-release',
                          svgAssetPath: 'assets/svgs/pre-bend-release.svg',
                          onPressed: () => _handleBendButtonPress(
                              'pre-bend-release',
                              selectedRow,
                              selectedNoteIndex),
                          isActive: _isPreBendReleaseActive ||
                              _checkIfCurrentChordHasBend('pre-bend-release',
                                  selectedRow, selectedNoteIndex),
                          isLocked: _isPreBendReleaseActive),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('pick-upward', '\uE612'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      //mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildFretButton(1, selectedRow, selectedNoteIndex),
                        _buildFretButton(2, selectedRow, selectedNoteIndex),
                        _buildFretButton(3, selectedRow, selectedNoteIndex),
                        _buildFretButton(4, selectedRow, selectedNoteIndex),
                        _buildFretButton(5, selectedRow, selectedNoteIndex),
                        _buildFretButton(6, selectedRow, selectedNoteIndex),
                        _buildFretButton(7, selectedRow, selectedNoteIndex),
                        _buildFretButton(8, selectedRow, selectedNoteIndex),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Fret numbers row 2 (9-16)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFretButton(9, selectedRow, selectedNoteIndex),
                        _buildFretButton(10, selectedRow, selectedNoteIndex),
                        _buildFretButton(11, selectedRow, selectedNoteIndex),
                        _buildFretButton(12, selectedRow, selectedNoteIndex),
                        _buildFretButton(13, selectedRow, selectedNoteIndex),
                        _buildFretButton(14, selectedRow, selectedNoteIndex),
                        _buildFretButton(15, selectedRow, selectedNoteIndex),
                        _buildFretButton(16, selectedRow, selectedNoteIndex),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Fret numbers row 3 (17-24)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFretButton(17, selectedRow, selectedNoteIndex),
                        _buildFretButton(18, selectedRow, selectedNoteIndex),
                        _buildFretButton(19, selectedRow, selectedNoteIndex),
                        _buildFretButton(20, selectedRow, selectedNoteIndex),
                        _buildFretButton(21, selectedRow, selectedNoteIndex),
                        _buildFretButton(22, selectedRow, selectedNoteIndex),
                        _buildFretButton(23, selectedRow, selectedNoteIndex),
                        _buildFretButton(24, selectedRow, selectedNoteIndex),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
