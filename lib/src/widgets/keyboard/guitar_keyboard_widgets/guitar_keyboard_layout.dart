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
  final void Function(VoidCallback spaceHandler)? onRegisterSpaceHandler;

  const GuitarKeyboardLayout({
    super.key,
    required this.showNotesKeyboard,
    required this.onToggleKeyboard,
    required this.onKeyPress,
    required this.sheetNoteRows,
    required this.sheetFormat,
    this.onRegisterSpaceHandler,
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
  bool _isMuteActive = false;
  bool _isPinchHarmonicActive = false;
  bool _isHarmonicActive = false;
  bool _isVibratoActive = false;
  bool _isTapRightHandActive = false;

  // Lock state tracking for three-tap behavior
  bool _isBendLocked = false;
  bool _isPreBendLocked = false;
  bool _isBendReleaseLocked = false;
  bool _isPreBendReleaseLocked = false;
  bool _isMuteLocked = false;
  bool _isPinchHarmonicLocked = false;
  bool _isHarmonicLocked = false;
  bool _isVibratoLocked = false;

  // Track previous selected note to detect changes
  int _previousSelectedRow = -1;
  int _previousSelectedIndex = -1;

  // Flag to indicate if navigation was from Next button (preserve lock state)
  bool _navigatedViaNextButton = false;

  @override
  void initState() {
    super.initState();
    // Register the space press handler with the parent after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onRegisterSpaceHandler?.call(_handleSpacePress);
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

  void _handleSpacePress() {
    if (!mounted) return;

    final currentSelectedNoteProvider =
        Provider.of<CurrentSelectedNoteProvider>(context, listen: false);
    final selectedRow = currentSelectedNoteProvider.selectedRow;
    final selectedNoteIndex = currentSelectedNoteProvider.selectedIndex;

    // Guard against invalid state
    if (widget.sheetNoteRows.isEmpty ||
        selectedRow < 0 ||
        selectedRow >= widget.sheetNoteRows.length ||
        selectedNoteIndex < 0) {
      widget.onKeyPress(MusicalNote(
        pitch: 'G',
        octave: 4,
        type: NoteType.fret,
        duration: 0.0,
        childNotes: [],
      ));
      return;
    }

    // Preserve active/locked technique button states across the insertion
    setState(() {
      _navigatedViaNextButton = true;
    });

    // Insert the new fret chord
    widget.onKeyPress(MusicalNote(
      pitch: 'G',
      octave: 4,
      type: NoteType.fret,
      duration: 0.0,
      childNotes: [],
    ));
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
  MusicalNote _updateFretForString(
      int selectedRow, int selectedNoteIndex, int stringIndex, int fretNumber,
      {bool goToNextString = true}) {
    final chord = _getCurrentChord(selectedRow, selectedNoteIndex);

    if (chord == null) {
      // No chord exists at this position, cannot update
      return MusicalNote(pitch: "", octave: 0, type: NoteType.space);
    }

    // Initialize childNotes if null
    chord.childNotes ??= [];

    bool fretWasAdded = false;

    // Find existing childNote for this string or create new one
    bool found = false;
    for (int i = 0; i < chord.childNotes!.length; i++) {
      if (chord.childNotes![i].octave == stringIndex) {
        found = true;

        if (fretNumber.toString() == chord.childNotes![i].unicodeCharacter) {
          chord.childNotes!.removeAt(i);
          break;
        }

        chord.childNotes![i] = MusicalNote(
          pitch: _stringNames[stringIndex],
          octave: stringIndex,
          type: NoteType.fret,
          unicodeCharacter: fretNumber.toString(),
          duration: 0.0,
          isBendStart: chord.childNotes![i].isBendStart,
          isPreBendStart: chord.childNotes![i].isPreBendStart,
          isBendReleaseStart: chord.childNotes![i].isBendReleaseStart,
          isPreBendReleaseStart: chord.childNotes![i].isPreBendReleaseStart,
          bendEndIndex: chord.childNotes![i].bendEndIndex,
          preBendEndIndex: chord.childNotes![i].preBendEndIndex,
          bendReleaseEndIndex: chord.childNotes![i].bendReleaseEndIndex,
          preBendReleaseEndIndex: chord.childNotes![i].preBendReleaseEndIndex,
        );
        fretWasAdded = true;
        break;
      }
    }

    var newChildNote = MusicalNote(
      pitch: _stringNames[stringIndex],
      octave: stringIndex,
      type: NoteType.fret,
      unicodeCharacter: fretNumber == 0 ? "" : fretNumber.toString(),
      duration: 0.0,
    );

    if (!found) {
      chord.childNotes!.add(newChildNote);
      fretWasAdded = true;
    }

    if (fretWasAdded && goToNextString) {
      setState(() {});
      //Currently commented out as I think it is uncessary logic, can demo at next session.
      /*setState(() {
        // Switch to next string (0->1->2->3->4->5->0)
        _selectedStringIndex = (_selectedStringIndex + 1) % 6;

        // Update bend button states to reflect the new current string
        _updateBendButtonStatesForCurrentString(selectedRow, selectedNoteIndex);
      });*/
    } else {
      setState(() {});
    }

    return newChildNote;
  }

  // Build a technique button (for top two rows)
  Widget _buildTechniqueButton(String identifer, String label,
      {double fontSize = 0,
      bool isUnicode = true,
      String? svgAssetPath,
      VoidCallback? onPressed,
      bool isActive = false,
      bool isLocked = false,
      Offset offset = Offset.zero}) {
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
                child: Transform.translate(
              offset: offset,
              child: svgAssetPath != null
                  ? SvgPicture.asset(svgAssetPath,
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.linearToSrgbGamma())
                  : Text(
                      label,
                      style: TextStyle(
                        fontFamily: isUnicode ? 'Bravura' : null,
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
            )),
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

  void _updateBendOnlyStatesForCurrentString(
      int selectedRow, int selectedNoteIndex) {
    final chord = _getCurrentChord(selectedRow, selectedNoteIndex);
    if (chord == null || chord.childNotes == null) {
      _isBendActive = false;
      _isPreBendActive = false;
      _isBendReleaseActive = false;
      _isPreBendReleaseActive = false;
      _isBendLocked = false;
      _isPreBendLocked = false;
      _isBendReleaseLocked = false;
      _isPreBendReleaseLocked = false;
      return;
    }

    MusicalNote? childNote;
    for (var child in chord.childNotes!) {
      if (child.octave == _selectedStringIndex) {
        childNote = child;
        break;
      }
    }

    if (childNote == null) {
      _isBendActive = false;
      _isPreBendActive = false;
      _isBendReleaseActive = false;
      _isPreBendReleaseActive = false;
      _isBendLocked = false;
      _isPreBendLocked = false;
      _isBendReleaseLocked = false;
      _isPreBendReleaseLocked = false;
      return;
    }

    _isBendActive = childNote.isBendStart;
    _isPreBendActive = childNote.isPreBendStart;
    _isBendReleaseActive = childNote.isBendReleaseStart;
    _isPreBendReleaseActive = childNote.isPreBendReleaseStart;

    _isBendLocked =
        childNote.bendEndIndex != null && childNote.bendEndIndex! >= 0;
    _isPreBendLocked =
        childNote.preBendEndIndex != null && childNote.preBendEndIndex! >= 0;
    _isBendReleaseLocked = childNote.bendReleaseEndIndex != null &&
        childNote.bendReleaseEndIndex! >= 0;
    _isPreBendReleaseLocked = childNote.preBendReleaseEndIndex != null &&
        childNote.preBendReleaseEndIndex! >= 0;
  }

  // Helper: Check if current chord has bend start property set for the selected string
  bool _checkIfCurrentChordHasBend(
      String bendType, int selectedRow, int selectedNoteIndex) {
    final chord = _getCurrentChord(selectedRow, selectedNoteIndex);
    if (chord == null || chord.childNotes == null) return false;

    // Find the childNote for the currently selected string
    MusicalNote? childNote;
    for (var child in chord.childNotes!) {
      if (child.octave == _selectedStringIndex) {
        childNote = child;
        break;
      }
    }

    if (childNote == null) return false;

    switch (bendType) {
      case 'bend':
        return childNote.isBendStart;
      case 'pre-bend':
        return childNote.isPreBendStart;
      case 'bend-release':
        return childNote.isBendReleaseStart;
      case 'pre-bend-release':
        return childNote.isPreBendReleaseStart;
      default:
        return false;
    }
  }

  // Helper: Handle bend button press for the selected string
  void _handleBendButtonPress(
      String bendType, int selectedRow, int selectedNoteIndex) {
    final chord = _getCurrentChord(selectedRow, selectedNoteIndex);
    if (chord == null) return;

    // Initialize childNotes if null
    chord.childNotes ??= [];

    // Find or create the childNote for the currently selected string
    MusicalNote? childNote;
    for (var child in chord.childNotes!) {
      if (child.octave == _selectedStringIndex) {
        childNote = child;
        break;
      }
    }

    // If no childNote exists for this string, we can't add a bend without a fret
    childNote ??= _updateFretForString(
        selectedRow, selectedNoteIndex, _selectedStringIndex, 0,
        goToNextString: false);

    setState(() {
      // Determine current state for this bend type
      bool isCurrentlyActive = false;
      bool isCurrentlyLocked = false;

      switch (bendType) {
        case 'bend':
          isCurrentlyActive = _isBendActive;
          isCurrentlyLocked = _isBendLocked;
          break;
        case 'pre-bend':
          isCurrentlyActive = _isPreBendActive;
          isCurrentlyLocked = _isPreBendLocked;
          break;
        case 'bend-release':
          isCurrentlyActive = _isBendReleaseActive;
          isCurrentlyLocked = _isBendReleaseLocked;
          break;
        case 'pre-bend-release':
          isCurrentlyActive = _isPreBendReleaseActive;
          isCurrentlyLocked = _isPreBendReleaseLocked;
          break;
      }

      // Three-tap behavior logic
      if (!isCurrentlyActive) {
        // First tap: set note to active and enter lock state
        // Before setting the new bend type, update all existing childNotes to have the same bend type
        // Get the endIndex from existing childNotes before updating them
        int? existingEndIndex = _getExistingBendEndIndex(chord);
        if (existingEndIndex != null) {
          _updateAllChildNotesToSameBendType(chord, bendType, existingEndIndex);
        }

        switch (bendType) {
          case 'bend':
            _isBendActive = true;
            _isBendLocked = true;
            childNote!.isBendStart = true;
            childNote.bendEndIndex =
                existingEndIndex ?? (selectedNoteIndex - 1);
            break;
          case 'pre-bend':
            _isPreBendActive = true;
            _isPreBendLocked = true;
            childNote!.isPreBendStart = true;
            childNote.preBendEndIndex =
                existingEndIndex ?? (selectedNoteIndex - 1);
            break;
          case 'bend-release':
            _isBendReleaseActive = true;
            _isBendReleaseLocked = true;
            childNote!.isBendReleaseStart = true;
            childNote.bendReleaseEndIndex =
                existingEndIndex ?? (selectedNoteIndex - 1);
            break;
          case 'pre-bend-release':
            _isPreBendReleaseActive = true;
            _isPreBendReleaseLocked = true;
            childNote!.isPreBendReleaseStart = true;
            childNote.preBendReleaseEndIndex =
                existingEndIndex ?? (selectedNoteIndex - 1);
            break;
        }
      } else if (isCurrentlyActive && isCurrentlyLocked) {
        // Second tap: switch to active state without lock state
        switch (bendType) {
          case 'bend':
            _isBendLocked = false;
            break;
          case 'pre-bend':
            _isPreBendLocked = false;
            break;
          case 'bend-release':
            _isBendReleaseLocked = false;
            break;
          case 'pre-bend-release':
            _isPreBendReleaseLocked = false;
            break;
        }
      } else {
        // Third tap: switch active state off and remove bend from note
        switch (bendType) {
          case 'bend':
            _isBendActive = false;
            _isBendLocked = false;
            childNote!.isBendStart = false;
            childNote.bendEndIndex = null;
            break;
          case 'pre-bend':
            _isPreBendActive = false;
            _isPreBendLocked = false;
            childNote!.isPreBendStart = false;
            childNote.preBendEndIndex = null;
            break;
          case 'bend-release':
            _isBendReleaseActive = false;
            _isBendReleaseLocked = false;
            childNote!.isBendReleaseStart = false;
            childNote.bendReleaseEndIndex = null;
            break;
          case 'pre-bend-release':
            _isPreBendReleaseActive = false;
            _isPreBendReleaseLocked = false;
            childNote!.isPreBendReleaseStart = false;
            childNote.preBendReleaseEndIndex = null;
            break;
        }
      }

      // Clear other bend states (mutually exclusive)
      if (bendType != 'bend') {
        _isBendActive = false;
        _isBendLocked = false;
        childNote!.isBendStart = false;
        childNote.bendEndIndex = null;
      }
      if (bendType != 'pre-bend') {
        _isPreBendActive = false;
        _isPreBendLocked = false;
        childNote!.isPreBendStart = false;
        childNote.preBendEndIndex = null;
      }
      if (bendType != 'bend-release') {
        _isBendReleaseActive = false;
        _isBendReleaseLocked = false;
        childNote!.isBendReleaseStart = false;
        childNote.bendReleaseEndIndex = null;
      }
      if (bendType != 'pre-bend-release') {
        _isPreBendReleaseActive = false;
        _isPreBendReleaseLocked = false;
        childNote!.isPreBendReleaseStart = false;
        childNote.preBendReleaseEndIndex = null;
      }
    });
  }

  // Helper: Get the endIndex from existing childNotes with bends
  int? _getExistingBendEndIndex(MusicalNote chord) {
    if (chord.childNotes == null) return null;

    for (var childNote in chord.childNotes!) {
      if (childNote.isBendStart && childNote.bendEndIndex != null) {
        return childNote.bendEndIndex;
      }
      if (childNote.isPreBendStart && childNote.preBendEndIndex != null) {
        return childNote.preBendEndIndex;
      }
      if (childNote.isBendReleaseStart &&
          childNote.bendReleaseEndIndex != null) {
        return childNote.bendReleaseEndIndex;
      }
      if (childNote.isPreBendReleaseStart &&
          childNote.preBendReleaseEndIndex != null) {
        return childNote.preBendReleaseEndIndex;
      }
    }
    return null;
  }

  // Helper: Update all childNotes to have the same bend type
  void _updateAllChildNotesToSameBendType(
      MusicalNote chord, String newBendType, int existingEndIndex) {
    if (chord.childNotes == null) return;

    for (var childNote in chord.childNotes!) {
      // Convert any existing bend type to the new bend type
      if (childNote.isBendStart && newBendType != 'bend') {
        // Convert bend to new type
        childNote.isBendStart = false;
        childNote.bendEndIndex = null;

        switch (newBendType) {
          case 'pre-bend':
            childNote.isPreBendStart = true;
            childNote.preBendEndIndex = existingEndIndex;
            break;
          case 'bend-release':
            childNote.isBendReleaseStart = true;
            childNote.bendReleaseEndIndex = existingEndIndex;
            break;
          case 'pre-bend-release':
            childNote.isPreBendReleaseStart = true;
            childNote.preBendReleaseEndIndex = existingEndIndex;
            break;
        }
      } else if (childNote.isPreBendStart && newBendType != 'pre-bend') {
        // Convert pre-bend to new type
        childNote.isPreBendStart = false;
        childNote.preBendEndIndex = null;

        switch (newBendType) {
          case 'bend':
            childNote.isBendStart = true;
            childNote.bendEndIndex = existingEndIndex;
            break;
          case 'bend-release':
            childNote.isBendReleaseStart = true;
            childNote.bendReleaseEndIndex = existingEndIndex;
            break;
          case 'pre-bend-release':
            childNote.isPreBendReleaseStart = true;
            childNote.preBendReleaseEndIndex = existingEndIndex;
            break;
        }
      } else if (childNote.isBendReleaseStart &&
          newBendType != 'bend-release') {
        // Convert bend-release to new type
        childNote.isBendReleaseStart = false;
        childNote.bendReleaseEndIndex = null;

        switch (newBendType) {
          case 'bend':
            childNote.isBendStart = true;
            childNote.bendEndIndex = existingEndIndex;
            break;
          case 'pre-bend':
            childNote.isPreBendStart = true;
            childNote.preBendEndIndex = existingEndIndex;
            break;
          case 'pre-bend-release':
            childNote.isPreBendReleaseStart = true;
            childNote.preBendReleaseEndIndex = existingEndIndex;
            break;
        }
      } else if (childNote.isPreBendReleaseStart &&
          newBendType != 'pre-bend-release') {
        // Convert pre-bend-release to new type
        childNote.isPreBendReleaseStart = false;
        childNote.preBendReleaseEndIndex = null;

        switch (newBendType) {
          case 'bend':
            childNote.isBendStart = true;
            childNote.bendEndIndex = existingEndIndex;
            break;
          case 'pre-bend':
            childNote.isPreBendStart = true;
            childNote.preBendEndIndex = existingEndIndex;
            break;
          case 'bend-release':
            childNote.isBendReleaseStart = true;
            childNote.bendReleaseEndIndex = existingEndIndex;
            break;
        }
      }
    }
  }

  // Helper: Handle technique button press (mute, pinch-harmonic, harmonic, tap-right-hand)
  void _handleTechniqueButtonPress(
      String techniqueType, int selectedRow, int selectedNoteIndex) {
    final chord = _getCurrentChord(selectedRow, selectedNoteIndex);
    if (chord == null) return;

    setState(() {
      // Determine current state for this technique type
      bool isCurrentlyActive = false;
      bool isCurrentlyLocked = false;

      switch (techniqueType) {
        case 'mute':
          isCurrentlyActive = _isMuteActive;
          isCurrentlyLocked = _isMuteLocked;
          break;
        case 'pinch-harmonic':
          isCurrentlyActive = _isPinchHarmonicActive;
          isCurrentlyLocked = _isPinchHarmonicLocked;
          break;
        case 'harmonic':
          isCurrentlyActive = _isHarmonicActive;
          isCurrentlyLocked = _isHarmonicLocked;
          break;
        case 'tap-right-hand':
          isCurrentlyActive = _isTapRightHandActive;
          isCurrentlyLocked = false;
          break;
        case 'vibrato':
          isCurrentlyActive = _isVibratoActive;
          isCurrentlyLocked = _isVibratoLocked;
          break;
      }

      // Three-tap behavior logic
      if (!isCurrentlyActive) {
        // First tap: set note to active and enter lock state
        switch (techniqueType) {
          case 'mute':
            _isMuteActive = true;
            _isMuteLocked = true;
            chord.isMuteStart = true;
            chord.muteEndIndex = selectedNoteIndex - 1;
            break;
          case 'pinch-harmonic':
            _isPinchHarmonicActive = true;
            _isPinchHarmonicLocked = true;
            chord.isPinchHarmonicStart = true;
            chord.pinchHarmonicEndIndex = selectedNoteIndex - 1;
            break;
          case 'harmonic':
            _isHarmonicActive = true;
            _isHarmonicLocked = true;
            chord.isHarmonicStart = true;
            chord.harmonicEndIndex = selectedNoteIndex - 1;
            break;
          case 'tap-right-hand':
            _isTapRightHandActive = !_isTapRightHandActive;
            chord.tapRightHandCharacter = chord.tapRightHandCharacter =
                '\uEA8B'; // Unicode for tap-right-hand
            break;
          case 'vibrato':
            _isVibratoActive = true;
            _isVibratoLocked = true;
            chord.isVibratoStart = true;
            chord.vibratoEndIndex = selectedNoteIndex - 1;
            break;
        }
      } else if (isCurrentlyActive && isCurrentlyLocked) {
        // Second tap: switch to active state without lock state
        switch (techniqueType) {
          case 'mute':
            _isMuteLocked = false;
            break;
          case 'pinch-harmonic':
            _isPinchHarmonicLocked = false;
            break;
          case 'harmonic':
            _isHarmonicLocked = false;
            break;
        }
      } else {
        // Third tap: switch active state off and remove technique from note
        switch (techniqueType) {
          case 'mute':
            _isMuteActive = false;
            _isMuteLocked = false;
            chord.isMuteStart = false;
            chord.muteEndIndex = null;
            break;
          case 'pinch-harmonic':
            _isPinchHarmonicActive = false;
            _isPinchHarmonicLocked = false;
            chord.isPinchHarmonicStart = false;
            chord.pinchHarmonicEndIndex = null;
            break;
          case 'harmonic':
            _isHarmonicActive = false;
            _isHarmonicLocked = false;
            chord.isHarmonicStart = false;
            chord.harmonicEndIndex = null;
            break;
          case 'tap-right-hand':
            _isTapRightHandActive = false;
            chord.tapRightHandCharacter = '';
            break;
        }
      }

      if (techniqueType != 'mute') {
        _isMuteActive = false;
        _isMuteLocked = false;
        chord.isMuteStart = false;
        chord.muteEndIndex = null;
      }
      if (techniqueType != 'pinch-harmonic') {
        _isPinchHarmonicActive = false;
        _isPinchHarmonicLocked = false;
        chord.isPinchHarmonicStart = false;
        chord.pinchHarmonicEndIndex = null;
      }
      if (techniqueType != 'harmonic') {
        _isHarmonicActive = false;
        _isHarmonicLocked = false;
        chord.isHarmonicStart = false;
        chord.harmonicEndIndex = null;
      }
    });
  }

  // Helper: Check if current chord has technique start property set
  bool _checkIfCurrentChordHasTechnique(
      String techniqueType, int selectedRow, int selectedNoteIndex) {
    final chord = _getCurrentChord(selectedRow, selectedNoteIndex);
    if (chord == null) return false;

    switch (techniqueType) {
      case 'mute':
        return chord.isMuteStart;
      case 'pinch-harmonic':
        return chord.isPinchHarmonicStart;
      case 'harmonic':
        return chord.isHarmonicStart;
      case 'vibrato':
        return chord.isVibratoStart;
      default:
        return false;
    }
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
            _updateBendOnlyStatesForCurrentString(
                Provider.of<CurrentSelectedNoteProvider>(context, listen: false)
                    .selectedRow,
                Provider.of<CurrentSelectedNoteProvider>(context, listen: false)
                    .selectedIndex);
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
                  final chords = widget.sheetNoteRows[selectedRow].chords;
                  final bool isLastNoteInRow =
                      selectedNoteIndex >= chords.length - 1;

                  if (isLastNoteInRow) {
                    if (_isBendActive ||
                        _isPreBendActive ||
                        _isBendReleaseActive ||
                        _isPreBendReleaseActive) {
                      for (int i = selectedNoteIndex; i >= 0; i--) {
                        final chord = chords[i];
                        if (chord.childNotes == null) continue;

                        for (var childNote in chord.childNotes!) {
                          if (_isBendActive &&
                              childNote.isBendStart &&
                              childNote.bendEndIndex != null &&
                              ((i <= selectedNoteIndex &&
                                      selectedNoteIndex - 1 <=
                                          childNote.bendEndIndex!) ||
                                  (childNote.bendEndIndex == i - 1))) {
                            childNote.bendEndIndex =
                                childNote.bendEndIndex! + 1;
                          }
                          if (_isPreBendActive &&
                              childNote.isPreBendStart &&
                              childNote.preBendEndIndex != null &&
                              ((i <= selectedNoteIndex &&
                                      selectedNoteIndex - 1 <=
                                          childNote.preBendEndIndex!) ||
                                  (childNote.preBendEndIndex == i - 1))) {
                            childNote.preBendEndIndex =
                                childNote.preBendEndIndex! + 1;
                          }
                          if (_isBendReleaseActive &&
                              childNote.isBendReleaseStart &&
                              childNote.bendReleaseEndIndex != null &&
                              ((i <= selectedNoteIndex &&
                                      selectedNoteIndex - 1 <=
                                          childNote.bendReleaseEndIndex!) ||
                                  (childNote.bendReleaseEndIndex == i - 1))) {
                            childNote.bendReleaseEndIndex =
                                childNote.bendReleaseEndIndex! + 1;
                          }
                          if (_isPreBendReleaseActive &&
                              childNote.isPreBendReleaseStart &&
                              childNote.preBendReleaseEndIndex != null &&
                              ((i <= selectedNoteIndex &&
                                      selectedNoteIndex - 1 <=
                                          childNote.preBendReleaseEndIndex!) ||
                                  (childNote.preBendReleaseEndIndex ==
                                      i - 1))) {
                            childNote.preBendReleaseEndIndex =
                                childNote.preBendReleaseEndIndex! + 1;
                          }
                        }
                      }
                    }

                    // Update technique end indices if in locked mode
                    if (_isMuteLocked ||
                        _isPinchHarmonicLocked ||
                        _isHarmonicLocked ||
                        _isVibratoLocked) {
                      // Find the chord that has the active technique with lock
                      MusicalNote? activeChord;
                      String? activeTechniqueType;

                      for (int i = selectedNoteIndex; i >= 0; i--) {
                        final chord = chords[i];

                        if (_isMuteLocked &&
                            chord.isMuteStart &&
                            chord.muteEndIndex != null) {
                          activeChord = chord;
                          activeTechniqueType = 'mute';
                          break;
                        }
                        if (_isPinchHarmonicLocked &&
                            chord.isPinchHarmonicStart &&
                            chord.pinchHarmonicEndIndex != null) {
                          activeChord = chord;
                          activeTechniqueType = 'pinch-harmonic';
                          break;
                        }
                        if (_isHarmonicLocked &&
                            chord.isHarmonicStart &&
                            chord.harmonicEndIndex != null) {
                          activeChord = chord;
                          activeTechniqueType = 'harmonic';
                          break;
                        }
                        if (_isVibratoLocked &&
                            chord.isVibratoStart &&
                            chord.vibratoEndIndex != null) {
                          activeChord = chord;
                          activeTechniqueType = 'vibrato';
                          break;
                        }
                      }

                      // Update the endIndex for the active technique
                      if (activeChord != null && activeTechniqueType != null) {
                        switch (activeTechniqueType) {
                          case 'mute':
                            activeChord.muteEndIndex =
                                activeChord.muteEndIndex! + 1;
                            break;
                          case 'pinch-harmonic':
                            activeChord.pinchHarmonicEndIndex =
                                activeChord.pinchHarmonicEndIndex! + 1;
                            break;
                          case 'harmonic':
                            activeChord.harmonicEndIndex =
                                activeChord.harmonicEndIndex! + 1;
                            break;
                          case 'vibrato':
                            activeChord.vibratoEndIndex =
                                activeChord.vibratoEndIndex! + 1;
                            break;
                        }
                      }
                    }

                    int nextIndex = selectedNoteIndex + 1;

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
                    // Not at the end of the row: just navigate to the next note
                    currentSelectedNoteProvider
                        .updateSelectedIndexAndInsertionPoint(
                            selectedRow, selectedNoteIndex + 1);
                  }
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
              _isMuteActive = false;
              _isPinchHarmonicActive = false;
              _isHarmonicActive = false;
              _isVibratoActive = false;
              _isVibratoLocked = false;
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
                    widget.onKeyPress(MusicalNote(
                      pitch: "D",
                      octave: 5,
                      type: NoteType.clef,
                      isBeamed: false,
                      unicodeCharacter: "\uF40C",
                      clefType: "Tab",
                    ));
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
                      _buildTechniqueButton('mute', 'P.M.',
                          fontSize: 12,
                          isUnicode: false,
                          onPressed: () => _handleTechniqueButtonPress(
                              'mute', selectedRow, selectedNoteIndex),
                          isActive: _isMuteActive ||
                              _checkIfCurrentChordHasTechnique(
                                  'mute', selectedRow, selectedNoteIndex),
                          isLocked: _isMuteLocked),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('pinch-harmonic', 'P.H.',
                          fontSize: 12,
                          isUnicode: false,
                          onPressed: () => _handleTechniqueButtonPress(
                              'pinch-harmonic', selectedRow, selectedNoteIndex),
                          isActive: _isPinchHarmonicActive ||
                              _checkIfCurrentChordHasTechnique('pinch-harmonic',
                                  selectedRow, selectedNoteIndex),
                          isLocked: _isPinchHarmonicLocked),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('vibrato', '\uE56E',
                          fontSize: 20,
                          offset: Offset(0, 3),
                          onPressed: () => _handleTechniqueButtonPress(
                              'vibrato', selectedRow, selectedNoteIndex),
                          isActive: _isVibratoActive ||
                              _checkIfCurrentChordHasTechnique(
                                  'vibrato', selectedRow, selectedNoteIndex),
                          isLocked: _isVibratoLocked),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('hammer-left-hand', '\uE4BA',
                          fontSize: 38, offset: Offset(0, -8)),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('bend', 'bend',
                          svgAssetPath: 'assets/svgs/bend.svg',
                          onPressed: () => _handleBendButtonPress(
                              'bend', selectedRow, selectedNoteIndex),
                          isActive: _isBendActive ||
                              _checkIfCurrentChordHasBend(
                                  'bend', selectedRow, selectedNoteIndex),
                          isLocked: _isBendLocked),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('pre-bend', 'pre-bend',
                          svgAssetPath: 'assets/svgs/pre-bend.svg',
                          onPressed: () => _handleBendButtonPress(
                              'pre-bend', selectedRow, selectedNoteIndex),
                          isActive: _isPreBendActive ||
                              _checkIfCurrentChordHasBend(
                                  'pre-bend', selectedRow, selectedNoteIndex),
                          isLocked: _isPreBendLocked),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('pick-downward', '\uE610',
                          fontSize: 30),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Second technique row with 7 buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTechniqueButton('tap-right-hand', '\uEA8B',
                          fontSize: 16,
                          offset: Offset(0, 7),
                          onPressed: () => _handleTechniqueButtonPress(
                              'tap-right-hand', selectedRow, selectedNoteIndex),
                          isActive: _isTapRightHandActive,
                          isLocked: false),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('harmonic', 'Ham.',
                          fontSize: 12,
                          isUnicode: false,
                          onPressed: () => _handleTechniqueButtonPress(
                              'harmonic', selectedRow, selectedNoteIndex),
                          isActive: _isHarmonicActive ||
                              _checkIfCurrentChordHasTechnique(
                                  'harmonic', selectedRow, selectedNoteIndex),
                          isLocked: _isHarmonicLocked),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('slide-up', '\uEA6D',
                          fontSize: 40, offset: Offset(0, -7)),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('slide-down', '\uEA6E',
                          fontSize: 40, offset: Offset(0, -7)),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('bend-release', 'bend-release',
                          svgAssetPath: 'assets/svgs/bend-release.svg',
                          onPressed: () => _handleBendButtonPress(
                              'bend-release', selectedRow, selectedNoteIndex),
                          isActive: _isBendReleaseActive ||
                              _checkIfCurrentChordHasBend('bend-release',
                                  selectedRow, selectedNoteIndex),
                          isLocked: _isBendReleaseLocked),
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
                          isLocked: _isPreBendReleaseLocked),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('pick-upward', '\uE612',
                          fontSize: 30),
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
