import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_position_calculator.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/beam_group_helpers.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_glyph_drawing_helpers.dart';

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

  for (var childNote in parentChord.childNotes!) {
    final double y = calculateNoteYMainSheet(
        childNote.pitch, childNote.octave, lineSpacing, staffTop);
    childNote.noteY = y;
    childNote.isUpsideDown ??= false;
  }

  final bool hasBeamableChildren = parentChord.childNotes!.any((c) =>
      c.type == NoteType.eighth ||
      c.type == NoteType.sixteenth ||
      c.type == NoteType.thirtySecond ||
      c.type == NoteType.sixtyFourth);

  if (parentChord.isBeamed && hasBeamableChildren) {
    final chordGroupResult = getBeamedChordGroup(index, notes);
    final List<MusicalNote> chordGroup = chordGroupResult.notesGroup;
    final bool isFirstChordInGroup = chordGroupResult.isFirst;

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

    final MusicalNote? extremalChild = getExtremalChildNote(
        parentChord, firstNoteUpsideDown, lineSpacing, staffTop);

    for (final childNote in parentChord.childNotes!) {
      final double childNoteY = childNote.noteY;
      final bool isExtremal = childNote == extremalChild;

      if (isExtremal && syntheticGroup.isNotEmpty) {
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
          beamedGroupHighestYOverride: beamedGroupHighestY,
          beamedGroupLowestYOverride: beamedGroupLowestY,
          isFirstNoteInGroupListOverride: true,
          doesGroupContain32ndOr64thNoteOverride: false,
        );
      }
    }
  } else {
    if (hasBeamableChildren) {
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
          drawNoteKey(canvas, paint, childNote, lineSpacing, staffTop, noteX,
              notes, index, childNoteY, noteSpacing, noteColour);
        } else {
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
      for (final childNote in parentChord.childNotes!) {
        drawNoteKey(canvas, paint, childNote, lineSpacing, staffTop, noteX,
            notes, index, childNote.noteY, noteSpacing, noteColour);
      }
    }
  }
}
