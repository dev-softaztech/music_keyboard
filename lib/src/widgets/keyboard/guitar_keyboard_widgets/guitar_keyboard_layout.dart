import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/providers/selected_string_provider.dart';
import 'package:provider/provider.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/guitar_tab_helpers.dart';
import 'guitar_technique_buttons.dart';
import 'guitar_fret_string_buttons.dart';
import 'guitar_favourites_panel.dart';

class GuitarKeyboardLayout extends StatefulWidget {
  final bool showNotesKeyboard;
  final void Function(bool) onToggleKeyboard;
  final bool Function(MusicalNote) onKeyPress;
  final List<SheetRows> sheetNoteRows;
  final SheetFormat sheetFormat;
  final void Function(VoidCallback spaceHandler)? onRegisterSpaceHandler;
  final void Function(VoidCallback resetHandler)? onRegisterResetHandler;
  final VoidCallback? onNewRowCreated;

  final Future<List<({int id, MusicalNote chord})>> Function()? loadFavourites;
  final void Function(MusicalNote chord)? onFavouriteChordTapped;
  final Future<void> Function(int id)? onFavouriteChordUsed;

  final int favouritesVersion;

  const GuitarKeyboardLayout({
    super.key,
    required this.showNotesKeyboard,
    required this.onToggleKeyboard,
    required this.onKeyPress,
    required this.sheetNoteRows,
    required this.sheetFormat,
    this.onRegisterSpaceHandler,
    this.onNewRowCreated,
    this.onRegisterResetHandler,
    this.loadFavourites,
    this.onFavouriteChordTapped,
    this.onFavouriteChordUsed,
    this.favouritesVersion = 0,
  });

  @override
  State<GuitarKeyboardLayout> createState() => _GuitarKeyboardLayoutState();
}

class _GuitarKeyboardLayoutState extends State<GuitarKeyboardLayout> {
  OverlayEntry? _overlayEntry;

  bool showLowerPair = false;

  bool _isBendActive = false;
  bool _isPreBendActive = false;
  bool _isBendReleaseActive = false;
  bool _isPreBendReleaseActive = false;
  bool _isMuteActive = false;
  bool _isPinchHarmonicActive = false;
  bool _isHarmonicActive = false;
  bool _isVibratoActive = false;
  bool _isTapRightHandActive = false;
  bool _isPickUpwardActive = false;
  bool _isPickDownwardActive = false;
  bool _isHammerLeftHandActive = false;
  bool _isSlideUpActive = false;
  bool _isSlideDownActive = false;

  bool _isBendLocked = false;
  bool _isPreBendLocked = false;
  bool _isBendReleaseLocked = false;
  bool _isPreBendReleaseLocked = false;
  bool _isMuteLocked = false;
  bool _isPinchHarmonicLocked = false;
  bool _isHarmonicLocked = false;
  bool _isVibratoLocked = false;
  bool _isHammerLeftHandLocked = false;

  bool _isChordsActive = false;

  bool _isFavouritesActive = false;
  bool _favouritesLoading = false;
  List<({int id, MusicalNote chord})> _favouriteChords = [];

  int _previousSelectedRow = -1;
  int _previousSelectedIndex = -1;

  bool _navigatedViaNextButton = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onRegisterSpaceHandler?.call(_handleSpacePress);
      widget.onRegisterResetHandler?.call(resetTechniqueStates);
    });
  }

  @override
  void didUpdateWidget(GuitarKeyboardLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.favouritesVersion != oldWidget.favouritesVersion &&
        _isFavouritesActive) {
      _reloadFavourites();
    }
  }

  Future<void> _reloadFavourites() async {
    setState(() => _favouritesLoading = true);
    final favs = widget.loadFavourites != null
        ? await widget.loadFavourites!()
        : <({int id, MusicalNote chord})>[];
    if (mounted) {
      setState(() {
        _favouriteChords = favs;
        _favouritesLoading = false;
      });
    }
  }

  @override
  void dispose() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    super.dispose();
  }

  void resetTechniqueStates() {
    setState(() {
      _isBendActive = false;
      _isPreBendActive = false;
      _isBendReleaseActive = false;
      _isPreBendReleaseActive = false;
      _isMuteActive = false;
      _isPinchHarmonicActive = false;
      _isHarmonicActive = false;
      _isVibratoActive = false;
      _isTapRightHandActive = false;
      _isPickUpwardActive = false;
      _isPickDownwardActive = false;
      _isHammerLeftHandActive = false;
      _isSlideUpActive = false;
      _isSlideDownActive = false;

      _isBendLocked = false;
      _isPreBendLocked = false;
      _isBendReleaseLocked = false;
      _isPreBendReleaseLocked = false;
      _isMuteLocked = false;
      _isPinchHarmonicLocked = false;
      _isHarmonicLocked = false;
      _isVibratoLocked = false;
      _isHammerLeftHandLocked = false;
    });
  }

  void _handleSpacePress() {
    if (!mounted) return;

    final currentSelectedNoteProvider =
        Provider.of<CurrentSelectedNoteProvider>(context, listen: false);
    final selectedRow = currentSelectedNoteProvider.selectedRow;
    final selectedNoteIndex = currentSelectedNoteProvider.selectedIndex;

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

    setState(() {
      _navigatedViaNextButton = true;
    });

    _updateTechniqueIndicesForNewNote(selectedRow, selectedNoteIndex);

    widget.onKeyPress(MusicalNote(
      pitch: 'G',
      octave: 4,
      type: NoteType.fret,
      duration: 0.0,
      childNotes: [],
    ));
  }

  void _updateTechniqueIndicesForNewNote(
      int selectedRow, int selectedNoteIndex) {
    final chords = widget.sheetNoteRows[selectedRow].chords;

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
                      selectedNoteIndex - 1 <= childNote.bendEndIndex!) ||
                  (childNote.bendEndIndex == i - 1))) {
            childNote.bendEndIndex = childNote.bendEndIndex! + 1;
          }
          if (_isPreBendActive &&
              childNote.isPreBendStart &&
              childNote.preBendEndIndex != null &&
              ((i <= selectedNoteIndex &&
                      selectedNoteIndex - 1 <= childNote.preBendEndIndex!) ||
                  (childNote.preBendEndIndex == i - 1))) {
            childNote.preBendEndIndex = childNote.preBendEndIndex! + 1;
          }
          if (_isBendReleaseActive &&
              childNote.isBendReleaseStart &&
              childNote.bendReleaseEndIndex != null &&
              ((i <= selectedNoteIndex &&
                      selectedNoteIndex - 1 <=
                          childNote.bendReleaseEndIndex!) ||
                  (childNote.bendReleaseEndIndex == i - 1))) {
            childNote.bendReleaseEndIndex = childNote.bendReleaseEndIndex! + 1;
          }
          if (_isPreBendReleaseActive &&
              childNote.isPreBendReleaseStart &&
              childNote.preBendReleaseEndIndex != null &&
              ((i <= selectedNoteIndex &&
                      selectedNoteIndex - 1 <=
                          childNote.preBendReleaseEndIndex!) ||
                  (childNote.preBendReleaseEndIndex == i - 1))) {
            childNote.preBendReleaseEndIndex =
                childNote.preBendReleaseEndIndex! + 1;
          }
        }
      }
    }

    if (_isHammerLeftHandLocked) {
      for (int i = selectedNoteIndex; i >= 0; i--) {
        final chord = chords[i];
        if (chord.childNotes == null) continue;

        for (var childNote in chord.childNotes!) {
          if (childNote.isHammerLeftHandStart &&
              childNote.hammerLeftHandEndIndex != null &&
              ((i <= selectedNoteIndex &&
                      selectedNoteIndex <= childNote.hammerLeftHandEndIndex!) ||
                  (childNote.hammerLeftHandEndIndex == i))) {
            childNote.hammerLeftHandEndIndex =
                childNote.hammerLeftHandEndIndex! + 1;
          }
        }
      }
    }

    if (_isMuteLocked ||
        _isPinchHarmonicLocked ||
        _isHarmonicLocked ||
        _isVibratoLocked) {
      MusicalNote? activeChord;
      List<String> activeTechniqueTypes = [];

      for (int i = selectedNoteIndex; i >= 0; i--) {
        final chord = chords[i];
        bool found = false;

        if (_isMuteLocked && chord.isMuteStart && chord.muteEndIndex != null) {
          activeChord = chord;
          activeTechniqueTypes.add('mute');
          found = true;
        }
        if (_isPinchHarmonicLocked &&
            chord.isPinchHarmonicStart &&
            chord.pinchHarmonicEndIndex != null) {
          activeChord = chord;
          activeTechniqueTypes.add('pinch-harmonic');
          found = true;
        }
        if (_isHarmonicLocked &&
            chord.isHarmonicStart &&
            chord.harmonicEndIndex != null) {
          activeChord = chord;
          activeTechniqueTypes.add('harmonic');
          found = true;
        }
        if (_isVibratoLocked &&
            chord.isVibratoStart &&
            chord.vibratoEndIndex != null) {
          activeChord = chord;
          activeTechniqueTypes.add('vibrato');
          found = true;
        }
        if (found) break;
      }

      if (activeChord != null && activeTechniqueTypes.isNotEmpty) {
        for (var type in activeTechniqueTypes) {
          if (type == 'mute') {
            activeChord.muteEndIndex = activeChord.muteEndIndex! + 1;
          }
          if (type == 'pinch-harmonic') {
            activeChord.pinchHarmonicEndIndex =
                activeChord.pinchHarmonicEndIndex! + 1;
          }
          if (type == 'harmonic') {
            activeChord.harmonicEndIndex = activeChord.harmonicEndIndex! + 1;
          }
          if (type == 'vibrato') {
            activeChord.vibratoEndIndex = activeChord.vibratoEndIndex! + 1;
          }
        }
      }
    }
  }

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

  String? _getFretForString(MusicalNote? chord, int stringIndex) {
    if (chord?.childNotes == null) return null;

    for (var childNote in chord!.childNotes!) {
      if (childNote.octave == stringIndex) {
        return childNote.unicodeCharacter;
      }
    }
    return null;
  }

  MusicalNote _updateFretForString(
      int selectedRow, int selectedNoteIndex, int stringIndex, int fretNumber,
      {bool goToNextString = true}) {
    return GuitarTabHelpers.updateFretForString(
      widget.sheetNoteRows,
      selectedRow,
      selectedNoteIndex,
      stringIndex,
      fretNumber,
      goToNextString: goToNextString,
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

    final selectedStringProvider =
        Provider.of<SelectedStringProvider>(context, listen: false);
    final selectedStringIndex = selectedStringProvider.selectedStringIndex;

    MusicalNote? childNote;
    for (var child in chord.childNotes!) {
      if (child.octave == selectedStringIndex) {
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

  bool _checkIfCurrentChordHasBend(
      String bendType, int selectedRow, int selectedNoteIndex) {
    final chord = _getCurrentChord(selectedRow, selectedNoteIndex);
    if (chord == null || chord.childNotes == null) return false;

    final selectedStringProvider =
        Provider.of<SelectedStringProvider>(context, listen: false);
    final selectedStringIndex = selectedStringProvider.selectedStringIndex;

    MusicalNote? childNote;
    for (var child in chord.childNotes!) {
      if (child.octave == selectedStringIndex) {
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

  void _handleBendButtonPress(
      String bendType, int selectedRow, int selectedNoteIndex) {
    final chord = _getCurrentChord(selectedRow, selectedNoteIndex);
    if (chord == null) return;

    chord.childNotes ??= [];

    final selectedStringProvider =
        Provider.of<SelectedStringProvider>(context, listen: false);
    final selectedStringIndex = selectedStringProvider.selectedStringIndex;

    MusicalNote? childNote;
    for (var child in chord.childNotes!) {
      if (child.octave == selectedStringIndex) {
        childNote = child;
        break;
      }
    }

    childNote ??= _updateFretForString(
        selectedRow, selectedNoteIndex, selectedStringIndex, 0,
        goToNextString: false);

    setState(() {
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

      if (!isCurrentlyActive) {
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

  void _updateAllChildNotesToSameBendType(
      MusicalNote chord, String newBendType, int existingEndIndex) {
    if (chord.childNotes == null) return;

    for (var childNote in chord.childNotes!) {
      if (childNote.isBendStart && newBendType != 'bend') {
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

  bool _checkIfCurrentChildNoteHasHammerLeftHand(
      int selectedRow, int selectedNoteIndex) {
    final chord = _getCurrentChord(selectedRow, selectedNoteIndex);
    if (chord == null || chord.childNotes == null) return false;

    final selectedStringProvider =
        Provider.of<SelectedStringProvider>(context, listen: false);
    final selectedStringIndex = selectedStringProvider.selectedStringIndex;

    for (var child in chord.childNotes!) {
      if (child.octave == selectedStringIndex) {
        return child.isHammerLeftHandStart;
      }
    }
    return false;
  }

  void _handleHammerLeftHandButtonPress(
      int selectedRow, int selectedNoteIndex) {
    final chord = _getCurrentChord(selectedRow, selectedNoteIndex);
    if (chord == null) return;

    chord.childNotes ??= [];

    final selectedStringProvider =
        Provider.of<SelectedStringProvider>(context, listen: false);
    final selectedStringIndex = selectedStringProvider.selectedStringIndex;

    MusicalNote? childNote;
    for (var child in chord.childNotes!) {
      if (child.octave == selectedStringIndex) {
        childNote = child;
        break;
      }
    }

    childNote ??= _updateFretForString(
        selectedRow, selectedNoteIndex, selectedStringIndex, 0,
        goToNextString: false);

    setState(() {
      bool isCurrentlyActive = _isHammerLeftHandActive;
      bool isCurrentlyLocked = _isHammerLeftHandLocked;

      if (!isCurrentlyActive) {
        _isHammerLeftHandActive = true;
        _isHammerLeftHandLocked = true;
        childNote!.isHammerLeftHandStart = true;
        childNote.hammerLeftHandEndIndex = selectedNoteIndex;
      } else if (isCurrentlyActive && isCurrentlyLocked) {
        _isHammerLeftHandLocked = false;
      } else {
        _isHammerLeftHandActive = false;
        _isHammerLeftHandLocked = false;
        childNote!.isHammerLeftHandStart = false;
        childNote.hammerLeftHandEndIndex = null;
      }
    });
  }

  void _handleTechniqueButtonPress(
      String techniqueType, int selectedRow, int selectedNoteIndex) {
    final chord = _getCurrentChord(selectedRow, selectedNoteIndex);
    if (chord == null) return;

    setState(() {
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
        case 'pick-downward':
          isCurrentlyActive = _isPickDownwardActive;
          isCurrentlyLocked = false;
          break;
        case 'pick-upward':
          isCurrentlyActive = _isPickUpwardActive;
          isCurrentlyLocked = false;
          break;
        case 'vibrato':
          isCurrentlyActive = _isVibratoActive;
          isCurrentlyLocked = _isVibratoLocked;
          break;
      }

      if (!isCurrentlyActive) {
        if (techniqueType == 'mute' ||
            techniqueType == 'pinch-harmonic' ||
            techniqueType == 'harmonic') {
          _resetOtherTechniqueProperties(chord, techniqueType);
        }

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
          case 'pick-downward':
            _isPickDownwardActive = !_isPickDownwardActive;
            chord.hasPickDownward = _isPickDownwardActive;
            // If pick-downward is now active, ensure pick-upward is inactive
            if (_isPickDownwardActive) {
              _isPickUpwardActive = false;
              chord.hasPickUpward = false;
            }
            break;
          case 'pick-upward':
            _isPickUpwardActive = !_isPickUpwardActive;
            chord.hasPickUpward = _isPickUpwardActive;
            // If pick-upward is now active, ensure pick-downward is inactive
            if (_isPickUpwardActive) {
              _isPickDownwardActive = false;
              chord.hasPickDownward = false;
            }
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
          case 'vibrato':
            _isVibratoLocked = false;
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
          case 'pick-downward':
            _isPickDownwardActive = false;
            chord.hasPickDownward = false;
            break;
          case 'pick-upward':
            _isPickUpwardActive = false;
            chord.hasPickUpward = false;
            break;
          case 'vibrato':
            _isVibratoActive = false;
            _isVibratoLocked = false;
            chord.isVibratoStart = false;
            chord.vibratoEndIndex = null;
            break;
        }

        if (techniqueType == 'pick-downward' ||
            techniqueType == 'pick-upward') {
          if (techniqueType == 'pick-downward') {
            _isPickUpwardActive = false;
            chord.hasPickUpward = false;
          } else {
            _isPickDownwardActive = false;
            chord.hasPickDownward = false;
          }
        }
      }
    });
  }

  void _resetOtherTechniqueProperties(
      MusicalNote chord, String activeTechnique) {
    chord.isMuteStart = false;
    chord.muteEndIndex = null;
    chord.isPinchHarmonicStart = false;
    chord.pinchHarmonicEndIndex = null;
    chord.isHarmonicStart = false;
    chord.harmonicEndIndex = null;

    _isMuteActive = false;
    _isMuteLocked = false;
    _isPinchHarmonicActive = false;
    _isPinchHarmonicLocked = false;
    _isHarmonicActive = false;
    _isHarmonicLocked = false;
  }

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

  bool _checkIfCurrentChildNoteHasSlide(
      String slideType, int selectedRow, int selectedNoteIndex) {
    final chord = _getCurrentChord(selectedRow, selectedNoteIndex);
    if (chord == null || chord.childNotes == null) return false;

    final selectedStringProvider =
        Provider.of<SelectedStringProvider>(context, listen: false);
    final selectedStringIndex = selectedStringProvider.selectedStringIndex;

    for (var child in chord.childNotes!) {
      if (child.octave == selectedStringIndex) {
        if (slideType == 'slide-up') return child.hasSlideUp;
        if (slideType == 'slide-down') return child.hasSlideDown;
      }
    }
    return false;
  }

  void _handleSlideButtonPress(
      String slideType, int selectedRow, int selectedNoteIndex) {
    final chord = _getCurrentChord(selectedRow, selectedNoteIndex);
    if (chord == null) return;

    chord.childNotes ??= [];

    final selectedStringProvider =
        Provider.of<SelectedStringProvider>(context, listen: false);
    final selectedStringIndex = selectedStringProvider.selectedStringIndex;

    MusicalNote? childNote;
    for (var child in chord.childNotes!) {
      if (child.octave == selectedStringIndex) {
        childNote = child;
        break;
      }
    }

    childNote ??= _updateFretForString(
        selectedRow, selectedNoteIndex, selectedStringIndex, 0,
        goToNextString: false);

    setState(() {
      if (slideType == 'slide-up') {
        childNote!.hasSlideUp = !childNote.hasSlideUp;
        if (childNote.hasSlideUp) {
          childNote.hasSlideDown = false;
        }
        _isSlideUpActive = childNote.hasSlideUp;
        _isSlideDownActive = false;
      } else if (slideType == 'slide-down') {
        childNote!.hasSlideDown = !childNote.hasSlideDown;
        if (childNote.hasSlideDown) {
          childNote.hasSlideUp = false;
        }
        _isSlideDownActive = childNote.hasSlideDown;
        _isSlideUpActive = false;
      }
    });
  }

  Future<void> _toggleFavourites() async {
    if (_isFavouritesActive) {
      setState(() => _isFavouritesActive = false);
      return;
    }
    setState(() => _favouritesLoading = true);
    final favs = widget.loadFavourites != null
        ? await widget.loadFavourites!()
        : <({int id, MusicalNote chord})>[];
    if (mounted) {
      setState(() {
        _favouriteChords = favs;
        _isFavouritesActive = true;
        _favouritesLoading = false;
      });
    }
  }

  void _onFretPressed(int fretNumber, int selectedRow, int selectedNoteIndex) {
    final selectedStringProvider =
        Provider.of<SelectedStringProvider>(context, listen: false);
    final selectedStringIndex = selectedStringProvider.selectedStringIndex;

    if (_isChordsActive) {
      setState(() {
        _updateFretForString(
            selectedRow, selectedNoteIndex, selectedStringIndex, fretNumber);
      });
    } else {
      if (widget.sheetNoteRows.isNotEmpty &&
          selectedRow >= 0 &&
          selectedRow < widget.sheetNoteRows.length &&
          selectedNoteIndex >= 0) {
        setState(() {
          _navigatedViaNextButton = true;
        });
        _updateTechniqueIndicesForNewNote(selectedRow, selectedNoteIndex);
      }
      widget.onKeyPress(MusicalNote(
        pitch: 'G',
        octave: 4,
        type: NoteType.fret,
        duration: 0.0,
        childNotes: [
          MusicalNote(
            pitch: 'G',
            octave: selectedStringIndex,
            type: NoteType.fret,
            unicodeCharacter: fretNumber.toString(),
            duration: 0.0,
          ),
        ],
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSelectedNoteProvider =
        Provider.of<CurrentSelectedNoteProvider>(context);
    final selectedNoteIndex = currentSelectedNoteProvider.selectedIndex;
    final selectedRow = currentSelectedNoteProvider.selectedRow;

    if (_previousSelectedRow != selectedRow ||
        _previousSelectedIndex != selectedNoteIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            final currentChord =
                _getCurrentChord(selectedRow, selectedNoteIndex);

            _isPickUpwardActive = currentChord?.hasPickUpward ?? false;
            _isPickDownwardActive = currentChord?.hasPickDownward ?? false;

            _isTapRightHandActive =
                currentChord?.tapRightHandCharacter == '\uEA8B';

            if (currentChord != null && currentChord.childNotes != null) {
              final selectedStringProvider =
                  Provider.of<SelectedStringProvider>(context, listen: false);
              final selectedStringIndex =
                  selectedStringProvider.selectedStringIndex;

              for (var childNote in currentChord.childNotes!) {
                if (childNote.octave == selectedStringIndex) {
                  _isSlideUpActive = childNote.hasSlideUp;
                  _isSlideDownActive = childNote.hasSlideDown;
                  _isHammerLeftHandActive = childNote.isHammerLeftHandStart;
                  break;
                }
              }
            } else {
              _isSlideUpActive = false;
              _isSlideDownActive = false;
              _isHammerLeftHandActive = false;
            }

            if (!_navigatedViaNextButton) {
              _isBendActive = false;
              _isPreBendActive = false;
              _isBendReleaseActive = false;
              _isPreBendReleaseActive = false;
              _isMuteActive = false;
              _isPinchHarmonicActive = false;
              _isHarmonicActive = false;
              _isVibratoActive = false;

              _isBendLocked = false;
              _isPreBendLocked = false;
              _isBendReleaseLocked = false;
              _isPreBendReleaseLocked = false;
              _isMuteLocked = false;
              _isPinchHarmonicLocked = false;
              _isHarmonicLocked = false;
              _isVibratoLocked = false;
              _isHammerLeftHandLocked = false;
            }

            // Reset the flag after checking
            _navigatedViaNextButton = false;
            _previousSelectedRow = selectedRow;
            _previousSelectedIndex = selectedNoteIndex;
          });
        }
      });
    }

    double screenWidth = MediaQuery.of(context).size.width;
    double techniqueSpacing = screenWidth * 0.01;

    return Container(
      height: 270,
      padding: const EdgeInsets.all(1),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: techniqueSpacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: screenWidth * 0.10,
                  child: GuitarChordsToggleButton(
                    isChordsActive: _isChordsActive,
                    onPressed: () {
                      setState(() {
                        _isChordsActive = !_isChordsActive;
                        _isFavouritesActive = false;
                      });
                    },
                  ),
                ),
                SizedBox(width: techniqueSpacing / 2),
                GuitarTechniqueButtonsPanel(
                  screenWidth: screenWidth,
                  techniqueSpacing: techniqueSpacing,
                  muteActive: _isMuteActive ||
                      _checkIfCurrentChordHasTechnique(
                          'mute', selectedRow, selectedNoteIndex),
                  muteLocked: _isMuteLocked,
                  onMutePressed: () => _handleTechniqueButtonPress(
                      'mute', selectedRow, selectedNoteIndex),
                  pinchHarmonicActive: _isPinchHarmonicActive ||
                      _checkIfCurrentChordHasTechnique(
                          'pinch-harmonic', selectedRow, selectedNoteIndex),
                  pinchHarmonicLocked: _isPinchHarmonicLocked,
                  onPinchHarmonicPressed: () => _handleTechniqueButtonPress(
                      'pinch-harmonic', selectedRow, selectedNoteIndex),
                  vibratoActive: _isVibratoActive ||
                      _checkIfCurrentChordHasTechnique(
                          'vibrato', selectedRow, selectedNoteIndex),
                  vibratoLocked: _isVibratoLocked,
                  onVibratoPressed: () => _handleTechniqueButtonPress(
                      'vibrato', selectedRow, selectedNoteIndex),
                  hammerLeftHandActive: _isHammerLeftHandActive ||
                      _checkIfCurrentChildNoteHasHammerLeftHand(
                          selectedRow, selectedNoteIndex),
                  hammerLeftHandLocked: _isHammerLeftHandLocked,
                  onHammerLeftHandPressed: () =>
                      _handleHammerLeftHandButtonPress(
                          selectedRow, selectedNoteIndex),
                  bendActive: _isBendActive ||
                      _checkIfCurrentChordHasBend(
                          'bend', selectedRow, selectedNoteIndex),
                  bendLocked: _isBendLocked,
                  onBendPressed: () => _handleBendButtonPress(
                      'bend', selectedRow, selectedNoteIndex),
                  preBendActive: _isPreBendActive ||
                      _checkIfCurrentChordHasBend(
                          'pre-bend', selectedRow, selectedNoteIndex),
                  preBendLocked: _isPreBendLocked,
                  onPreBendPressed: () => _handleBendButtonPress(
                      'pre-bend', selectedRow, selectedNoteIndex),
                  pickDownwardActive: _isPickDownwardActive,
                  onPickDownwardPressed: () => _handleTechniqueButtonPress(
                      'pick-downward', selectedRow, selectedNoteIndex),
                  tapRightHandActive: _isTapRightHandActive,
                  onTapRightHandPressed: () => _handleTechniqueButtonPress(
                      'tap-right-hand', selectedRow, selectedNoteIndex),
                  harmonicActive: _isHarmonicActive ||
                      _checkIfCurrentChordHasTechnique(
                          'harmonic', selectedRow, selectedNoteIndex),
                  harmonicLocked: _isHarmonicLocked,
                  onHarmonicPressed: () => _handleTechniqueButtonPress(
                      'harmonic', selectedRow, selectedNoteIndex),
                  slideUpActive: _isSlideUpActive ||
                      _checkIfCurrentChildNoteHasSlide(
                          'slide-up', selectedRow, selectedNoteIndex),
                  onSlideUpPressed: () => _handleSlideButtonPress(
                      'slide-up', selectedRow, selectedNoteIndex),
                  slideDownActive: _isSlideDownActive ||
                      _checkIfCurrentChildNoteHasSlide(
                          'slide-down', selectedRow, selectedNoteIndex),
                  onSlideDownPressed: () => _handleSlideButtonPress(
                      'slide-down', selectedRow, selectedNoteIndex),
                  bendReleaseActive: _isBendReleaseActive ||
                      _checkIfCurrentChordHasBend(
                          'bend-release', selectedRow, selectedNoteIndex),
                  bendReleaseLocked: _isBendReleaseLocked,
                  onBendReleasePressed: () => _handleBendButtonPress(
                      'bend-release', selectedRow, selectedNoteIndex),
                  preBendReleaseActive: _isPreBendReleaseActive ||
                      _checkIfCurrentChordHasBend(
                          'pre-bend-release', selectedRow, selectedNoteIndex),
                  preBendReleaseLocked: _isPreBendReleaseLocked,
                  onPreBendReleasePressed: () => _handleBendButtonPress(
                      'pre-bend-release', selectedRow, selectedNoteIndex),
                  pickUpwardActive: _isPickUpwardActive,
                  onPickUpwardPressed: () => _handleTechniqueButtonPress(
                      'pick-upward', selectedRow, selectedNoteIndex),
                ),
                SizedBox(width: techniqueSpacing / 2),
                SizedBox(
                  width: screenWidth * 0.10,
                  child: GuitarFavouritesToggleButton(
                    isFavouritesActive: _isFavouritesActive,
                    onPressed: _toggleFavourites,
                  ),
                ),
              ],
            )
          ]),
          SizedBox(height: 8),
          SizedBox(
              height: 166,
              width: screenWidth,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.015),
                child: _isFavouritesActive
                    ? Row(children: [
                        GuitarFavouritesGrid(
                          favouritesLoading: _favouritesLoading,
                          favouriteChords: _favouriteChords,
                          onFavouriteChordTapped: (chord) =>
                              widget.onFavouriteChordTapped?.call(chord),
                          onFavouriteChordUsed: (id) =>
                              widget.onFavouriteChordUsed?.call(id),
                        )
                      ])
                    : GuitarFretStringButtons(
                        selectedStringIndex:
                            Provider.of<SelectedStringProvider>(context)
                                .selectedStringIndex,
                        fretForString: (stringIndex) => _getFretForString(
                            _getCurrentChord(selectedRow, selectedNoteIndex),
                            stringIndex),
                        isChordsActive: _isChordsActive,
                        techniqueSpacing: techniqueSpacing,
                        onStringSelected: (stringIndex) {
                          final selectedStringProvider =
                              Provider.of<SelectedStringProvider>(context,
                                  listen: false);
                          setState(() {
                            selectedStringProvider
                                .setSelectedStringIndex(stringIndex);
                            _updateBendOnlyStatesForCurrentString(
                                selectedRow, selectedNoteIndex);
                          });
                        },
                        onFretPressed: (fretNumber) => _onFretPressed(
                            fretNumber, selectedRow, selectedNoteIndex),
                      ),
              ))
        ],
      ),
    );
  }
}
