import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';

void drawNote(
    Canvas canvas,
    Paint paint,
    MusicalNote note,
    double lineSpacing,
    double staffTop,
    double noteX,
    List<MusicalNote> notes,
    int index,
    int noteSpacing,
    Color noteColour) {
  if (note.type == NoteType.clef || note.type == NoteType.bar) {
    drawClefKey(canvas, paint, note, lineSpacing, staffTop, noteX, notes, index,
        noteColour);
    return;
  } else if (note.type == NoteType.timeSignature) {
    drawTimeSignatureKey(canvas, paint, note, lineSpacing, staffTop, noteX,
        notes, index, noteColour);
  } else if (note.type == NoteType.rest) {
    drawRestKey(canvas, paint, note, lineSpacing, staffTop, noteX, notes, index,
        noteColour);
  } else {
    final double noteY =
        calculateNoteYMainSheet(note.pitch, note.octave, lineSpacing, staffTop);
    note.noteY = noteY;
    drawNoteKey(canvas, paint, note, lineSpacing, staffTop, noteX, notes, index,
        noteY, noteSpacing, noteColour);
  }
}

void drawClefKey(
    Canvas canvas,
    Paint paint,
    MusicalNote note,
    double lineSpacing,
    double staffTop,
    double noteX,
    List<MusicalNote> notes,
    int index,
    Color noteColour) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: note.unicodeCharacter,
      style: TextStyle(
        fontFamily: 'Bravura',
        fontSize: 40,
        color: noteColour,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  textPainter.layout();
  final offsetX = noteX - textPainter.width / 2;
  double offsetY = staffTop - (lineSpacing * 4) - 1;

  // Adjust Y position for clefs
  if (note.unicodeCharacter == "\uf472") offsetY = offsetY - 10;
  if (note.unicodeCharacter == "\uf474") offsetY = offsetY - 30;
  if (note.unicodeCharacter == "\uf473") offsetY = offsetY - 20;
  if (note.unicodeCharacter == "\ue08a" || note.unicodeCharacter == "\ue08b") {
    offsetY = offsetY - 20;
  }

  textPainter.paint(canvas, Offset(offsetX, offsetY + 0.5));
}

void drawTimeSignatureKey(
    Canvas canvas,
    Paint paint,
    MusicalNote note,
    double lineSpacing,
    double staffTop,
    double noteX,
    List<MusicalNote> notes,
    int index,
    Color noteColour) {
  final textPainterTop = TextPainter(
    text: TextSpan(
      text: note.topTimeSignatureCharacter,
      style: TextStyle(
        fontFamily: 'Bravura',
        fontSize: 40,
        color: noteColour,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  final textPainterBottom = TextPainter(
    text: TextSpan(
      text: note.bottomTimeSignatureCharacter,
      style: TextStyle(
        fontFamily: 'Bravura',
        fontSize: 40,
        color: noteColour,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  textPainterTop.layout();
  textPainterBottom.layout();

  final offsetX = noteX - textPainterTop.width / 2;
  double offsetY = staffTop - (lineSpacing * 4) - 1;

  textPainterTop.paint(canvas, Offset(offsetX, offsetY + 0.5));
  textPainterBottom.paint(canvas, Offset(offsetX, offsetY + 0.5));
}

void drawRestKey(
    Canvas canvas,
    Paint paint,
    MusicalNote note,
    double lineSpacing,
    double staffTop,
    double noteX,
    List<MusicalNote> notes,
    int index,
    Color noteColour) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: note.unicodeCharacter, // Unicode character for whole note
      style: TextStyle(
        fontFamily: 'Bravura', // Use Bravura font
        fontSize: 36, // Adjust font size as needed
        color: noteColour,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  textPainter.layout();
  final offsetX = noteX - textPainter.width / 2;
  final offsetY = (staffTop + (lineSpacing * 2)) - textPainter.height / 2;
  textPainter.paint(canvas, Offset(offsetX, offsetY + 0.5));
}

void drawNoteKey(
    Canvas canvas,
    Paint paint,
    MusicalNote note,
    double lineSpacing,
    double staffTop,
    double noteX,
    List<MusicalNote> notes,
    int index,
    double noteY,
    int noteSpacing,
    Color noteColour) {
  final double noteRadius = 8.0; // Radius of the note head
  double stemHeight = 35.0; // Stem height for all notes
  double noteWidth = 10;
  double connectedGroupHighestY = 0.0;
  double connectedGroupLowestY = 0.0;
  bool firstNoteUpsideDown = false;
  List<MusicalNote> connectedNotesGroup = [];
  bool isFirstNoteInGroupList = false;
  bool isAConnectedNote = false;
  bool doesGroupContain32ndOr64thNote = false;
  final double sheetCenter = staffTop + (lineSpacing * 2);
  note.isUpsideDown = noteY < sheetCenter;

  if (note.type == NoteType.eighth ||
      note.type == NoteType.sixteenth ||
      note.type == NoteType.thirtySecond ||
      note.type == NoteType.sixtyFourth) {
    isAConnectedNote = true;
  }

  if (isAConnectedNote && note.isConnected) {
    ({bool isFirst, List<MusicalNote> notesGroup}) notesGroup =
        getConnectedNotesGroup(index, notes);
    connectedNotesGroup = notesGroup.notesGroup;
    isFirstNoteInGroupList = notesGroup.isFirst;

    ({
      double highestY,
      double lowestY,
      double firstNoteY,
      bool doesGroupContain32ndOr64thNote
    }) notesGroupYs = getConnectedNotesGroupHighestY(
        connectedNotesGroup, lineSpacing, staffTop);

    connectedGroupHighestY = notesGroupYs.highestY;
    connectedGroupLowestY = notesGroupYs.lowestY;
    firstNoteUpsideDown = notesGroupYs.firstNoteY < sheetCenter;
    doesGroupContain32ndOr64thNote =
        notesGroupYs.doesGroupContain32ndOr64thNote;
  }

  // Draw accidental if present
  if (note.accidentalCharacter.isNotEmpty) {
    if (note.accidentalCharacter == 'dotted_rest') {
      final Paint handlePaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(noteX + 15, noteY), 2, handlePaint);
    } else {
      final accidentalPainter = TextPainter(
        text: TextSpan(
          text: note.accidentalCharacter,
          style: TextStyle(
            fontFamily: 'Bravura',
            fontSize: 30, // Slightly smaller than the note
            color: noteColour,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      accidentalPainter.layout();

      final accidentalX = noteX -
          (accidentalPainter.width / 2) -
          15; // Position to the left of the note
      final accidentalY = noteY - (accidentalPainter.height / 2);
      accidentalPainter.paint(canvas, Offset(accidentalX, accidentalY));
    }
  }

  // Draw note head
  if (note.type == NoteType.whole) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '\uE1D2', // Unicode character for whole note
        style: TextStyle(
          fontFamily: 'Bravura', // Use Bravura font
          fontSize: 35, // Adjust font size as needed
          color: noteColour,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    final offsetX = noteX - textPainter.width / 2;
    final offsetY = noteY - textPainter.height / 2;
    textPainter.paint(canvas, Offset(offsetX, offsetY));
    noteWidth = textPainter.width;
  } else {
    final String noteHeadCharacter =
        (note.type == NoteType.half) ? '\uF4BD' : '\uf4be';

    final textPainter = TextPainter(
      text: TextSpan(
        text: noteHeadCharacter,
        style: TextStyle(
          fontFamily: 'Bravura',
          fontSize: 36,
          color: noteColour,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    final offsetX = noteX - textPainter.width / 2;
    final offsetY = noteY - textPainter.height / 2;
    textPainter.paint(canvas, Offset(offsetX, offsetY));
    noteWidth = textPainter.width;

    if (note.isConnected && doesGroupContain32ndOr64thNote) {
      stemHeight = stemHeight + 10;
    }

    if (isAConnectedNote && note.isConnected) {
      if (!firstNoteUpsideDown) {
        stemHeight = (noteY - connectedGroupHighestY) + stemHeight;
      }
      if (firstNoteUpsideDown) {
        stemHeight = (connectedGroupLowestY - noteY) + stemHeight;
      }
    }

    double stemX = 0.0;

    if ((note.isConnected && !firstNoteUpsideDown) ||
        (!note.isUpsideDown && !(note.isConnected && firstNoteUpsideDown))) {
      stemX = noteX + 5.0;
      canvas.drawLine(
        Offset(stemX, noteY - 1),
        Offset(stemX, noteY - stemHeight + 1),
        paint..strokeWidth = 1.50,
      );
    } else {
      stemX = noteX - 5.0;
      canvas.drawLine(
        Offset(stemX, noteY + 1),
        Offset(stemX, noteY + stemHeight - 1),
        paint..strokeWidth = 1.50,
      );
    }

    if (isAConnectedNote &&
        connectedNotesGroup.length > 1 &&
        !isFirstNoteInGroupList) {
      var stemTopY =
          firstNoteUpsideDown ? noteY + stemHeight - 3 : noteY - stemHeight + 3;
      drawConnectedNotes(canvas, paint, note, stemX, stemTopY,
          firstNoteUpsideDown, noteSpacing);
    }
  }

  if ((note.type == NoteType.eighth ||
          note.type == NoteType.sixteenth ||
          note.type == NoteType.thirtySecond ||
          note.type == NoteType.sixtyFourth) &&
      connectedNotesGroup.length <= 1) {
    String flagCharacter = "";
    double flagY = !note.isUpsideDown
        ? (noteY - stemHeight - 64)
        : (noteY + stemHeight - 68);

    switch (note.type) {
      case NoteType.eighth:
        flagCharacter = !note.isUpsideDown ? '\uE240' : '\uE241';
        break;
      case NoteType.sixteenth:
        flagCharacter = !note.isUpsideDown ? '\uE242' : '\uE243';
        break;
      case NoteType.thirtySecond:
        flagCharacter = !note.isUpsideDown ? '\ue244' : '\uE245';
        break;
      case NoteType.sixtyFourth:
        flagCharacter = !note.isUpsideDown ? '\ue246' : '\uE247';
        break;
      default:
        flagCharacter = !note.isUpsideDown ? '\uE240' : '\uE241';
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: flagCharacter,
        style: TextStyle(
          fontFamily: 'Bravura',
          fontSize: 34.0,
          color: noteColour,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    double flagX = !note.isUpsideDown
        ? (noteX + noteRadius - 4)
        : (noteX - noteRadius + 2);

    textPainter.paint(canvas, Offset(flagX, flagY));
  }

  drawLedgerLines(
      canvas, paint, noteY, noteX, noteWidth, lineSpacing, staffTop);
}

void drawConnectedNotes(Canvas canvas, Paint paint, MusicalNote note,
    double stemX, double stemTopY, bool firstNoteUpsideDown, int noteSpacing) {
  canvas.drawLine(
    Offset(stemX, stemTopY),
    Offset(stemX - noteSpacing, stemTopY),
    paint..strokeWidth = 4.0,
  );

  if (note.type == NoteType.sixteenth ||
      note.type == NoteType.thirtySecond ||
      note.type == NoteType.sixtyFourth) {
    double y = firstNoteUpsideDown ? stemTopY - 7 : stemTopY + 7;

    canvas.drawLine(
      Offset(stemX, y),
      Offset(stemX - noteSpacing, y),
      paint..strokeWidth = 4.0,
    );
  }

  if (note.type == NoteType.thirtySecond || note.type == NoteType.sixtyFourth) {
    double y = firstNoteUpsideDown ? stemTopY - 14 : stemTopY + 14;

    canvas.drawLine(
      Offset(stemX, y),
      Offset(stemX - noteSpacing, y),
      paint..strokeWidth = 4.0,
    );
  }
  if (note.type == NoteType.sixtyFourth) {
    double y = firstNoteUpsideDown ? stemTopY - 21 : stemTopY + 21;

    canvas.drawLine(
      Offset(stemX, y),
      Offset(stemX - noteSpacing, y),
      paint..strokeWidth = 4.0,
    );
  }
}

({List<MusicalNote> notesGroup, bool isFirst}) getConnectedNotesGroup(
    int index, List<MusicalNote> notes) {
  MusicalNote firstNote = notes[index];
  List<MusicalNote> connectedNotesGroup = [firstNote];

  // Traverse backwards to find connected notes before the index
  for (int i = index - 1; i >= 0; i--) {
    if (notes[i].isConnected &&
        (notes[i].type == NoteType.eighth ||
            notes[i].type == NoteType.sixteenth ||
            notes[i].type == NoteType.thirtySecond ||
            notes[i].type == NoteType.sixtyFourth)) {
      // && notes[i].type == firstNote.type) {
      connectedNotesGroup.insert(0, notes[i]); // Insert at the beginning
    } else {
      break;
    }
  }

  // Traverse forwards to find connected notes after the index
  for (int i = index + 1; i < notes.length; i++) {
    if (notes[i].isConnected &&
        (notes[i].type == NoteType.eighth ||
            notes[i].type == NoteType.sixteenth ||
            notes[i].type == NoteType.thirtySecond ||
            notes[i].type == NoteType.sixtyFourth)) {
      // && notes[i].type == firstNote.type) {
      connectedNotesGroup.add(notes[i]); // Append normally
    } else {
      break;
    }
  }
/*
  // **New logic to split into groups of 4**
  int totalNotes = connectedNotesGroup.length;
  int groupIndex =
      connectedNotesGroup.indexOf(firstNote) ~/ 4; // Get group index
  int startIndex = groupIndex * 4; // Start of this sub-group
  int endIndex = startIndex + 4; // End of this sub-group

  if (endIndex > totalNotes) endIndex = totalNotes; // Avoid overflow

  // Extract only the sub-group of 4
  List<MusicalNote> subGroup =
      connectedNotesGroup.sublist(startIndex, endIndex);
*/
  // Check if this note is the last in the **sub-group**

  bool isFirst = connectedNotesGroup.first == firstNote;

  return (notesGroup: connectedNotesGroup, isFirst: isFirst);
}

({
  double highestY,
  double lowestY,
  double firstNoteY,
  bool doesGroupContain32ndOr64thNote
}) getConnectedNotesGroupHighestY(
    List<MusicalNote> notes, double lineSpacing, double staffCenter) {
  double highestY = 0;
  double lowestY = 0;
  bool doesGroupContain32ndOr64thNote = false;

  for (final note in notes) {
    final double noteY = calculateNoteYMainSheet(
        note.pitch, note.octave, lineSpacing, staffCenter);

    if (highestY == 0) highestY = noteY;
    if (noteY < highestY) highestY = noteY;

    if (lowestY == 0) lowestY = noteY;
    if (noteY > lowestY) lowestY = noteY;

    if (note.type == NoteType.thirtySecond ||
        note.type == NoteType.sixtyFourth) {
      doesGroupContain32ndOr64thNote = true;
    }
  }

  final double firstNoteY = calculateNoteYMainSheet(
      notes[0].pitch, notes[0].octave, lineSpacing, staffCenter);

  return (
    highestY: highestY,
    lowestY: lowestY,
    firstNoteY: firstNoteY,
    doesGroupContain32ndOr64thNote: doesGroupContain32ndOr64thNote
  );
}

void drawLedgerLines(Canvas canvas, Paint paint, double noteY, double noteX,
    double noteWidth, double lineSpacing, double staffTop) {
  final double staffBottom = staffTop + (4 * lineSpacing); // Bottom staff line

  // Determine if the note is above or below the staff
  if (noteY < staffTop) {
    // Draw ledger lines **above** the staff
    for (double y = staffTop - lineSpacing; y >= noteY; y -= lineSpacing) {
      canvas.drawLine(
        Offset(noteX - (noteWidth / 2) - 7, y),
        Offset(noteX + (noteWidth / 2) + 7, y),
        paint..strokeWidth = 1.0,
      );
    }
  } else if (noteY > staffBottom) {
    // Draw ledger lines **below** the staff
    for (double y = staffBottom + lineSpacing; y <= noteY; y += lineSpacing) {
      canvas.drawLine(
        Offset(noteX - (noteWidth / 2) - 7, y),
        Offset(noteX + (noteWidth / 2) + 7, y),
        paint..strokeWidth = 1.0,
      );
    }
  }
}
