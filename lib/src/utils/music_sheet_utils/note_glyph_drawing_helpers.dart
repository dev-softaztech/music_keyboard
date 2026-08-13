import 'package:flutter/material.dart';
import 'package:music_keyboard/models/keyboard_type.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/beam_group_helpers.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/guitar_tab_drawing_helpers.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/chord_drawing_helpers.dart';

void drawNote(
    Canvas canvas,
    Paint paint,
    MusicalNote note,
    double lineSpacing,
    double staffTop,
    double noteX,
    List<MusicalNote> notes,
    int index,
    double noteSpacing,
    Color noteColour,
    KeyboardType keyboardType) {
  if (note.type == NoteType.clef || note.type == NoteType.bar) {
    drawClefKey(canvas, paint, note, lineSpacing, staffTop, noteX, notes, index,
        noteColour, keyboardType);
    return;
  } else if (note.type == NoteType.timeSignature) {
    drawTimeSignatureKey(canvas, paint, note, lineSpacing, staffTop, noteX,
        notes, index, noteColour);
  } else if (note.type == NoteType.rest) {
    drawRestKey(canvas, paint, note, lineSpacing, staffTop, noteX, notes, index,
        noteColour);
  } else if (note.type == NoteType.space) {
    return;
  } else if (note.type == NoteType.fret) {
    drawGuitarTabFrets(canvas, note, lineSpacing, staffTop, noteX, noteColour);
    return;
  } else if (note.type == NoteType.chord) {
    drawChordNotes(canvas, paint, note, lineSpacing, staffTop, noteX, notes,
        index, noteSpacing, noteColour);
    return;
  } else {
    drawNoteKey(canvas, paint, note, lineSpacing, staffTop, noteX, notes, index,
        note.noteY, noteSpacing, noteColour);
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
    Color noteColour,
    KeyboardType keyboardType) {
  var fontSize = 40.0;
  if (note.unicodeCharacter == "\uF40C") fontSize = 35;
  if (keyboardType == KeyboardType.guitarTab) fontSize = 50;

  final textPainter = TextPainter(
    text: TextSpan(
      text: note.unicodeCharacter,
      style: TextStyle(
        fontFamily: 'Bravura',
        fontSize: fontSize,
        color: noteColour,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  textPainter.layout();
  final offsetX = noteX - textPainter.width / 2;
  double offsetY = staffTop - (lineSpacing * 4) - 1;

  if (note.unicodeCharacter == "\uf472") offsetY = offsetY - 10;
  if (note.unicodeCharacter == "\uf474") offsetY = offsetY - 30;
  if (note.unicodeCharacter == "\uf473") {
    if (note.clefType == "Tenor") {
      offsetY = offsetY - 30; // Tenor clef: -10 pixels compared to other notes
    } else {
      offsetY = offsetY - 20; // Alto clef (default)
    }
  }
  if (note.unicodeCharacter == "\ue08a" || note.unicodeCharacter == "\ue08b") {
    offsetY = offsetY - 20;
  }

  if (note.unicodeCharacter == "\uF40C") offsetY = offsetY - 4;

  if (keyboardType == KeyboardType.guitarTab) offsetY = offsetY - 10;

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
  if (note.topTimeSignatureCharacter == '\uE08A') {
    final cTimeSignatureTextPainter = TextPainter(
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

    cTimeSignatureTextPainter.layout();

    final offsetX = noteX - cTimeSignatureTextPainter.width / 2;
    double offsetY = staffTop - 60;

    cTimeSignatureTextPainter.paint(canvas, Offset(offsetX, offsetY));
  } else {
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

    final offsetXTop = noteX - textPainterTop.width / 2;
    double offsetY = staffTop - (lineSpacing * 4) - 1;
    textPainterTop.paint(canvas, Offset(offsetXTop, offsetY));

    final offsetXBottom = noteX - textPainterBottom.width / 2;

    textPainterBottom.paint(canvas, Offset(offsetXBottom, offsetY));
  }
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
      text: note.unicodeCharacter,
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
    double noteSpacing,
    Color noteColour,
    {List<MusicalNote>? beamedGroupOverride,
    bool? firstNoteUpsideDownOverride,
    double? beamedGroupHighestYOverride,
    double? beamedGroupLowestYOverride,
    bool? isFirstNoteInGroupListOverride,
    bool? doesGroupContain32ndOr64thNoteOverride}) {
  final double noteRadius = 8.0;
  double stemHeight = 35.0;
  double noteWidth = 10;
  double beamedGroupHighestY = 0.0;
  double beamedGroupLowestY = 0.0;
  bool firstNoteUpsideDown = false;
  List<MusicalNote> beamedNotesGroup = [];
  bool isFirstNoteInGroupList = false;
  bool isABeamedNote = false;
  bool doesGroupContain32ndOr64thNote = false;
  final double staffCenter = staffTop + (lineSpacing * 2);

  if (note.type == NoteType.eighth ||
      note.type == NoteType.sixteenth ||
      note.type == NoteType.thirtySecond ||
      note.type == NoteType.sixtyFourth) {
    isABeamedNote = true;
  }

  if (isABeamedNote && (note.isBeamed || beamedGroupOverride != null)) {
    if (beamedGroupOverride != null) {
      beamedNotesGroup = beamedGroupOverride;
      isFirstNoteInGroupList = isFirstNoteInGroupListOverride ?? false;
      beamedGroupHighestY = beamedGroupHighestYOverride ?? 0.0;
      beamedGroupLowestY = beamedGroupLowestYOverride ?? 0.0;
      firstNoteUpsideDown = firstNoteUpsideDownOverride ?? false;
      doesGroupContain32ndOr64thNote =
          doesGroupContain32ndOr64thNoteOverride ?? false;
    } else {
      final chordGroupResult = getBeamedChordGroup(index, notes);
      final List<MusicalNote> mixedGroup = chordGroupResult.notesGroup;
      isFirstNoteInGroupList = chordGroupResult.isFirst;

      final MusicalNote firstEntry = mixedGroup.first;
      if (firstEntry.isUpsideDown != null) {
        firstNoteUpsideDown = firstEntry.isUpsideDown!;
      } else if (firstEntry.type == NoteType.chord &&
          firstEntry.childNotes != null &&
          firstEntry.childNotes!.isNotEmpty) {
        final double firstChildY = calculateNoteYMainSheet(
            firstEntry.childNotes!.first.pitch,
            firstEntry.childNotes!.first.octave,
            lineSpacing,
            staffTop);
        firstNoteUpsideDown = firstChildY <= staffCenter;
      } else {
        final double firstY = calculateNoteYMainSheet(
            firstEntry.pitch, firstEntry.octave, lineSpacing, staffTop);
        firstNoteUpsideDown = firstY <= staffCenter;
      }

      for (final entry in mixedGroup) {
        MusicalNote? representative;
        if (entry.type == NoteType.chord) {
          representative = getExtremalChildNote(
              entry, firstNoteUpsideDown, lineSpacing, staffTop);
        } else {
          representative = entry;
        }
        if (representative == null) continue;
        beamedNotesGroup.add(representative);

        final double repY = calculateNoteYMainSheet(
            representative.pitch, representative.octave, lineSpacing, staffTop);
        if (beamedGroupHighestY == 0 || repY < beamedGroupHighestY) {
          beamedGroupHighestY = repY;
        }
        if (beamedGroupLowestY == 0 || repY > beamedGroupLowestY) {
          beamedGroupLowestY = repY;
        }
        if (representative.type == NoteType.thirtySecond ||
            representative.type == NoteType.sixtyFourth) {
          doesGroupContain32ndOr64thNote = true;
        }
      }
    }
  }

  // Draw accidental if present
  if (note.accidentalCharacter.isNotEmpty) {
    if (note.accidentalCharacter == 'dotted_rest') {
      final Paint handlePaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(noteX + 15, noteY - 2.5), 2, handlePaint);
    } else {
      final accidentalPainter = TextPainter(
        text: TextSpan(
          text: note.accidentalCharacter,
          style: TextStyle(
            fontFamily: 'Bravura',
            fontSize: 30,
            color: noteColour,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      accidentalPainter.layout();

      final accidentalX = noteX - (accidentalPainter.width / 2) - 15;
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
          fontFamily: 'Bravura',
          fontSize: 35,
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

    if ((note.isBeamed || beamedGroupOverride != null) &&
        doesGroupContain32ndOr64thNote) {
      stemHeight = stemHeight + 10;
    }

    if (isABeamedNote && (note.isBeamed || beamedGroupOverride != null)) {
      if (!firstNoteUpsideDown) {
        stemHeight = (noteY - beamedGroupHighestY) + stemHeight;
      }
      if (firstNoteUpsideDown) {
        stemHeight = (beamedGroupLowestY - noteY) + stemHeight;
      }
    }

    double stemX = 0.0;

    final bool stemGoesUp = beamedGroupOverride != null
        ? !firstNoteUpsideDown
        : ((note.isBeamed && !firstNoteUpsideDown) ||
            (note.isUpsideDown == false &&
                !(note.isBeamed && firstNoteUpsideDown)));

    if (stemGoesUp) {
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

    if (isABeamedNote &&
        beamedNotesGroup.length > 1 &&
        !isFirstNoteInGroupList) {
      var stemTopY =
          firstNoteUpsideDown ? noteY + stemHeight - 3 : noteY - stemHeight + 3;
      drawBeamedNotes(canvas, paint, note, stemX, stemTopY, firstNoteUpsideDown,
          noteSpacing);
    }
  }

  if ((note.type == NoteType.eighth ||
          note.type == NoteType.sixteenth ||
          note.type == NoteType.thirtySecond ||
          note.type == NoteType.sixtyFourth) &&
      beamedNotesGroup.length <= 1) {
    String flagCharacter = "";
    double flagY = note.isUpsideDown == false
        ? (noteY - stemHeight - 64)
        : (noteY + stemHeight - 68);

    switch (note.type) {
      case NoteType.eighth:
        flagCharacter = note.isUpsideDown == false ? '\uE240' : '\uE241';
        break;
      case NoteType.sixteenth:
        flagCharacter = note.isUpsideDown == false ? '\uE242' : '\uE243';
        break;
      case NoteType.thirtySecond:
        flagCharacter = note.isUpsideDown == false ? '\ue244' : '\uE245';
        break;
      case NoteType.sixtyFourth:
        flagCharacter = note.isUpsideDown == false ? '\ue246' : '\uE247';
        break;
      default:
        flagCharacter = note.isUpsideDown == false ? '\uE240' : '\uE241';
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

    double flagX = note.isUpsideDown == false
        ? (noteX + noteRadius - 3.8)
        : (noteX - noteRadius + 2.2);

    textPainter.paint(canvas, Offset(flagX, flagY));
  }

  drawLedgerLines(
      canvas, paint, noteY, noteX, noteWidth, lineSpacing, staffTop);
}

void drawBeamedNotes(Canvas canvas, Paint paint, MusicalNote note, double stemX,
    double stemTopY, bool firstNoteUpsideDown, double noteSpacing) {
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

void drawLedgerLines(Canvas canvas, Paint paint, double noteY, double noteX,
    double noteWidth, double lineSpacing, double staffTop) {
  final double staffBottom = staffTop + (4 * lineSpacing);

  if (noteY < staffTop) {
    for (double y = staffTop - lineSpacing; y >= noteY; y -= lineSpacing) {
      canvas.drawLine(
        Offset(noteX - (noteWidth / 2) - 3, y),
        Offset(noteX + (noteWidth / 2) + 3, y),
        paint..strokeWidth = 1.0,
      );
    }
  } else if (noteY > staffBottom) {
    for (double y = staffBottom + lineSpacing; y <= noteY; y += lineSpacing) {
      canvas.drawLine(
        Offset(noteX - (noteWidth / 2) - 3, y),
        Offset(noteX + (noteWidth / 2) + 3, y),
        paint..strokeWidth = 1.0,
      );
    }
  }
}
