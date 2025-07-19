import 'package:music_keyboard/models/music_note.dart';

/// Utility class for handling time signatures and bar line calculations
class BarLineCalculator {
  static final Map<String, int> topTimeSignatureValues = {
    '\uF5C9': 0,
    '\uF5CB': 1,
    '\uF5CD': 2,
    '\uF5CF': 3,
    '\uF5D1': 4,
    '\uF5D3': 5,
    '\uF5D5': 6,
    '\uF5D7': 7,
    '\uF5D9': 8,
    '\uF5DB': 9,
  };

  static final Map<String, int> bottomTimeSignatureValues = {
    '\uF5C8': 0,
    '\uF5CA': 1,
    '\uF5CC': 2,
    '\uF5CE': 3,
    '\uF5D0': 4,
    '\uF5D2': 5,
    '\uF5D4': 6,
    '\uF5D6': 7,
    '\uF5D8': 8,
    '\uF5DA': 9,
  };

  /// Map of note types to their duration values (a whole note is 1.0)
  static final Map<NoteType, double> noteDurations = {
    NoteType.whole: 1,
    NoteType.half: 0.5,
    NoteType.quarter: 0.25,
    NoteType.eighth: 0.125,
    NoteType.sixteenth: 0.0625,
    NoteType.thirtySecond: 0.03125,
    NoteType.sixtyFourth: 0.015625,
    NoteType.rest: 0.0, // Rests don't contribute to duration
    NoteType.accidental: 0.0,
    NoteType.clef: 0.0,
    NoteType.bar: 0.0,
    NoteType.timeSignature: 0.0,
  };

  /// Find the last time signature in a row of notes
  static MusicalNote? findLastTimeSignature(List<MusicalNote> notes) {
    MusicalNote? lastTimeSignature;
    for (var note in notes) {
      if (note.type == NoteType.timeSignature) {
        lastTimeSignature = note;
      }
    }
    return lastTimeSignature;
  }

  /// Find the last time signature across all rows up to the current row
  static MusicalNote? findLastTimeSignatureAcrossRows(
      List<List<MusicalNote>> allRows, int currentRowIndex) {
    MusicalNote? lastTimeSignature;
    for (int i = 0; i <= currentRowIndex; i++) {
      MusicalNote? rowTimeSignature = findLastTimeSignature(allRows[i]);
      if (rowTimeSignature != null) {
        lastTimeSignature = rowTimeSignature;
      }
    }
    return lastTimeSignature;
  }

  /// Find the last time signature before a specific note in a row
  static MusicalNote? findLastTimeSignatureBeforeNote(
      List<MusicalNote> notes, int noteIndex) {
    MusicalNote? lastTimeSignature;
    for (int i = 0; i <= noteIndex; i++) {
      if (i < notes.length && notes[i].type == NoteType.timeSignature) {
        lastTimeSignature = notes[i];
      }
    }
    return lastTimeSignature;
  }

  /// Calculate the total duration of notes in a bar
  static double calculateBarDuration(
      List<MusicalNote> notes, int startIndex, int endIndex) {
    double totalDuration = 0.0;

    for (int i = startIndex; i <= endIndex; i++) {
      if (i < notes.length) {
        totalDuration += notes[i].duration;
      }
    }

    return totalDuration;
  }

  /// Set the duration values for notes based on their type
  static void setNoteDurations(List<MusicalNote> notes) {
    for (var note in notes) {
      note.duration = noteDurations[note.type] ?? 0.0;
    }
  }

  static double _getMaxDuration(MusicalNote timeSignature) {
    int top =
        topTimeSignatureValues[timeSignature.topTimeSignatureCharacter] ?? 4;
    int bottom =
        bottomTimeSignatureValues[timeSignature.bottomTimeSignatureCharacter] ??
            4;

    if (bottom == 0) return 4.0; // Avoid division by zero, default to 4/4

    // Calculate duration relative to a whole note (1.0)
    // e.g., 3/4 is 3 * (1/4) = 0.75
    // e.g., 6/8 is 6 * (1/8) = 0.75
    return top * (1.0 / bottom);
  }

  /// Check if a bar is full based on the time signature
  static bool isBarFull(double barDuration, MusicalNote timeSignature) {
    double maxDuration = _getMaxDuration(timeSignature);
    // Use a small epsilon for floating point comparison
    return (barDuration - maxDuration) >= -1e-9;
  }

  /// Check if a bar has too many notes based on the time signature
  static bool hasBarTooManyNotes(
      double barDuration, MusicalNote timeSignature) {
    double maxDuration = _getMaxDuration(timeSignature);
    return barDuration > maxDuration;
  }

  /// Calculate positions where bar lines should be automatically placed
  static List<int> calculateBarLinePositions(List<MusicalNote> notes) {
    List<int> barPositions = [];
    MusicalNote? currentTimeSignature;
    double currentBarDuration = 0.0;

    // Set duration for each note
    setNoteDurations(notes);

    // Process notes and handle time signature changes
    for (int i = 0; i < notes.length; i++) {
      MusicalNote note = notes[i];

      // Check for time signature changes
      if (note.type == NoteType.timeSignature) {
        currentTimeSignature = note;
        currentBarDuration = 0.0; // Reset bar duration after a time signature
        continue;
      }

      // Skip existing bar lines
      if (note.type == NoteType.bar) {
        currentBarDuration = 0.0;
        continue;
      }

      // If we don't have a time signature yet, find the last one
      currentTimeSignature ??= findLastTimeSignature(notes.sublist(0, i));

      // If still no time signature, skip this note
      if (currentTimeSignature == null) {
        continue;
      }

      // Add this note's duration to the current bar
      currentBarDuration += note.duration;
      double maxDuration = _getMaxDuration(currentTimeSignature);

      // If we've reached or exceeded the bar duration, add a bar line position
      if ((currentBarDuration - maxDuration) >= -1e-9 && i < notes.length - 1) {
        // Don't add a bar line if the next note is already a bar line or time signature
        if (i + 1 < notes.length) {
          MusicalNote nextNote = notes[i + 1];
          if (nextNote.type != NoteType.bar &&
              nextNote.type != NoteType.timeSignature) {
            barPositions.add(i + 1); // Position after the current note
          }
        }
        currentBarDuration = 0.0;
      }
    }

    return barPositions;
  }
}
