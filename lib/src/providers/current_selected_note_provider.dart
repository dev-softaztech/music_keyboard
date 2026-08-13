import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/bar_line_calculator.dart';
import 'package:music_keyboard/src/providers/undo_manager.dart';
import 'package:provider/provider.dart';
import 'package:music_keyboard/src/services/beam_slur_service.dart';
import 'package:music_keyboard/src/services/bend_technique_service.dart';
import 'package:music_keyboard/src/services/mute_harmonic_service.dart';

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
    BeamSlurService.beamNotes(row, startIndex, endIndex, sheetNoteRows, context);
    notifyListeners();
  }

  void slurNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    BeamSlurService.slurNotes(row, startIndex, endIndex, sheetNoteRows, context);
    notifyListeners();
  }

  void crescendoNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    BeamSlurService.crescendoNotes(
        row, startIndex, endIndex, sheetNoteRows, context);
    notifyListeners();
  }

  void decrescendoNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    BeamSlurService.decrescendoNotes(
        row, startIndex, endIndex, sheetNoteRows, context);
    notifyListeners();
  }

  /// **Get all notes in the same beamed group as the given note.**
  ///
  /// Recognises both regular beamable note types (eighth, sixteenth,
  /// thirtySecond, sixtyFourth) *and* [NoteType.chord] parents whose
  /// [MusicalNote.isBeamed] flag is true and whose [MusicalNote.childNotes]
  /// contain at least one beamable type.
  List<int> getBeamedGroupIndices(int noteIndex, List<MusicalNote> notes) {
    return BeamSlurService.getBeamedGroupIndices(noteIndex, notes);
  }

  void switchBeamRotation(List<SheetRows> sheetNoteRows, BuildContext context) {
    BeamSlurService.switchBeamRotation(
        selectedRow, selectedIndex, sheetNoteRows, context);
    notifyListeners();
  }

//Guitar tab
  void muteNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    MuteHarmonicService.muteNotes(
        row, startIndex, endIndex, sheetNoteRows, context);
    notifyListeners();
  }

  void pinchHarmonicNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    MuteHarmonicService.pinchHarmonicNotes(
        row, startIndex, endIndex, sheetNoteRows, context);
    notifyListeners();
  }

  void harmonicNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    MuteHarmonicService.harmonicNotes(
        row, startIndex, endIndex, sheetNoteRows, context);
    notifyListeners();
  }

  void vibratoNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    MuteHarmonicService.vibratoNotes(
        row, startIndex, endIndex, sheetNoteRows, context);
    notifyListeners();
  }

  void bendNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    BendTechniqueService.bendNotes(
        selectedRow, row, startIndex, endIndex, sheetNoteRows, context);
    notifyListeners();
  }

  void preBendNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    BendTechniqueService.preBendNotes(
        selectedRow, row, startIndex, endIndex, sheetNoteRows, context);
    notifyListeners();
  }

  void bendReleaseNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    BendTechniqueService.bendReleaseNotes(
        selectedRow, row, startIndex, endIndex, sheetNoteRows, context);
    notifyListeners();
  }

  void preBendReleaseNotes(int row, int startIndex, int endIndex,
      List<SheetRows> sheetNoteRows, BuildContext context) {
    BendTechniqueService.preBendReleaseNotes(
        selectedRow, row, startIndex, endIndex, sheetNoteRows, context);
    notifyListeners();
  }

  void removeAllBendsInRange(
      List<SheetRows> sheetNoteRows, int row, int startIndex, int endIndex) {
    BendTechniqueService.removeAllBendsInRange(
        sheetNoteRows, row, startIndex, endIndex);
  }
}
