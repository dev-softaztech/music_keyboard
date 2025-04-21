class MusicalNote {
  final String pitch; // e.g., C, D, E
  final int octave; // e.g., 4 (Middle C is in octave 4)
  final NoteType type; // e.g., Whole, Half, Quarter, Eighth, Sixteenth
  bool isConnected; // Whether this note is connected to others
  bool isTiedToNext;
  final String unicodeCharacter;
  final String accidentalCharacter; // Unicode character for the accidental
  int? slurEndIndex;
  double noteY;

  MusicalNote(
      {required this.pitch,
      required this.octave,
      required this.type,
      this.isConnected = false,
      this.isTiedToNext = false,
      this.unicodeCharacter = "",
      this.accidentalCharacter = "",
      this.noteY = 0.0});

  MusicalNote copy() {
    return MusicalNote(
        pitch: pitch,
        octave: octave,
        type: type,
        isConnected: isConnected,
        unicodeCharacter: unicodeCharacter,
        accidentalCharacter: accidentalCharacter,
        noteY: noteY);
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
  accidental,
  bar
}
