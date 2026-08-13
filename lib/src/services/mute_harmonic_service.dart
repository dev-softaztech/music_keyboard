import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/src/providers/undo_manager.dart';
import 'package:provider/provider.dart';

/// Mute / pinchHarmonic / harmonic / vibrato mutators for guitar tab.
///
/// Stateless — operates on the [sheetNoteRows] passed in. Callers (the
/// selected-note provider) are responsible for calling `notifyListeners()`
/// after invoking these.
class MuteHarmonicService {
  static void muteNotes(int row, int startIndex, int endIndex,
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
  }

  static void pinchHarmonicNotes(int row, int startIndex, int endIndex,
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
  }

  static void harmonicNotes(int row, int startIndex, int endIndex,
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
  }

  static void vibratoNotes(int row, int startIndex, int endIndex,
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
  }
}
