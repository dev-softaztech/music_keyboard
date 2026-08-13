import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/src/providers/undo_manager.dart';
import 'package:music_keyboard/src/providers/selected_string_provider.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/guitar_tab_helpers.dart';
import 'package:provider/provider.dart';

/// Bend / preBend / bendRelease / preBendRelease mutators for guitar tab.
///
/// Stateless — operates on the [sheetNoteRows] passed in. Callers (the
/// selected-note provider) are responsible for calling `notifyListeners()`
/// after invoking these.
class BendTechniqueService {
  static void bendNotes(int selectedRow, int row, int startIndex,
      int endIndex, List<SheetRows> sheetNoteRows, BuildContext context) {
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
  }

  static void preBendNotes(int selectedRow, int row, int startIndex,
      int endIndex, List<SheetRows> sheetNoteRows, BuildContext context) {
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
  }

  static void bendReleaseNotes(int selectedRow, int row, int startIndex,
      int endIndex, List<SheetRows> sheetNoteRows, BuildContext context) {
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
  }

  static void preBendReleaseNotes(int selectedRow, int row, int startIndex,
      int endIndex, List<SheetRows> sheetNoteRows, BuildContext context) {
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
  }

  static void removeAllBendsInRange(
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
