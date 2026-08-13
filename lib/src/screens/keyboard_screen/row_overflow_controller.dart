import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/row_properties.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/models/keyboard_type.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/providers/list_of_spacing_for_each_row.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_width_calculator.dart';
import 'package:provider/provider.dart';

abstract class RowOverflowHost {
  BuildContext get context;
  Sheet get sheet;
  double get defaultNoteSpacing;
  int get maxNotesPerRow;
}

class RowOverflowController {
  RowOverflowController({required this.host});

  final RowOverflowHost host;

  Sheet get sheet => host.sheet;
  double get defaultNoteSpacing => host.defaultNoteSpacing;
  int get maxNotesPerRow => host.maxNotesPerRow;

  void handleRowOverflow(
      CurrentSelectedNoteProvider selectedNoteProvider,
      ListOfSpacingForEachRow rowSpacingProvider,
      List<double> rowSpacingList,
      double smallestSpacingSize,
      List<MusicalNote> notes,
      double maxRowSize) {
    bool hasBarNotes = _hasBarNotesInRow(selectedNoteProvider.selectedRow);

    if (!hasBarNotes) {
      _handleRowOverflowWithoutBars(selectedNoteProvider, rowSpacingProvider,
          rowSpacingList, smallestSpacingSize, notes, maxRowSize);
    } else {
      _handleRowOverflowWithBars(
          selectedNoteProvider, rowSpacingProvider, rowSpacingList);
    }
  }

  bool _hasBarNotesInRow(int rowIndex) {
    for (var note in sheet.sheetRows[rowIndex].chords) {
      if (note.type == NoteType.bar) {
        return true;
      }
    }
    return false;
  }

  void _handleRowOverflowWithoutBars(
      CurrentSelectedNoteProvider selectedNoteProvider,
      ListOfSpacingForEachRow rowSpacingProvider,
      List<double> rowSpacingList,
      double smallestSpacingSize,
      List<MusicalNote> notes,
      double maxRowSize) {
    final int rowsToAdd = sheet.format.rowsPerGroup;
    final List<String> clefs = sheet.format.defaultClefsFor(sheet.keyboardType);

    final int rowsPerGroup = sheet.format.rowsPerGroup;
    final int groupStartRow =
        (selectedNoteProvider.selectedRow ~/ rowsPerGroup) * rowsPerGroup;
    final int groupEndRow =
        math.min(groupStartRow + rowsPerGroup - 1, sheet.sheetRows.length - 1);
    final int insertionPoint = groupEndRow + 1;

    for (int i = 0; i < rowsToAdd; i++) {
      final newRow =
          SheetRows(chords: [], rowProperties: RowProperties(tempoNumber: 0));

      if (i < clefs.length) {
        newRow.chords.add(MusicalNote(
          pitch: "G",
          octave: 4,
          type: NoteType.clef,
          isBeamed: false,
          unicodeCharacter: clefs[i],
          clefType: clefs[i],
        ));
      }

      sheet.sheetRows.insert(insertionPoint + i, newRow);
      rowSpacingList.insert(insertionPoint + i, defaultNoteSpacing);
    }

    var overflowNotes =
        sheet.sheetRows[selectedNoteProvider.selectedRow].chords;
    var endIndex = overflowNotes.length - 1;
    var startIndex = 0;
    var notesWidth = 0.0;

    for (int i = 0; i < overflowNotes.length; i++) {
      final note = overflowNotes[i];

      if (note.type == NoteType.clef || note.type == NoteType.timeSignature) {
        notesWidth += getNoteWidth(note);
      } else if (note.type == NoteType.keySignature) {
        notesWidth += getNoteWidth(note) + 10;
      } else {
        notesWidth += smallestSpacingSize;
      }

      if (notesWidth > maxRowSize) {
        startIndex = i;
        break;
      }
    }

    int targetRowIndex = insertionPoint;

    if (sheet.format == SheetFormat.twoRows && rowsToAdd == 2) {
      final currentRowIndex = selectedNoteProvider.selectedRow;
      final isCurrentRowTreble = _isRowInTreblePosition(currentRowIndex);

      targetRowIndex = isCurrentRowTreble ? insertionPoint : insertionPoint + 1;
    }

    _moveMultipleOverflowingNotesToRow(
        selectedNoteProvider, startIndex, endIndex, targetRowIndex);

    final currentRowNotesLength = sheet.sheetRows[targetRowIndex].chords.length;

    selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
        targetRowIndex, math.max(0, currentRowNotesLength - 1));

    updateRowSpacing(selectedNoteProvider.selectedRow, selectedNoteProvider,
        sheet.sheetRows[selectedNoteProvider.selectedRow].chords);
    rowSpacingProvider.updateRowSpacingList(rowSpacingList);

    sheet.sheetProperties
        .updateCurlyBracesForRowInsertion(insertionPoint, rowsToAdd);
  }

  bool _isRowInTreblePosition(int rowIndex) {
    if (sheet.format == SheetFormat.single) return true;

    final rowsPerGroup = sheet.format.rowsPerGroup;
    return (rowIndex % rowsPerGroup) == 0;
  }

  void _handleRowOverflowWithBars(
      CurrentSelectedNoteProvider selectedNoteProvider,
      ListOfSpacingForEachRow rowSpacingProvider,
      List<double> rowSpacingList) {
    final barBoundaries =
        _findLastBarBoundaries(selectedNoteProvider.selectedRow);
    int lastBarStartIndex = barBoundaries['startIndex']!;
    int lastBarEndIndex = barBoundaries['endIndex']!;

    int notesInLastBar = lastBarEndIndex - lastBarStartIndex + 1;

    _ensureNextRowExists(selectedNoteProvider, rowSpacingProvider,
        rowSpacingList, notesInLastBar);

    _moveMultipleOverflowingNotes(
        selectedNoteProvider, lastBarStartIndex, lastBarEndIndex);
  }

  Map<String, int> _findLastBarBoundaries(int rowIndex) {
    int lastBarStartIndex = 0;
    int lastBarEndIndex = sheet.sheetRows[rowIndex].chords.length - 1;

    int lastBarLineIndex = -1;
    for (int i = sheet.sheetRows[rowIndex].chords.length - 1; i >= 0; i--) {
      if (sheet.sheetRows[rowIndex].chords[i].type == NoteType.bar) {
        lastBarLineIndex = i;
        break;
      }
    }

    if (lastBarLineIndex != -1) {
      lastBarStartIndex = lastBarLineIndex + 1;
    } else {
      lastBarStartIndex = 0;
    }

    lastBarEndIndex = sheet.sheetRows[rowIndex].chords.length - 1;

    return {
      'startIndex': lastBarStartIndex,
      'endIndex': lastBarEndIndex,
    };
  }

  void _ensureNextRowExists(
      CurrentSelectedNoteProvider selectedNoteProvider,
      ListOfSpacingForEachRow rowSpacingProvider,
      List<double> rowSpacingList,
      int notesInCurrentBar) {
    if (sheet.sheetRows.length - 1 <= selectedNoteProvider.selectedRow) {
      sheet.sheetRows.insert(selectedNoteProvider.selectedRow + 1,
          SheetRows(chords: [], rowProperties: RowProperties(tempoNumber: 0)));
      rowSpacingList.insert(rowSpacingList.length, defaultNoteSpacing);
      rowSpacingProvider.updateRowSpacingList(rowSpacingList);

      sheet.sheetProperties.updateCurlyBracesForRowInsertion(
          selectedNoteProvider.selectedRow + 1, 1);
    } else if (sheet
                .sheetRows[selectedNoteProvider.selectedRow + 1].chords.length +
            notesInCurrentBar >
        maxNotesPerRow) {
      sheet.sheetRows.insert(selectedNoteProvider.selectedRow + 1,
          SheetRows(chords: [], rowProperties: RowProperties(tempoNumber: 0)));
      rowSpacingList.insert(rowSpacingList.length, defaultNoteSpacing);
      rowSpacingProvider.updateRowSpacingList(rowSpacingList);

      sheet.sheetProperties.updateCurlyBracesForRowInsertion(
          selectedNoteProvider.selectedRow + 1, 1);
    }
  }

  void _moveMultipleOverflowingNotes(
      CurrentSelectedNoteProvider selectedNoteProvider,
      int lastBarStartIndex,
      int lastBarEndIndex) {
    _moveMultipleOverflowingNotesToRow(selectedNoteProvider, lastBarStartIndex,
        lastBarEndIndex, selectedNoteProvider.selectedRow + 1);
  }

  void _moveMultipleOverflowingNotesToRow(
      CurrentSelectedNoteProvider selectedNoteProvider,
      int startIndex,
      int endIndex,
      int targetRowIndex) {
    List<MusicalNote> notesToMove = [];
    for (int i = startIndex; i <= endIndex; i++) {
      notesToMove
          .add(sheet.sheetRows[selectedNoteProvider.selectedRow].chords[i]);
    }

    for (int i = endIndex; i >= startIndex; i--) {
      sheet.sheetRows[selectedNoteProvider.selectedRow].chords.removeAt(i);
    }

    int insertIndex = 0;
    if (sheet.sheetRows[targetRowIndex].chords.isNotEmpty &&
        sheet.sheetRows[targetRowIndex].chords[0].type == NoteType.clef) {
      insertIndex = 1;
    }

    for (int i = 0; i < notesToMove.length; i++) {
      sheet.sheetRows[targetRowIndex].chords
          .insert(insertIndex + i, notesToMove[i]);
    }

    if (sheet.sheetRows[selectedNoteProvider.selectedRow].chords.isNotEmpty &&
        sheet.sheetRows[selectedNoteProvider.selectedRow].chords.last.type ==
            NoteType.bar) {
      sheet.sheetRows[selectedNoteProvider.selectedRow].chords.removeLast();
    }

    updateRowSpacing(selectedNoteProvider.selectedRow, selectedNoteProvider,
        sheet.sheetRows[selectedNoteProvider.selectedRow].chords);
    updateRowSpacing(targetRowIndex, selectedNoteProvider,
        sheet.sheetRows[targetRowIndex].chords);

    if (selectedNoteProvider.insertionIndex >= startIndex) {
      selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
          targetRowIndex, notesToMove.length - 1);
    }
  }

  bool updateRowSpacing(
      int rowIndex,
      CurrentSelectedNoteProvider selectedNoteProvider,
      List<MusicalNote> notes) {
    final rowSpacingProvider = host.context.read<ListOfSpacingForEachRow>();
    var rowSpacingList = rowSpacingProvider.rowSpacingList;

    List<double> listOfSpacingSizes = [
      65,
      63,
      61,
      59,
      57,
      55,
      53,
      51,
      49,
      47,
      45,
      43,
    ];

    if (sheet.format == SheetFormat.single) {
      return _updateSingleRowSpacing(rowIndex, selectedNoteProvider, notes,
          rowSpacingProvider, rowSpacingList, listOfSpacingSizes);
    } else {
      return _updateConnectedRowGroupSpacing(rowIndex, selectedNoteProvider,
          rowSpacingProvider, rowSpacingList, listOfSpacingSizes);
    }
  }

  bool _updateSingleRowSpacing(
      int rowIndex,
      CurrentSelectedNoteProvider selectedNoteProvider,
      List<MusicalNote> notes,
      ListOfSpacingForEachRow rowSpacingProvider,
      List<double> rowSpacingList,
      List<double> listOfSpacingSizes) {
    var clefAndKeySigLength = 0.0;
    var countOfNormalNotes = 0.0;

    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      if (note.type == NoteType.clef || note.type == NoteType.timeSignature) {
        clefAndKeySigLength += getNoteWidth(note);
      } else if (note.type == NoteType.keySignature) {
        clefAndKeySigLength += getNoteWidth(note) + 10;
      } else {
        countOfNormalNotes++;
      }
    }

    double maxRowSize = 1200;
    var adjustedSpacingFitsAllNotesOnSingleLine = false;
    if (rowSpacingList.length > rowIndex) {
      for (int i = 0; i < listOfSpacingSizes.length; i++) {
        if (clefAndKeySigLength + (countOfNormalNotes * listOfSpacingSizes[i]) <
            maxRowSize) {
          rowSpacingList[rowIndex] = listOfSpacingSizes[i];
          adjustedSpacingFitsAllNotesOnSingleLine = true;
          break;
        }
      }
    }

    if (!adjustedSpacingFitsAllNotesOnSingleLine) {
      handleRowOverflow(selectedNoteProvider, rowSpacingProvider,
          rowSpacingList, listOfSpacingSizes.last, notes, maxRowSize);
    }

    rowSpacingProvider.updateRowSpacingList(rowSpacingList);

    return !adjustedSpacingFitsAllNotesOnSingleLine;
  }

  bool _updateConnectedRowGroupSpacing(
      int rowIndex,
      CurrentSelectedNoteProvider selectedNoteProvider,
      ListOfSpacingForEachRow rowSpacingProvider,
      List<double> rowSpacingList,
      List<double> listOfSpacingSizes) {
    final int rowsPerGroup = sheet.format.rowsPerGroup;

    final int groupStartRow = (rowIndex ~/ rowsPerGroup) * rowsPerGroup;
    final int groupEndRow =
        math.min(groupStartRow + rowsPerGroup - 1, sheet.sheetRows.length - 1);

    double maxClefAndKeySigLength = 0.0;
    double maxCountOfNormalNotes = 0.0;

    for (int i = groupStartRow; i <= groupEndRow; i++) {
      if (i < sheet.sheetRows.length) {
        var clefAndKeySigLength = 0.0;
        var countOfNormalNotes = 0.0;

        for (int j = 0; j < sheet.sheetRows[i].chords.length; j++) {
          final note = sheet.sheetRows[i].chords[j];

          if (note.type == NoteType.clef ||
              note.type == NoteType.timeSignature) {
            clefAndKeySigLength += getNoteWidth(note);
          } else if (note.type == NoteType.keySignature) {
            clefAndKeySigLength += getNoteWidth(note) + 10;
          } else {
            countOfNormalNotes++;
          }
        }

        maxClefAndKeySigLength =
            math.max(maxClefAndKeySigLength, clefAndKeySigLength);
        maxCountOfNormalNotes =
            math.max(maxCountOfNormalNotes, countOfNormalNotes);
      }
    }

    double maxRowSize = 1200;
    var adjustedSpacingFitsAllNotesOnSingleLine = false;
    double selectedSpacing = listOfSpacingSizes.last;

    for (int i = 0; i < listOfSpacingSizes.length; i++) {
      if (maxClefAndKeySigLength +
              (maxCountOfNormalNotes * listOfSpacingSizes[i]) <
          maxRowSize) {
        selectedSpacing = listOfSpacingSizes[i];
        adjustedSpacingFitsAllNotesOnSingleLine = true;
        break;
      }
    }

    for (int i = groupStartRow; i <= groupEndRow; i++) {
      if (i < sheet.sheetRows.length) {
        rowSpacingList[i] = selectedSpacing;
      }
    }

    if (!adjustedSpacingFitsAllNotesOnSingleLine) {
      int mostNotesRowIndex = groupStartRow;
      int maxNotes = sheet.sheetRows[groupStartRow].chords.length;

      for (int i = groupStartRow + 1; i <= groupEndRow; i++) {
        if (i < sheet.sheetRows.length &&
            sheet.sheetRows[i].chords.length > maxNotes) {
          maxNotes = sheet.sheetRows[i].chords.length;
          mostNotesRowIndex = i;
        }
      }

      selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
          mostNotesRowIndex,
          sheet.sheetRows[mostNotesRowIndex].chords.length - 1);

      handleRowOverflow(
          selectedNoteProvider,
          rowSpacingProvider,
          rowSpacingList,
          listOfSpacingSizes.last,
          sheet.sheetRows[mostNotesRowIndex].chords,
          maxRowSize);
    } else {
      rowSpacingProvider.updateRowSpacingList(rowSpacingList);
    }

    return !adjustedSpacingFitsAllNotesOnSingleLine;
  }

  void forceNewRow(CurrentSelectedNoteProvider selectedNoteProvider) {
    if (sheet.sheetRows.isEmpty) return;

    final rowSpacingProvider = host.context.read<ListOfSpacingForEachRow>();
    var rowSpacingList = rowSpacingProvider.rowSpacingList;

    final int rowsToAdd = sheet.format.rowsPerGroup;
    final List<String> clefs = sheet.format.defaultClefsFor(sheet.keyboardType);

    final int rowsPerGroup = sheet.format.rowsPerGroup;
    final int groupStartRow =
        (selectedNoteProvider.selectedRow ~/ rowsPerGroup) * rowsPerGroup;
    final int groupEndRow =
        math.min(groupStartRow + rowsPerGroup - 1, sheet.sheetRows.length - 1);
    final int insertionPoint = groupEndRow + 1;

    for (int i = 0; i < rowsToAdd; i++) {
      final newRow =
          SheetRows(chords: [], rowProperties: RowProperties(tempoNumber: 0));

      if (i < clefs.length) {
        newRow.chords.add(MusicalNote(
          pitch: "G",
          octave: 4,
          type: NoteType.clef,
          isBeamed: false,
          unicodeCharacter: clefs[i],
          clefType: clefs[i],
        ));
      }

      if (sheet.keyboardType == KeyboardType.guitarTab) {
        newRow.chords.add(MusicalNote(
          pitch: 'G',
          octave: 4,
          type: NoteType.fret,
          duration: 0.0,
          childNotes: [],
        ));
      }

      sheet.sheetRows.insert(insertionPoint + i, newRow);
      rowSpacingList.insert(insertionPoint + i, defaultNoteSpacing);
    }

    rowSpacingProvider.updateRowSpacingList(rowSpacingList);

    sheet.sheetProperties
        .updateCurlyBracesForRowInsertion(insertionPoint, rowsToAdd);

    int targetRowIndex = insertionPoint;

    if (sheet.format == SheetFormat.twoRows && rowsToAdd == 2) {
      final currentRowIndex = selectedNoteProvider.selectedRow;
      final isCurrentRowTreble = _isRowInTreblePosition(currentRowIndex);

      targetRowIndex = isCurrentRowTreble
          ? insertionPoint // Treble row (first in new group)
          : insertionPoint + 1; // Bass row (second in new group)
    }

    selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
        targetRowIndex, 0);
  }
}
