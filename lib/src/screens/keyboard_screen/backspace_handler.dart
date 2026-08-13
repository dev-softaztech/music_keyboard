import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/keyboard_type.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/providers/list_of_spacing_for_each_row.dart';
import 'package:music_keyboard/src/providers/undo_manager.dart';
import 'package:provider/provider.dart';

abstract class BackspaceHandlerHost {
  BuildContext get context;
  Sheet get sheet;
  VoidCallback? get clearHighlightingCallback;
  void markAsChanged();
  bool updateRowSpacing(
      int rowIndex,
      CurrentSelectedNoteProvider selectedNoteProvider,
      List<MusicalNote> notes);
}

class BackspaceHandler {
  BackspaceHandler({required this.host});

  final BackspaceHandlerHost host;

  Sheet get sheet => host.sheet;

  void handleBackspacePress() {
    clearHighlighting();

    final selectedNoteProvider =
        host.context.read<CurrentSelectedNoteProvider>();

    if (selectedNoteProvider.selectedRow == 0 &&
        selectedNoteProvider.insertionIndex == 0) {
      return;
    }

    final rowSpacingProvider = host.context.read<ListOfSpacingForEachRow>();
    var rowSpacingList = rowSpacingProvider.rowSpacingList;
    final selectedRow = selectedNoteProvider.selectedRow;
    int selectedIndex = selectedNoteProvider.selectedIndex;
    final notes = sheet.sheetRows[selectedRow].chords;

    if (notes.isEmpty) {
      if (sheet.format == SheetFormat.single) {
        if (selectedRow == 0) {
          return;
        }

        sheet.sheetRows.removeAt(selectedRow);
        rowSpacingList.removeAt(selectedRow);
        rowSpacingProvider.updateRowSpacingList(rowSpacingList);

        sheet.sheetProperties.updateCurlyBracesForRowDeletion(selectedRow, 1);

        selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
            selectedRow - 1,
            sheet.sheetRows[selectedRow - 1].chords.isEmpty
                ? -1
                : sheet.sheetRows[selectedRow - 1].chords.length - 1);
      } else {
        final int rowsPerGroup = sheet.format.rowsPerGroup;
        final int groupStartRow = (selectedRow ~/ rowsPerGroup) * rowsPerGroup;
        final int groupEndRow = math.min(
            groupStartRow + rowsPerGroup - 1, sheet.sheetRows.length - 1);

        bool allRowsInGroupEmpty = true;
        for (int i = groupStartRow; i <= groupEndRow; i++) {
          if (sheet.sheetRows[i].chords.isNotEmpty) {
            allRowsInGroupEmpty = false;
            break;
          }
        }

        if (allRowsInGroupEmpty) {
          if (groupStartRow == 0) {
            return;
          }

          final int rowsToRemove = groupEndRow - groupStartRow + 1;

          sheet.sheetRows
              .removeRange(groupStartRow, groupStartRow + rowsToRemove);
          rowSpacingList.removeRange(
              groupStartRow, groupStartRow + rowsToRemove);
          rowSpacingProvider.updateRowSpacingList(rowSpacingList);

          sheet.sheetProperties
              .updateCurlyBracesForRowDeletion(groupStartRow, rowsToRemove);

          final int newCursorRow = groupStartRow - 1;
          selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
              newCursorRow,
              sheet.sheetRows[newCursorRow].chords.isEmpty
                  ? -1
                  : sheet.sheetRows[newCursorRow].chords.length - 1);
        }
      }
    } else if (notes.isNotEmpty && selectedNoteProvider.insertionIndex >= 0) {
      if (selectedIndex >= notes.length) {
        selectedIndex = notes.length - 1;
      }

      MusicalNote noteToRemove = notes[selectedIndex];

      for (var note in notes) {
        if (note.slurEndIndex == selectedNoteProvider.insertionIndex) {
          note.slurEndIndex = null;
        }
      }

      host.context.read<SheetUndoManager>().saveState(sheet.sheetRows);

      notes.remove(noteToRemove);

      selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
          selectedRow, selectedIndex - 1);

      final int removedNoteIndex = selectedNoteProvider.insertionIndex;
      for (var note in notes) {
        if (note.crescendoEndIndex != null &&
            note.crescendoEndIndex == removedNoteIndex) {
          note.crescendoEndIndex = note.crescendoEndIndex! - 1;
        }
        if (note.decrescendoEndIndex != null &&
            note.decrescendoEndIndex == removedNoteIndex) {
          note.decrescendoEndIndex = note.decrescendoEndIndex! - 1;
        }
      }

      if (sheet.keyboardType == KeyboardType.guitarTab) {
        final int currentSelectedIndex = selectedNoteProvider.selectedIndex;

        for (var note in notes) {
          if (note.harmonicEndIndex != null &&
              currentSelectedIndex <= note.harmonicEndIndex!) {
            note.harmonicEndIndex = note.harmonicEndIndex! - 1;
          }
          if (note.vibratoEndIndex != null &&
              currentSelectedIndex <= note.vibratoEndIndex!) {
            note.vibratoEndIndex = note.vibratoEndIndex! - 1;
          }
          if (note.muteEndIndex != null &&
              currentSelectedIndex <= note.muteEndIndex!) {
            note.muteEndIndex = note.muteEndIndex! - 1;
          }
          if (note.pinchHarmonicEndIndex != null &&
              currentSelectedIndex <= note.pinchHarmonicEndIndex!) {
            note.pinchHarmonicEndIndex = note.pinchHarmonicEndIndex! - 1;
          }

          if (note.childNotes != null) {
            for (var childNote in note.childNotes!) {
              if (childNote.bendEndIndex != null &&
                  currentSelectedIndex <= childNote.bendEndIndex!) {
                childNote.bendEndIndex = childNote.bendEndIndex! - 1;
              }
              if (childNote.preBendEndIndex != null &&
                  currentSelectedIndex <= childNote.preBendEndIndex!) {
                childNote.preBendEndIndex = childNote.preBendEndIndex! - 1;
              }
              if (childNote.bendReleaseEndIndex != null &&
                  currentSelectedIndex <= childNote.bendReleaseEndIndex!) {
                childNote.bendReleaseEndIndex =
                    childNote.bendReleaseEndIndex! - 1;
              }
              if (childNote.preBendReleaseEndIndex != null &&
                  currentSelectedIndex <= childNote.preBendReleaseEndIndex!) {
                childNote.preBendReleaseEndIndex =
                    childNote.preBendReleaseEndIndex! - 1;
              }
            }
          }
        }
      }

      selectedNoteProvider.adjustSlurIndicesForSpaceNote(
          noteToRemove, notes, removedNoteIndex, false);
    }

    host.updateRowSpacing(selectedRow, selectedNoteProvider, notes);

    host.markAsChanged();
  }

  void clearHighlighting() {
    host.clearHighlightingCallback?.call();
  }
}
