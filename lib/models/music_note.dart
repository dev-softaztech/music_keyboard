class MusicalNote {
  final String pitch; // e.g., C, D, E
  final int octave; // e.g., 4 (Middle C is in octave 4)
  final NoteType type; // e.g., Whole, Half, Quarter, Eighth, Sixteenth
  bool isBeamed; // Whether this note is connected to others
  bool isTiedToNext;
  bool isCrescendoStart;
  bool isDecrescendoStart;
  int? crescendoEndIndex;
  int? decrescendoEndIndex;
  final String unicodeCharacter;
  final String accidentalCharacter; // Unicode character for the accidental
  int? slurEndIndex;
  double noteY;
  bool? isUpsideDown;
  double duration; // Duration value for bar line calculation
  String topTimeSignatureCharacter;
  String bottomTimeSignatureCharacter;
  String dynamicCharacter;
  String accentCharacter;
  bool isTriplet;
  double tempoNumber;
  bool swing;
  String swingText;
  String rehearsalMarking;
  String keySignatureName;
  String keySignatureClefType;
  String clefType; // 'Treble', 'Bass', 'Alto', 'Tenor'

  MusicalNote(
      {required this.pitch,
      required this.octave,
      required this.type,
      this.isBeamed = false,
      this.isTiedToNext = false,
      this.isCrescendoStart = false,
      this.isDecrescendoStart = false,
      this.crescendoEndIndex,
      this.decrescendoEndIndex,
      this.slurEndIndex,
      this.unicodeCharacter = "",
      this.accidentalCharacter = "",
      this.noteY = 0.0,
      this.isUpsideDown = null,
      this.duration = 0.0,
      this.topTimeSignatureCharacter = "",
      this.bottomTimeSignatureCharacter = "",
      this.dynamicCharacter = "",
      this.accentCharacter = "",
      this.isTriplet = false,
      this.tempoNumber = 0.0,
      this.swing = false,
      this.swingText = "",
      this.rehearsalMarking = "",
      this.keySignatureName = "",
      this.keySignatureClefType = "",
      this.clefType = ""});

  MusicalNote copy() {
    return MusicalNote(
        pitch: pitch,
        octave: octave,
        type: type,
        isBeamed: isBeamed,
        isTiedToNext: isTiedToNext,
        isCrescendoStart: isCrescendoStart,
        isDecrescendoStart: isDecrescendoStart,
        crescendoEndIndex: crescendoEndIndex,
        decrescendoEndIndex: decrescendoEndIndex,
        slurEndIndex: slurEndIndex,
        unicodeCharacter: unicodeCharacter,
        accidentalCharacter: accidentalCharacter,
        noteY: noteY,
        isUpsideDown: isUpsideDown,
        duration: duration,
        topTimeSignatureCharacter: topTimeSignatureCharacter,
        bottomTimeSignatureCharacter: bottomTimeSignatureCharacter,
        dynamicCharacter: dynamicCharacter,
        accentCharacter: accentCharacter,
        isTriplet: isTriplet,
        tempoNumber: tempoNumber,
        swing: swing,
        swingText: swingText,
        rehearsalMarking: rehearsalMarking,
        keySignatureName: keySignatureName,
        keySignatureClefType: keySignatureClefType,
        clefType: clefType);
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
  timeSignature,
  space,
  keySignature
}
