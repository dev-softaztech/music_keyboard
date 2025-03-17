import 'package:music_keyboard/models/music_note.dart';

// Map the Unicode character to a NoteType
NoteType mapUnicodeToNoteType(String unicodeCharacter) {
  const unicodeMap = {
    '\ue1dd': NoteType.sixtyFourth,
    '\ue1db': NoteType.thirtySecond,
    '\ue1d9': NoteType.sixteenth,
    '\ue1d7': NoteType.eighth,
    '\ue1d5': NoteType.quarter,
    '\ue1d3': NoteType.half,
    '\ue1d2': NoteType.whole,
  };

  return unicodeMap[unicodeCharacter] ?? NoteType.quarter; // Default to Quarter
}
