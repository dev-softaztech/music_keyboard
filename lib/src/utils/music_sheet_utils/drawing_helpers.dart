import 'package:flutter/material.dart';
import 'package:music_keyboard/models/keyboard_type.dart';
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
    // Draw guitar tab fret notes - only draw childNotes, not the parent
    drawGuitarTabFrets(canvas, note, lineSpacing, staffTop, noteX, noteColour);
    return;
  } else if (note.type == NoteType.chord) {
    // Draw each child note at the same X position
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

  // Adjust Y position for clefs
  if (note.unicodeCharacter == "\uf472") offsetY = offsetY - 10;
  if (note.unicodeCharacter == "\uf474") offsetY = offsetY - 30;
  if (note.unicodeCharacter == "\uf473") {
    // Handle Alto vs Tenor clef - both use same unicode but different positioning
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
    double noteSpacing,
    Color noteColour,
    {List<MusicalNote>? beamedGroupOverride,
    bool? firstNoteUpsideDownOverride,
    double? beamedGroupHighestYOverride,
    double? beamedGroupLowestYOverride,
    bool? isFirstNoteInGroupListOverride,
    bool? doesGroupContain32ndOr64thNoteOverride}) {
  final double noteRadius = 8.0; // Radius of the note head
  double stemHeight = 35.0; // Stem height for all notes
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
      // Use pre-computed values supplied by the caller (e.g. drawChordNotes)
      beamedNotesGroup = beamedGroupOverride;
      isFirstNoteInGroupList = isFirstNoteInGroupListOverride ?? false;
      beamedGroupHighestY = beamedGroupHighestYOverride ?? 0.0;
      beamedGroupLowestY = beamedGroupLowestYOverride ?? 0.0;
      firstNoteUpsideDown = firstNoteUpsideDownOverride ?? false;
      doesGroupContain32ndOr64thNote =
          doesGroupContain32ndOr64thNoteOverride ?? false;
    } else {
      ({bool isFirst, List<MusicalNote> notesGroup}) notesGroup =
          getBeamedNotesGroup(index, notes);
      beamedNotesGroup = notesGroup.notesGroup;
      isFirstNoteInGroupList = notesGroup.isFirst;

      ({
        double highestY,
        double lowestY,
        double firstNoteY,
        bool doesGroupContain32ndOr64thNote
      }) notesGroupYs = getBeamedNotesGroupHighestY(
          beamedNotesGroup, lineSpacing, staffTop, staffCenter);

      beamedGroupHighestY = notesGroupYs.highestY;
      beamedGroupLowestY = notesGroupYs.lowestY;
      firstNoteUpsideDown = notesGroupYs.firstNoteY < staffCenter;
      doesGroupContain32ndOr64thNote =
          notesGroupYs.doesGroupContain32ndOr64thNote;
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

    // When beaming overrides are supplied (chord beaming), use firstNoteUpsideDown
    // directly so all child stems follow the group direction.
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

/// Collects the beamed group that contains the note at [index].
/// Unlike [getBeamedNotesGroup], this version also recognises
/// [NoteType.chord] parents whose [MusicalNote.isBeamed] flag is true and
/// whose [MusicalNote.childNotes] contain at least one beamable note type
/// (eighth, sixteenth, thirtySecond, sixtyFourth).  Regular beamed notes are
/// matched as before, so mixed groups work correctly.
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

/// Returns the extremal child note of [chord] that should carry the beamed
/// stem — the one whose stem tip is closest to the beam line.
///
/// * When [stemDown] is **false** (stem up) this is the child with the
///   **smallest Y** on the canvas (highest pitch on the stave).
/// * When [stemDown] is **true**  (stem down) this is the child with the
///   **largest Y** on the canvas (lowest pitch on the stave).
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
      // Stem down → want lowest note (largest canvas Y)
      extremalY = y;
      extremal = child;
    } else if (!stemDown && y < extremalY) {
      // Stem up → want highest note (smallest canvas Y)
      extremalY = y;
      extremal = child;
    }
  }
  return extremal;
}

void drawLedgerLines(Canvas canvas, Paint paint, double noteY, double noteX,
    double noteWidth, double lineSpacing, double staffTop) {
  final double staffBottom = staffTop + (4 * lineSpacing); // Bottom staff line

  // Determine if the note is above or below the staff
  if (noteY < staffTop) {
    // Draw ledger lines **above** the staff
    for (double y = staffTop - lineSpacing; y >= noteY; y -= lineSpacing) {
      canvas.drawLine(
        Offset(noteX - (noteWidth / 2) - 3, y),
        Offset(noteX + (noteWidth / 2) + 3, y),
        paint..strokeWidth = 1.0,
      );
    }
  } else if (noteY > staffBottom) {
    // Draw ledger lines **below** the staff
    for (double y = staffBottom + lineSpacing; y <= noteY; y += lineSpacing) {
      canvas.drawLine(
        Offset(noteX - (noteWidth / 2) - 3, y),
        Offset(noteX + (noteWidth / 2) + 3, y),
        paint..strokeWidth = 1.0,
      );
    }
  }
}

/// Always draw the guitar tab clef symbol (\uF40C) at the start of a row
void drawGuitarTabRowClef(Canvas canvas, double lineSpacing, double staffTop,
    double noteX, Color noteColour) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: '\uF40C',
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
  double offsetY = staffTop - (lineSpacing * 4) - 1;
  offsetY = offsetY - 4;

  textPainter.paint(canvas, Offset(offsetX, offsetY + 0.5));
}

/// Draw guitar tab fret numbers on the staff
/// Only draws childNotes, not the parent chord
void drawGuitarTabFrets(Canvas canvas, MusicalNote parentChord,
    double lineSpacing, double staffTop, double noteX, Color noteColour) {
  // If there are no childNotes, nothing to draw
  if (parentChord.childNotes == null || parentChord.childNotes!.isEmpty) {
    return;
  }

  // For guitar tabs with 6 strings, draw fret numbers on each string line
  // String positions from top to bottom: 0=E, 1=B, 2=G, 3=D, 4=A, 5=E
  for (var childNote in parentChord.childNotes!) {
    // Calculate Y position based on string index (octave field stores string index 0-5)
    double stringY = staffTop + (childNote.octave * lineSpacing);

    // Draw the fret number
    final textPainter = TextPainter(
      text: TextSpan(
        text: childNote.unicodeCharacter, // Fret number as string
        style: TextStyle(
          fontSize: 11,
          //fontWeight: FontWeight.bold,
          color: noteColour,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Center the text on the string line
    final double xPos = noteX - (textPainter.width / 2);
    final double yPos = stringY - (textPainter.height / 2);

    // Draw white background rectangle behind the fret number
    final Paint backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Add slight padding around the text
    final double paddingVertical = 2;
    final double paddingHorizontal = 0.5;
    final Rect backgroundRect = Rect.fromLTRB(
      xPos - paddingHorizontal,
      yPos + paddingVertical,
      xPos + textPainter.width + paddingHorizontal,
      yPos + textPainter.height - paddingVertical,
    );

    canvas.drawRect(backgroundRect, backgroundPaint);

    // Draw the text on top of the white background
    textPainter.paint(canvas, Offset(xPos, yPos));
  }
}

/// Draw all child notes of a NoteType.chord at the same X position.
///
/// When [parentChord.isBeamed] is true and the children have beamable note
/// types (eighth, sixteenth, thirtySecond, sixtyFourth), this function
/// applies the same beaming logic as [drawNoteKey] for regular notes:
///
/// * Only the **extremal** child note — the highest note on the stave for
///   stem-up groups, or the lowest for stem-down groups — receives the
///   extended stem that connects to the shared beam bar.
/// * All other child notes are drawn with a normal-length stem and no flag.
/// * The beam position is determined by examining the extremal child notes
///   across every chord (and regular note) in the beamed group.
void drawChordNotes(
    Canvas canvas,
    Paint paint,
    MusicalNote parentChord,
    double lineSpacing,
    double staffTop,
    double noteX,
    List<MusicalNote> notes,
    int index,
    double noteSpacing,
    Color noteColour) {
  if (parentChord.childNotes == null || parentChord.childNotes!.isEmpty) {
    return;
  }

  final double staffCenter = staffTop + (lineSpacing * 2);

  // Pre-compute Y positions and stem direction for every child note.
  for (var childNote in parentChord.childNotes!) {
    final double y = calculateNoteYMainSheet(
        childNote.pitch, childNote.octave, lineSpacing, staffTop);
    childNote.noteY = y;
    childNote.isUpsideDown ??= y <= staffCenter;
  }

  // Check whether this chord should be drawn with beamed stems.
  final bool hasBeamableChildren = parentChord.childNotes!.any((c) =>
      c.type == NoteType.eighth ||
      c.type == NoteType.sixteenth ||
      c.type == NoteType.thirtySecond ||
      c.type == NoteType.sixtyFourth);

  if (parentChord.isBeamed && hasBeamableChildren) {
    // ── 1. Find the full beamed group in the main notes list ───────────────
    final chordGroupResult = getBeamedChordGroup(index, notes);
    final List<MusicalNote> chordGroup = chordGroupResult.notesGroup;
    final bool isFirstChordInGroup = chordGroupResult.isFirst;

    // ── 2. Determine stem direction from the first entry in the group ───────
    //    Mirror the logic used in getBeamedNotesGroupHighestY: prefer the
    //    explicit isUpsideDown flag, otherwise fall back to staff-centre test.
    final MusicalNote firstInGroup = chordGroup.first;
    bool firstNoteUpsideDown;
    if (firstInGroup.isUpsideDown != null) {
      firstNoteUpsideDown = firstInGroup.isUpsideDown!;
    } else if (firstInGroup.type == NoteType.chord &&
        firstInGroup.childNotes != null &&
        firstInGroup.childNotes!.isNotEmpty) {
      final double firstChildY = calculateNoteYMainSheet(
          firstInGroup.childNotes!.first.pitch,
          firstInGroup.childNotes!.first.octave,
          lineSpacing,
          staffTop);
      firstNoteUpsideDown = firstChildY <= staffCenter;
    } else {
      final double firstY = calculateNoteYMainSheet(
          firstInGroup.pitch, firstInGroup.octave, lineSpacing, staffTop);
      firstNoteUpsideDown = firstY <= staffCenter;
    }

    // ── 3. Build a synthetic beamed group made of one representative note
    //       per entry in the chord group.  For chord parents the representative
    //       is the extremal child; for regular notes it is the note itself.
    //       The synthetic group is used by drawNoteKey to determine stem
    //       extension and to draw the beam bars.
    List<MusicalNote> syntheticGroup = [];
    double beamedGroupHighestY = 0;
    double beamedGroupLowestY = 0;
    bool doesGroupContain32ndOr64thNote = false;

    for (final entry in chordGroup) {
      MusicalNote? representative;
      if (entry.type == NoteType.chord) {
        representative = getExtremalChildNote(
            entry, firstNoteUpsideDown, lineSpacing, staffTop);
      } else {
        representative = entry;
      }
      if (representative == null) continue;

      syntheticGroup.add(representative);

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

    // ── 4. Identify the extremal child of THIS chord ─────────────────────
    final MusicalNote? extremalChild = getExtremalChildNote(
        parentChord, firstNoteUpsideDown, lineSpacing, staffTop);

    // ── 5. Draw every child note ──────────────────────────────────────────
    for (final childNote in parentChord.childNotes!) {
      final double childNoteY = childNote.noteY;
      final bool isExtremal = childNote == extremalChild;

      if (isExtremal && syntheticGroup.isNotEmpty) {
        // Extremal child: extended stem + beam bar (if not first in group).
        drawNoteKey(
          canvas,
          paint,
          childNote,
          lineSpacing,
          staffTop,
          noteX,
          notes,
          index,
          childNoteY,
          noteSpacing,
          noteColour,
          beamedGroupOverride: syntheticGroup,
          firstNoteUpsideDownOverride: firstNoteUpsideDown,
          beamedGroupHighestYOverride: beamedGroupHighestY,
          beamedGroupLowestYOverride: beamedGroupLowestY,
          isFirstNoteInGroupListOverride: isFirstChordInGroup,
          doesGroupContain32ndOr64thNoteOverride:
              doesGroupContain32ndOr64thNote,
        );
      } else {
        // Non-extremal child: normal stem, no flag, no beam bar.
        // Pass a fake 2-note group so drawNoteKey suppresses the flag, and
        // mark it as "first in group" so no beam bar is drawn from here.
        drawNoteKey(
          canvas,
          paint,
          childNote,
          lineSpacing,
          staffTop,
          noteX,
          notes,
          index,
          childNoteY,
          noteSpacing,
          noteColour,
          beamedGroupOverride: [childNote, childNote],
          firstNoteUpsideDownOverride: firstNoteUpsideDown,
          beamedGroupHighestYOverride: childNoteY,
          beamedGroupLowestYOverride: childNoteY,
          isFirstNoteInGroupListOverride: true,
          doesGroupContain32ndOr64thNoteOverride: false,
        );
      }
    }
  } else {
    // Not beamed.
    // For beamable note types (eighth, sixteenth, etc.) only the extremal
    // child — highest note for stem-up chords, lowest for stem-down chords —
    // receives the flag.  All other children have their stems extended so they
    // reach the same height as the flagged note's stem tip, with no flag of
    // their own.
    if (hasBeamableChildren) {
      // Use the first child's isUpsideDown as the chord-wide stem direction.
      final bool chordStemDown =
          parentChord.childNotes!.first.isUpsideDown ?? false;

      final MusicalNote? extremalChild = getExtremalChildNote(
          parentChord, chordStemDown, lineSpacing, staffTop);
      final double extremalChildY = extremalChild != null
          ? calculateNoteYMainSheet(
              extremalChild.pitch, extremalChild.octave, lineSpacing, staffTop)
          : 0;

      for (final childNote in parentChord.childNotes!) {
        final double childNoteY = childNote.noteY;
        final bool isExtremal = childNote == extremalChild;

        if (isExtremal) {
          // Extremal child: drawn normally — it gets the flag and a default
          // 35 px stem in the correct direction.
          drawNoteKey(canvas, paint, childNote, lineSpacing, staffTop, noteX,
              notes, index, childNoteY, noteSpacing, noteColour);
        } else {
          // Non-extremal child: suppress flag and extend the stem so its tip
          // aligns with the extremal child's stem tip.
          //
          // Passing beamedGroupOverride with length > 1 suppresses the flag.
          // Passing extremalChildY as both beamedGroupHighestY and
          // beamedGroupLowestY makes the stem-extension formula produce the
          // correct extra height:
          //   stem-up:   stemHeight = (childNoteY – extremalChildY) + 35
          //   stem-down: stemHeight = (extremalChildY – childNoteY) + 35
          drawNoteKey(
            canvas,
            paint,
            childNote,
            lineSpacing,
            staffTop,
            noteX,
            notes,
            index,
            childNoteY,
            noteSpacing,
            noteColour,
            beamedGroupOverride: [childNote, childNote],
            firstNoteUpsideDownOverride: chordStemDown,
            beamedGroupHighestYOverride: extremalChildY,
            beamedGroupLowestYOverride: extremalChildY,
            isFirstNoteInGroupListOverride: true,
            doesGroupContain32ndOr64thNoteOverride: false,
          );
        }
      }
    } else {
      // No beamable children — draw everything normally.
      for (final childNote in parentChord.childNotes!) {
        drawNoteKey(canvas, paint, childNote, lineSpacing, staffTop, noteX,
            notes, index, childNote.noteY, noteSpacing, noteColour);
      }
    }
  }
}
