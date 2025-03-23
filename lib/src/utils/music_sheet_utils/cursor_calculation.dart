import 'package:music_keyboard/models/music_note.dart';

double calculateCursorPosition(
    MusicalNote note, int rowSpacing, int clefCount, int index) {
  double noteX = 0;

  if (note.type == NoteType.clef) {
    noteX = 25 + (26 * index) + 10;
  } else {
    noteX = 25 + (rowSpacing * index) + 10;
    noteX = noteX - (clefCount * rowSpacing);
    noteX = noteX + (26 * clefCount);
  }

  return noteX;
}
