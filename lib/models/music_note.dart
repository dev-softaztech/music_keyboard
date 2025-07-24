class MusicalNote {
  final String pitch; // e.g., C, D, E
  final int octave; // e.g., 4 (Middle C is in octave 4)
  final NoteType type; // e.g., Whole, Half, Quarter, Eighth, Sixteenth
  bool isConnected; // Whether this note is connected to others
  bool isTiedToNext;
  bool isCrescendoStart;
  bool isDecrescendoStart;
  int? crescendoEndIndex;
  int? decrescendoEndIndex;
  final String unicodeCharacter;
  final String accidentalCharacter; // Unicode character for the accidental
  int? slurEndIndex;
  double noteY;
  double duration; // Duration value for bar line calculation
  String topTimeSignatureCharacter;
  String bottomTimeSignatureCharacter;

  MusicalNote(
      {required this.pitch,
      required this.octave,
      required this.type,
      this.isConnected = false,
      this.isTiedToNext = false,
      this.isCrescendoStart = false,
      this.isDecrescendoStart = false,
      this.crescendoEndIndex,
      this.decrescendoEndIndex,
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
        isCrescendoStart: isCrescendoStart,
        isDecrescendoStart: isDecrescendoStart,
        crescendoEndIndex: crescendoEndIndex,
        decrescendoEndIndex: decrescendoEndIndex,
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
