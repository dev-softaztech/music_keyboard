const Map<String, double> pitchOffsetsMainSheet = {
  'C': 5.5,
  'D': 5,
  'E': 4.5,
  'F': 4,
  'G': 3.5,
  'A': 3,
  'B': 2.5,
};

// Calculates the Y position of the note based on pitch and octave
double calculateNoteYMainSheet(
    String pitch, int octave, double lineSpacing, double staffTop) {
  final double baseOffset =
      pitchOffsetsMainSheet[pitch]!; // Base offset for the pitch
  final double octaveOffset =
      (4 - octave) * 3.5; // Each octave shifts by 3.5 lines

  return staffTop + (baseOffset + octaveOffset) * lineSpacing;
}

const Map<String, double> pitchOffsetsVerticalKeyboard = {
  'C': 5.5,
  'D': 5,
  'E': 4.5,
  'F': 4,
  'G': 3.5,
  'A': 3,
  'B': 2.5,
};

// Calculates the Y position of the note based on pitch and octave
double calculateNoteYVerticalKeyboard(
    String pitch, int octave, double lineSpacing, double staffCenter) {
  final double baseOffset =
      pitchOffsetsVerticalKeyboard[pitch]!; // Base offset for the pitch
  final double octaveOffset =
      (4 - octave) * 3.5; // Each octave shifts by 3.5 lines

  return staffCenter + (baseOffset + octaveOffset) * lineSpacing;
}
