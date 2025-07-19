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
  double duration; // Duration value for bar line calculation
  final String topTimeSignatureCharacter;
  final String bottomTimeSignatureCharacter;

  MusicalNote(
      {required this.pitch,
      required this.octave,
      required this.type,
      this.isConnected = false,
      this.isTiedToNext = false,
      this.unicodeCharacter = "",
      this.accidentalCharacter = "",
      this.noteY = 0.0,
      this.duration = 0.0,
      this.topTimeSignatureCharacter = "",
      this.bottomTimeSignatureCharacter = ""});

  MusicalNote copy() {
    return MusicalNote(
        pitch: pitch,
        octave: octave,
        type: type,
        isConnected: isConnected,
        isTiedToNext: isTiedToNext,
        unicodeCharacter: unicodeCharacter,
        accidentalCharacter: accidentalCharacter,
        noteY: noteY,
        duration: duration,
        topTimeSignatureCharacter: topTimeSignatureCharacter,
        bottomTimeSignatureCharacter: bottomTimeSignatureCharacter);
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
  bar,
  timeSignature
}
