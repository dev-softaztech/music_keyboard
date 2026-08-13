import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';

({List<MusicalNote> notesGroup, bool isFirst}) getBeamedNotesGroup(
    int index, List<MusicalNote> notes) {
  MusicalNote firstNote = notes[index];
  List<MusicalNote> beamedNotesGroup = [firstNote];

  // Traverse backwards to find Beamed notes before the index
  for (int i = index - 1; i >= 0; i--) {
    if (notes[i].isBeamed &&
        (notes[i].type == NoteType.eighth ||
            notes[i].type == NoteType.sixteenth ||
            notes[i].type == NoteType.thirtySecond ||
            notes[i].type == NoteType.sixtyFourth) &&
        notes[i].type != NoteType.space) {
      // && notes[i].type == firstNote.type) {
      beamedNotesGroup.insert(0, notes[i]); // Insert at the beginning
    } else {
      break;
    }
  }

  // Traverse forwards to find Beamed notes after the index
  for (int i = index + 1; i < notes.length; i++) {
    if (notes[i].isBeamed &&
        (notes[i].type == NoteType.eighth ||
            notes[i].type == NoteType.sixteenth ||
            notes[i].type == NoteType.thirtySecond ||
            notes[i].type == NoteType.sixtyFourth) &&
        notes[i].type != NoteType.space) {
      beamedNotesGroup.add(notes[i]);
    } else {
      break;
    }
  }

  bool isFirst = beamedNotesGroup.first == firstNote;

  return (notesGroup: beamedNotesGroup, isFirst: isFirst);
}

({
  double highestY,
  double lowestY,
  double firstNoteY,
  bool doesGroupContain32ndOr64thNote
}) getBeamedNotesGroupHighestY(List<MusicalNote> notes, double lineSpacing,
    double staffTop, double staffCenter) {
  double highestY = 0;
  double lowestY = 0;
  bool doesGroupContain32ndOr64thNote = false;

  for (final note in notes) {
    final double noteY =
        calculateNoteYMainSheet(note.pitch, note.octave, lineSpacing, staffTop);

    if (highestY == 0) highestY = noteY;
    if (noteY < highestY) highestY = noteY;

    if (lowestY == 0) lowestY = noteY;
    if (noteY > lowestY) lowestY = noteY;

    if (note.type == NoteType.thirtySecond ||
        note.type == NoteType.sixtyFourth) {
      doesGroupContain32ndOr64thNote = true;
    }
  }

  double firstNoteY = calculateNoteYMainSheet(
      notes[0].pitch, notes[0].octave, lineSpacing, staffTop);

  if (notes[0].isUpsideDown == true) {
    firstNoteY = staffCenter - 1;
  } else {
    firstNoteY = staffCenter + 1;
  }

  return (
    highestY: highestY,
    lowestY: lowestY,
    firstNoteY: firstNoteY,
    doesGroupContain32ndOr64thNote: doesGroupContain32ndOr64thNote
  );
}

({List<MusicalNote> notesGroup, bool isFirst}) getBeamedChordGroup(
    int index, List<MusicalNote> notes) {
  MusicalNote firstNote = notes[index];
  List<MusicalNote> beamedGroup = [firstNote];

  bool isBeamable(MusicalNote n) {
    if (!n.isBeamed || n.type == NoteType.space) return false;
    if (n.type == NoteType.chord) {
      return n.childNotes?.any((c) =>
              c.type == NoteType.eighth ||
              c.type == NoteType.sixteenth ||
              c.type == NoteType.thirtySecond ||
              c.type == NoteType.sixtyFourth) ??
          false;
    }
    return n.type == NoteType.eighth ||
        n.type == NoteType.sixteenth ||
        n.type == NoteType.thirtySecond ||
        n.type == NoteType.sixtyFourth;
  }

  for (int i = index - 1; i >= 0; i--) {
    if (isBeamable(notes[i])) {
      beamedGroup.insert(0, notes[i]);
    } else {
      break;
    }
  }

  for (int i = index + 1; i < notes.length; i++) {
    if (isBeamable(notes[i])) {
      beamedGroup.add(notes[i]);
    } else {
      break;
    }
  }

  bool isFirst = beamedGroup.first == firstNote;
  return (notesGroup: beamedGroup, isFirst: isFirst);
}

MusicalNote? getExtremalChildNote(
    MusicalNote chord, bool stemDown, double lineSpacing, double staffTop) {
  if (chord.childNotes == null || chord.childNotes!.isEmpty) return null;

  MusicalNote? extremal;
  double extremalY = 0;

  for (var child in chord.childNotes!) {
    final double y = calculateNoteYMainSheet(
        child.pitch, child.octave, lineSpacing, staffTop);
    if (extremalY == 0) {
      extremalY = y;
      extremal = child;
    } else if (stemDown && y > extremalY) {
      extremalY = y;
      extremal = child;
    } else if (!stemDown && y < extremalY) {
      extremalY = y;
      extremal = child;
    }
  }
  return extremal;
}
