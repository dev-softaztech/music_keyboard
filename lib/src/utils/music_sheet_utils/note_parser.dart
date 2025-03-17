import 'package:music_keyboard/models/music_note.dart';

class NoteParser {
  /// Parses a keyboard input string (e.g., "C4") into a [MusicalNote].
  static MusicalNote parse(String input) {
    if (input.length < 2 || input.length > 3) {
      throw FormatException("Invalid note format: $input");
    }

    final pitch = input[0]; // e.g., C, D, E
    final octave = int.parse(input.substring(1)); // e.g., 4 or 10

    // Validate pitch
    const validPitches = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
    if (!validPitches.contains(pitch)) {
      throw FormatException("Invalid pitch: $pitch");
    }

    return MusicalNote(pitch: pitch, octave: octave, type: NoteType.quarter);
  }
}
