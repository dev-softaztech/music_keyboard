import 'package:music_keyboard/models/music_note.dart';

/// Utility class for handling time signatures and bar line calculations
class BarLineCalculator {
  /// Map of time signature unicode characters to their beat values
  static final Map<String, double> timeSignatureValues = {
    '\ue08a': 4.0, // 4 quarter note beats per bar
    '\ue08b': 4.0, // 2 half note beats per bar (equivalent to 4 quarter notes)
    '\uf5f9': 2.0, // 2 quarter note beats per bar
    '\uf5fa': 4.0, // 2 half note beats per bar
    '\uf5fb': 6.0, // 3 half note beats per bar
    '\uf5fc': 3.0, // 3 quarter note beats per bar
    '\uf5fd': 3.0 / 2, // 3 eighth note beats per bar
    '\uf5fe': 4.0, // 4 quarter note beats per bar
    '\uf5ff': 5.0, // 5 quarter note beats per bar
    '\uf600': 5.0 / 2, // 5 eighth note beats per bar
    '\uf601': 6.0, // 6 quarter note beats per bar
    '\uf602': 6.0 / 2, // 6 eighth note beats per bar
    '\uf603': 7.0 / 2, // 7 eighth note beats per bar
    '\uf604': 9.0 / 2, // 9 eighth note beats per bar
    '\uf605': 12.0 / 2, // 12 eighth note beats per bar
    '\uf510': 4.0, // Additional time signature from ClefsKeyboardLayout
  };

  /// Map of note types to their duration values (in quarter notes)
  static final Map<NoteType, double> noteDurations = {
    NoteType.whole: 4.0,
    NoteType.half: 2.0,
    NoteType.quarter: 1.0,
    NoteType.eighth: 0.5,
    NoteType.sixteenth: 0.25,
    NoteType.thirtySecond: 0.125,
    NoteType.sixtyFourth: 0.0625,
    NoteType.rest: 0.0, // Rests don't contribute to duration
    NoteType.accidental: 0.0, // Accidentals don't contribute to duration
    NoteType.clef: 0.0, // Clefs don't contribute to duration
    NoteType.bar: 0.0, // Bar lines don't contribute to duration
  };

  /// Find the last time signature in a row of notes
  static String? findLastTimeSignature(List<MusicalNote> notes) {
    String? lastTimeSignature;

    for (var note in notes) {
      if (note.type == NoteType.clef &&
          timeSignatureValues.containsKey(note.unicodeCharacter)) {
        lastTimeSignature = note.unicodeCharacter;
      }
    }

    return lastTimeSignature;
  }

  /// Find the last time signature across all rows up to the current row
  static String? findLastTimeSignatureAcrossRows(
      List<List<MusicalNote>> allRows, int currentRowIndex) {
    String? lastTimeSignature;

    // Check all rows up to and including the current row
    for (int i = 0; i <= currentRowIndex; i++) {
      String? rowTimeSignature = findLastTimeSignature(allRows[i]);
      if (rowTimeSignature != null) {
        lastTimeSignature = rowTimeSignature;
      }
    }

    return lastTimeSignature;
  }

  /// Find the last time signature before a specific note in a row
  static String? findLastTimeSignatureBeforeNote(
      List<MusicalNote> notes, int noteIndex) {
    String? lastTimeSignature;

    // Only check notes up to the specified index
    for (int i = 0; i <= noteIndex; i++) {
      if (i < notes.length &&
          notes[i].type == NoteType.clef &&
          timeSignatureValues.containsKey(notes[i].unicodeCharacter)) {
        lastTimeSignature = notes[i].unicodeCharacter;
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

  /// Check if a bar is full based on the time signature
  static bool isBarFull(double barDuration, String timeSignature) {
    double maxDuration = timeSignatureValues[timeSignature] ?? 4.0;
    return barDuration >= maxDuration;
  }

  /// Check if a bar has too many notes based on the time signature
  static bool hasBarTooManyNotes(double barDuration, String timeSignature) {
    double maxDuration = timeSignatureValues[timeSignature] ?? 4.0;
    return barDuration > maxDuration;
  }

  /// Calculate positions where bar lines should be automatically placed
  static List<int> calculateBarLinePositions(List<MusicalNote> notes) {
    List<int> barPositions = [];
    String? currentTimeSignature;
    double currentBarDuration = 0.0;

    // Set duration for each note
    for (var note in notes) {
      note.duration = noteDurations[note.type] ?? 0.0;
    }

    // Process notes and handle time signature changes
    for (int i = 0; i < notes.length; i++) {
      MusicalNote note = notes[i];

      // Check for time signature changes
      if (note.type == NoteType.clef &&
          timeSignatureValues.containsKey(note.unicodeCharacter)) {
        currentTimeSignature = note.unicodeCharacter;
        currentBarDuration = 0.0; // Reset bar duration after a time signature
        continue;
      }

      // Skip existing bar lines
      if (note.type == NoteType.bar) {
        currentBarDuration = 0.0;
        continue;
      }

      // If we don't have a time signature yet, skip this note
      if (currentTimeSignature == null) {
        continue;
      }

      // Add this note's duration to the current bar
      currentBarDuration += note.duration;
      double maxDuration = timeSignatureValues[currentTimeSignature] ?? 4.0;

      // If we've reached or exceeded the bar duration, add a bar line position
      if (currentBarDuration >= maxDuration && i < notes.length - 1) {
        // Don't add a bar line if the next note is already a bar line or time signature
        if (i + 1 < notes.length) {
          MusicalNote nextNote = notes[i + 1];
          if (nextNote.type != NoteType.bar &&
              !(nextNote.type == NoteType.clef &&
                  timeSignatureValues.containsKey(nextNote.unicodeCharacter))) {
            barPositions.add(i + 1); // Position after the current note
          }
        }
        currentBarDuration = 0.0;
      }
    }

    return barPositions;
  }
}
