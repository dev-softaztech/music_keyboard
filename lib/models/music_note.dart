class MusicalNote {
  final String pitch; // e.g., C, D, E
  final int octave; // e.g., 4 (Middle C is in octave 4)
  final NoteType type; // e.g., Whole, Half, Quarter, Eighth, Sixteenth
  bool isConnected; // Whether this note is connected to others
  bool isTiedToNext;
  final String unicodeCharacter;
  int? slurEndIndex;

  MusicalNote(
      {required this.pitch,
      required this.octave,
      required this.type,
      this.isConnected = false,
      this.isTiedToNext = false,
      this.unicodeCharacter = ""});

  MusicalNote copy() {
    return MusicalNote(
      pitch: pitch,
      octave: octave,
      type: type,
      isConnected: isConnected,
      unicodeCharacter: unicodeCharacter,
    );
  }
}

enum NoteType {
  whole,
  half,
  quarter,
  eighth,
  sixteenth,
  thirtySecond,
  sixtyFourth,
  clef,
  rest,
  accidental
}
