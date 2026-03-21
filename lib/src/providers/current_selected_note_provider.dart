import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/bar_line_calculator.dart';
import 'package:music_keyboard/src/providers/undo_manager.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/guitar_tab_helpers.dart';
import 'package:provider/provider.dart';
import 'package:music_keyboard/src/providers/selected_string_provider.dart';

class CurrentSelectedNoteProvider extends ChangeNotifier {
  int selectedRow = 0;
  int insertionIndex = 0;
  int selectedIndex = -1;

  //final List<List<SheetRows>> _history = [];

  // Track if we need to check for automatic bar line placement
  bool _checkForBarLines = false;

  /// **Updates the cursor & highlights the selected note**
  void updateSelectedIndexAndInsertionPoint(int newRow, int newSelectedIndex) {
    selectedRow = newRow;
    selectedIndex = newSelectedIndex;
    insertionIndex = newSelectedIndex + 1;

    // Set flag to check for bar lines on next note addition
    _checkForBarLines = true;

    notifyListeners();
  }

  /// **Add a note to the sheet and handle automatic bar line placement**
  void addNote(
      MusicalNote note, List<SheetRows> sheetNoteRows, BuildContext context) {
    final notes = sheetNoteRows[selectedRow].chords;

    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    notes.insert(insertionIndex, note);

    // Adjust indices for dynamics
    for (var n in notes) {
      if (n.crescendoEndIndex != null &&
          n.crescendoEndIndex! >= selectedIndex) {
        n.crescendoEndIndex = n.crescendoEndIndex! + 1;
      }
      if (n.decrescendoEndIndex != null &&
          n.decrescendoEndIndex! >= selectedIndex) {
        n.decrescendoEndIndex = n.decrescendoEndIndex! + 1;
      }
    }

    for (var n in notes) {
      // Check chord-level techniques
      if (n.harmonicEndIndex != null && n.harmonicEndIndex! > selectedIndex) {
        n.harmonicEndIndex = n.harmonicEndIndex! + 1;
      }
      if (n.vibratoEndIndex != null && n.vibratoEndIndex! > selectedIndex) {
        n.vibratoEndIndex = n.vibratoEndIndex! + 1;
      }
      if (n.muteEndIndex != null && n.muteEndIndex! > selectedIndex) {
        n.muteEndIndex = n.muteEndIndex! + 1;
      }
      if (n.pinchHarmonicEndIndex != null &&
          n.pinchHarmonicEndIndex! > selectedIndex) {
        n.pinchHarmonicEndIndex = n.pinchHarmonicEndIndex! + 1;
      }

      // Check per-string bend techniques (stored on childNotes)
      if (n.childNotes != null) {
        for (var childNote in n.childNotes!) {
          if (childNote.bendEndIndex != null &&
              childNote.bendEndIndex! > selectedIndex) {
            childNote.bendEndIndex = childNote.bendEndIndex! + 1;
          }
          if (childNote.preBendEndIndex != null &&
              childNote.preBendEndIndex! > selectedIndex) {
            childNote.preBendEndIndex = childNote.preBendEndIndex! + 1;
          }
          if (childNote.bendReleaseEndIndex != null &&
              childNote.bendReleaseEndIndex! > selectedIndex) {
            childNote.bendReleaseEndIndex = childNote.bendReleaseEndIndex! + 1;
          }
          if (childNote.preBendReleaseEndIndex != null &&
              childNote.preBendReleaseEndIndex! > selectedIndex) {
            childNote.preBendReleaseEndIndex =
                childNote.preBendReleaseEndIndex! + 1;
          }
        }
      }
    }

    adjustSlurIndicesForSpaceNote(note, notes, insertionIndex, true);

    note.duration = BarLineCalculator.noteDurations[note.type] ?? 0.0;

    updateSelectedIndexAndInsertionPoint(selectedRow, selectedIndex + 1);

    if (_checkForBarLines && note.type != NoteType.bar) {
      _handleAutomaticBarLines(notes, sheetNoteRows);
    }

    notifyListeners();
  }

  void adjustSlurIndicesForSpaceNote(MusicalNote spaceNote,
      List<MusicalNote> notes, int spaceNoteIndex, bool isAdd) {
    if (spaceNote.type != NoteType.space) return;
    if (spaceNoteIndex < 0 || spaceNoteIndex > notes.length) return;

    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      if (note.slurEndIndex != null) {
        if (i < spaceNoteIndex && note.slurEndIndex! >= spaceNoteIndex) {
          if (isAdd) {
            if (note.slurEndIndex! > notes.length) {
              note.slurEndIndex = notes.length;
            }

            note.slurEndIndex = note.slurEndIndex! + 1;
          } else {
            if (note.slurEndIndex! <= 0) {
              note.slurEndIndex = 0;
            }

            note.slurEndIndex = note.slurEndIndex! - 1;
          }
        }
      }
    }
  }

  /// **Handle automatic bar line placement based on time signature**
  void _handleAutomaticBarLines(List<MusicalNote> notes,
      [List<SheetRows>? allRows]) {
    MusicalNote? timeSignature;

    // First check for time signatures within the current row
    timeSignature = BarLineCalculator.findLastTimeSignature(notes);

    // If no time signature found in current row and allRows is provided, check previous rows
    if (timeSignature == null && allRows != null) {
      int currentRowIndex = -1;

      // Find the current row index
      for (int i = 0; i < allRows.length; i++) {
        if (identical(allRows[i], notes)) {
          currentRowIndex = i;
          break;
        }
      }

      if (currentRowIndex > 0) {
        timeSignature = BarLineCalculator.findLastTimeSignatureAcrossRows(
            allRows, currentRowIndex - 1);
      }
    }

    // Only proceed if we have a time signature (either in this row or from previous rows)
    if (timeSignature != null ||
        notes.any((note) => note.type == NoteType.timeSignature)) {
      // Calculate positions for automatic bar lines
      // This method now handles multiple time signatures within a row
      List<int> barLinePositions =
          BarLineCalculator.calculateBarLinePositions(notes, timeSignature);

      // Add bar lines at calculated positions (in reverse order to maintain correct indices)
      for (int i = barLinePositions.length - 1; i >= 0; i--) {
        int position = barLinePositions[i];

        // Create a bar line note
        MusicalNote barLineNote = MusicalNote(
          pitch: "D",
          octave: 4,
          type: NoteType.bar,
          unicodeCharacter: '\ue030', // Standard bar line
        );

        // Insert the bar line at the calculated position
        if (position < notes.length) {
          notes.insert(position, barLineNote);

          // Adjust insertion point if the bar line was inserted before it
          if (position < insertionIndex) {
            insertionIndex++;
            selectedIndex = insertionIndex - 1;
          }
        }
      }
    }
  }

  void beamNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    // Ensure selection is left-to-right
    if (startIndex > endIndex) {
      int tempIndex = startIndex;
      startIndex = endIndex;
      endIndex = tempIndex;
    }

    // Apply beaming to all notes in the range
    for (int i = startIndex; i <= endIndex; i++) {
      sheetNoteRows[row].chords[i].isBeamed = true;
    }

    notifyListeners();
  }

  void slurNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    //saveState(sheetNoteRows); // Save for undo

    // Ensure selection is left-to-right
    if (startIndex > endIndex) {
      int tempIndex = startIndex;
      startIndex = endIndex;
      endIndex = tempIndex;
    }

    MusicalNote firstNote = sheetNoteRows[row].chords[startIndex];
    firstNote.slurEndIndex = endIndex;

    notifyListeners();
  }

  void crescendoNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    if (startIndex > endIndex) {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
    }

    // Remove any overlapping dynamics
    for (int i = 0; i < sheetNoteRows[row].chords.length; i++) {
      final note = sheetNoteRows[row].chords[i];
      if (note.isCrescendoStart && note.crescendoEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.crescendoEndIndex! >= startIndex &&
                note.crescendoEndIndex! <= endIndex)) {
          note.isCrescendoStart = false;
          note.crescendoEndIndex = null;
        }
      }
      if (note.isDecrescendoStart && note.decrescendoEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.decrescendoEndIndex! >= startIndex &&
                note.decrescendoEndIndex! <= endIndex)) {
          note.isDecrescendoStart = false;
          note.decrescendoEndIndex = null;
        }
      }
    }

    MusicalNote firstNote = sheetNoteRows[row].chords[startIndex];
    firstNote.isCrescendoStart = true;
    firstNote.crescendoEndIndex = endIndex;

    notifyListeners();
  }

  void decrescendoNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    if (startIndex > endIndex) {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
    }

    // Remove any overlapping dynamics
    for (int i = 0; i < sheetNoteRows[row].chords.length; i++) {
      final note = sheetNoteRows[row].chords[i];
      if (note.isCrescendoStart && note.crescendoEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.crescendoEndIndex! >= startIndex &&
                note.crescendoEndIndex! <= endIndex)) {
          note.isCrescendoStart = false;
          note.crescendoEndIndex = null;
        }
      }
      if (note.isDecrescendoStart && note.decrescendoEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.decrescendoEndIndex! >= startIndex &&
                note.decrescendoEndIndex! <= endIndex)) {
          note.isDecrescendoStart = false;
          note.decrescendoEndIndex = null;
        }
      }
    }

    MusicalNote firstNote = sheetNoteRows[row].chords[startIndex];
    firstNote.isDecrescendoStart = true;
    firstNote.decrescendoEndIndex = endIndex;

    notifyListeners();
  }

  /// **Get all notes in the same beamed group as the given note.**
  ///
  /// Recognises both regular beamable note types (eighth, sixteenth,
  /// thirtySecond, sixtyFourth) *and* [NoteType.chord] parents whose
  /// [MusicalNote.isBeamed] flag is true and whose [MusicalNote.childNotes]
  /// contain at least one beamable type.
  List<int> getBeamedGroupIndices(int noteIndex, List<MusicalNote> notes) {
    if (noteIndex < 0 ||
        noteIndex >= notes.length ||
        !notes[noteIndex].isBeamed) {
      return [];
    }

    // Returns true if a note is part of a beamed group (regular or chord).
    bool isBeamable(MusicalNote n) {
      if (!n.isBeamed) return false;
      if (n.type == NoteType.chord) {
        return n.childNotes?.any((c) =>
                c.type == NoteType.eighth ||
                c.type == NoteType.sixteenth ||
                c.type == NoteType.thirtySecond ||
                c.type == NoteType.sixtyFourth) ??
            false;
      }
      return n.type == NoteType.eighth ||
          n.type == NoteType.sixteenth ||
          n.type == NoteType.thirtySecond ||
          n.type == NoteType.sixtyFourth;
    }

    if (!isBeamable(notes[noteIndex])) return [];

    List<int> groupIndices = [noteIndex];

    // Traverse backwards to find connected beamed notes
    for (int i = noteIndex - 1; i >= 0; i--) {
      if (isBeamable(notes[i])) {
        groupIndices.insert(0, i);
      } else {
        break;
      }
    }

    // Traverse forwards to find connected beamed notes
    for (int i = noteIndex + 1; i < notes.length; i++) {
      if (isBeamable(notes[i])) {
        groupIndices.add(i);
      } else {
        break;
      }
    }

    return groupIndices;
  }

  void switchBeamRotation(List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    final row = selectedRow;
    final index = selectedIndex;

    if (index >= 0 && index < sheetNoteRows[row].chords.length) {
      final selectedNote = sheetNoteRows[row].chords[index];

      if (selectedNote.isBeamed) {
        List<int> groupIndices =
            getBeamedGroupIndices(index, sheetNoteRows[row].chords);

        if (groupIndices.isNotEmpty) {
          final firstNote = sheetNoteRows[row].chords[groupIndices.first];

          // Toggle — derive the new state from the current first-note value.
          final bool newState = firstNote.isUpsideDown != true;

          // Apply to every note in the group.  For chord parents, also apply
          // to all of their child notes so they stay visually consistent.
          for (final idx in groupIndices) {
            final note = sheetNoteRows[row].chords[idx];
            note.isUpsideDown = newState;
            if (note.type == NoteType.chord && note.childNotes != null) {
              for (var child in note.childNotes!) {
                child.isUpsideDown = newState;
              }
            }
          }
        }
      }
    }

    notifyListeners();
  }

//Guitar tab
  void muteNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    if (startIndex > endIndex) {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
    }

    // Remove any overlapping dynamics
    for (int i = 0; i < sheetNoteRows[row].chords.length; i++) {
      final note = sheetNoteRows[row].chords[i];
      if (note.isPinchHarmonicStart && note.pinchHarmonicEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.pinchHarmonicEndIndex! >= startIndex &&
                note.pinchHarmonicEndIndex! <= endIndex)) {
          note.isPinchHarmonicStart = false;
          note.pinchHarmonicEndIndex = null;
        }
      }
      if (note.isHarmonicStart && note.harmonicEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.harmonicEndIndex! >= startIndex &&
                note.harmonicEndIndex! <= endIndex)) {
          note.isHarmonicStart = false;
          note.harmonicEndIndex = null;
        }
      }
      if (note.isMuteStart && note.muteEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.muteEndIndex! >= startIndex &&
                note.muteEndIndex! <= endIndex)) {
          note.isMuteStart = false;
          note.muteEndIndex = null;
        }
      }
    }

    MusicalNote firstNote = sheetNoteRows[row].chords[startIndex];
    firstNote.isMuteStart = true;
    firstNote.muteEndIndex = endIndex;

    notifyListeners();
  }

  void pinchHarmonicNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    if (startIndex > endIndex) {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
    }

    // Remove any overlapping dynamics
    for (int i = 0; i < sheetNoteRows[row].chords.length; i++) {
      final note = sheetNoteRows[row].chords[i];
      if (note.isMuteStart && note.muteEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.muteEndIndex! >= startIndex &&
                note.muteEndIndex! <= endIndex)) {
          note.isMuteStart = false;
          note.muteEndIndex = null;
        }
      }
      if (note.isHarmonicStart && note.harmonicEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.harmonicEndIndex! >= startIndex &&
                note.harmonicEndIndex! <= endIndex)) {
          note.isHarmonicStart = false;
          note.harmonicEndIndex = null;
        }
      }
      if (note.isPinchHarmonicStart && note.pinchHarmonicEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.pinchHarmonicEndIndex! >= startIndex &&
                note.pinchHarmonicEndIndex! <= endIndex)) {
          note.isPinchHarmonicStart = false;
          note.pinchHarmonicEndIndex = null;
        }
      }
    }

    MusicalNote firstNote = sheetNoteRows[row].chords[startIndex];
    firstNote.isPinchHarmonicStart = true;
    firstNote.pinchHarmonicEndIndex = endIndex;

    notifyListeners();
  }

  void harmonicNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    if (startIndex > endIndex) {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
    }

    // Remove any overlapping dynamics
    for (int i = 0; i < sheetNoteRows[row].chords.length; i++) {
      final note = sheetNoteRows[row].chords[i];
      if (note.isPinchHarmonicStart && note.pinchHarmonicEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.pinchHarmonicEndIndex! >= startIndex &&
                note.pinchHarmonicEndIndex! <= endIndex)) {
          note.isPinchHarmonicStart = false;
          note.pinchHarmonicEndIndex = null;
        }
      }
      if (note.isMuteStart && note.muteEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.muteEndIndex! >= startIndex &&
                note.muteEndIndex! <= endIndex)) {
          note.isMuteStart = false;
          note.muteEndIndex = null;
        }
      }
      if (note.isHarmonicStart && note.harmonicEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.harmonicEndIndex! >= startIndex &&
                note.harmonicEndIndex! <= endIndex)) {
          note.isHarmonicStart = false;
          note.harmonicEndIndex = null;
        }
      }
    }

    MusicalNote firstNote = sheetNoteRows[row].chords[startIndex];
    firstNote.isHarmonicStart = true;
    firstNote.harmonicEndIndex = endIndex;

    notifyListeners();
  }

  void vibratoNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    if (startIndex > endIndex) {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
    }

    // Remove any overlapping dynamics
    for (int i = 0; i < sheetNoteRows[row].chords.length; i++) {
      final note = sheetNoteRows[row].chords[i];
      if (note.isVibratoStart && note.vibratoEndIndex != null) {
        if ((i >= startIndex && i <= endIndex) ||
            (note.vibratoEndIndex! >= startIndex &&
                note.vibratoEndIndex! <= endIndex)) {
          note.isVibratoStart = false;
          note.vibratoEndIndex = null;
        }
      }
    }

    MusicalNote firstNote = sheetNoteRows[row].chords[startIndex];
    firstNote.isVibratoStart = true;
    firstNote.vibratoEndIndex = endIndex;

    notifyListeners();
  }

  void bendNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    if (startIndex > endIndex) {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
    }

    removeAllBendsInRange(sheetNoteRows, row, startIndex, endIndex);

    MusicalNote firstNote = sheetNoteRows[row].chords[startIndex];

    firstNote.childNotes ??= [];

    // Get the selected string index from the provider
    final selectedStringProvider =
        Provider.of<SelectedStringProvider>(context, listen: false);
    final selectedStringIndex = selectedStringProvider.selectedStringIndex;

    // Find or create the childNote for the currently selected string
    MusicalNote? childNote;
    for (var child in firstNote.childNotes!) {
      if (child.octave == selectedStringIndex) {
        childNote = child;
        break;
      }
    }

    // If no childNote exists for this string, we can't add a bend without a fret
    childNote ??= GuitarTabHelpers.updateFretForString(
        sheetNoteRows, selectedRow, startIndex, selectedStringIndex, 0,
        goToNextString: false);

    childNote.isBendStart = true;
    childNote.bendEndIndex = endIndex;

    notifyListeners();
  }

  void preBendNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    if (startIndex > endIndex) {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
    }

    removeAllBendsInRange(sheetNoteRows, row, startIndex, endIndex);

    MusicalNote firstNote = sheetNoteRows[row].chords[startIndex];

    firstNote.childNotes ??= [];

    // Get the selected string index from the provider
    final selectedStringProvider =
        Provider.of<SelectedStringProvider>(context, listen: false);
    final selectedStringIndex = selectedStringProvider.selectedStringIndex;

    // Find or create the childNote for the currently selected string
    MusicalNote? childNote;
    for (var child in firstNote.childNotes!) {
      if (child.octave == selectedStringIndex) {
        childNote = child;
        break;
      }
    }

    // If no childNote exists for this string, we can't add a bend without a fret
    childNote ??= GuitarTabHelpers.updateFretForString(
        sheetNoteRows, selectedRow, startIndex, selectedStringIndex, 0,
        goToNextString: false);

    childNote.isPreBendStart = true;
    childNote.preBendEndIndex = endIndex;

    notifyListeners();
  }

  void bendReleaseNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    if (startIndex > endIndex) {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
    }

    removeAllBendsInRange(sheetNoteRows, row, startIndex, endIndex);

    MusicalNote firstNote = sheetNoteRows[row].chords[startIndex];

    firstNote.childNotes ??= [];

    // Get the selected string index from the provider
    final selectedStringProvider =
        Provider.of<SelectedStringProvider>(context, listen: false);
    final selectedStringIndex = selectedStringProvider.selectedStringIndex;

    // Find or create the childNote for the currently selected string
    MusicalNote? childNote;
    for (var child in firstNote.childNotes!) {
      if (child.octave == selectedStringIndex) {
        childNote = child;
        break;
      }
    }

    // If no childNote exists for this string, we can't add a bend without a fret
    childNote ??= GuitarTabHelpers.updateFretForString(
        sheetNoteRows, selectedRow, startIndex, selectedStringIndex, 0,
        goToNextString: false);

    childNote.isBendReleaseStart = true;
    childNote.bendReleaseEndIndex = endIndex;

    notifyListeners();
  }

  void preBendReleaseNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    context.read<SheetUndoManager>().saveState(sheetNoteRows);

    if (startIndex > endIndex) {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
    }

    removeAllBendsInRange(sheetNoteRows, row, startIndex, endIndex);

    MusicalNote firstNote = sheetNoteRows[row].chords[startIndex];

    firstNote.childNotes ??= [];

    // Get the selected string index from the provider
    final selectedStringProvider =
        Provider.of<SelectedStringProvider>(context, listen: false);
    final selectedStringIndex = selectedStringProvider.selectedStringIndex;

    // Find or create the childNote for the currently selected string
    MusicalNote? childNote;
    for (var child in firstNote.childNotes!) {
      if (child.octave == selectedStringIndex) {
        childNote = child;
        break;
      }
    }

    // If no childNote exists for this string, we can't add a bend without a fret
    childNote ??= GuitarTabHelpers.updateFretForString(
        sheetNoteRows, selectedRow, startIndex, selectedStringIndex, 0,
        goToNextString: false);

    childNote.isPreBendReleaseStart = true;
    childNote.preBendReleaseEndIndex = endIndex;

    notifyListeners();
  }

  void removeAllBendsInRange(
      List<SheetRows> sheetNoteRows, int row, int startIndex, int endIndex) {
    for (int i = 0; i < sheetNoteRows[row].chords.length; i++) {
      final chord = sheetNoteRows[row].chords[i];
      final childNotes = chord.childNotes;
      if (childNotes != null) {
        for (int i = 0; i < childNotes.length; i++) {
          var note = childNotes[i];
          if (note.isBendStart && note.bendEndIndex != null) {
            if ((i >= startIndex && i <= endIndex) ||
                (note.bendEndIndex! >= startIndex &&
                    note.bendEndIndex! <= endIndex)) {
              note.isBendStart = false;
              note.bendEndIndex = null;
            }
          }
          if (note.isPreBendStart && note.preBendEndIndex != null) {
            if ((i >= startIndex && i <= endIndex) ||
                (note.preBendEndIndex! >= startIndex &&
                    note.preBendEndIndex! <= endIndex)) {
              note.isPreBendStart = false;
              note.preBendEndIndex = null;
            }
          }
          if (note.isBendReleaseStart && note.bendReleaseEndIndex != null) {
            if ((i >= startIndex && i <= endIndex) ||
                (note.bendReleaseEndIndex! >= startIndex &&
                    note.bendReleaseEndIndex! <= endIndex)) {
              note.isBendReleaseStart = false;
              note.bendReleaseEndIndex = null;
            }
          }
          if (note.isPreBendReleaseStart &&
              note.preBendReleaseEndIndex != null) {
            if ((i >= startIndex && i <= endIndex) ||
                (note.preBendReleaseEndIndex! >= startIndex &&
                    note.preBendReleaseEndIndex! <= endIndex)) {
              note.isPreBendReleaseStart = false;
              note.preBendReleaseEndIndex = null;
            }
          }
        }
      }
    }
  }
}
