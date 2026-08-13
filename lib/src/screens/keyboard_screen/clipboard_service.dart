import 'package:flutter/material.dart';
import 'package:music_keyboard/models/clipboard_item.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/row_properties.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/providers/list_of_spacing_for_each_row.dart';
import 'package:music_keyboard/src/providers/select_rows_mode_provider.dart';
import 'package:music_keyboard/src/utils/toast_utils.dart';
import 'package:music_keyboard/src/widgets/clipboard_popup.dart';
import 'package:provider/provider.dart';

abstract class ClipboardHost {
  BuildContext get context;
  Sheet get sheet;
  double get defaultNoteSpacing;
  SheetDatabaseHelper get dbHelper;
  bool updateRowSpacing(
      int rowIndex,
      CurrentSelectedNoteProvider selectedNoteProvider,
      List<MusicalNote> notes);
}

class ClipboardService {
  ClipboardService({required this.host});

  final ClipboardHost host;

  Sheet get sheet => host.sheet;

  Future<void> copySelectedRows() async {
    final selectRowsModeProvider = host.context.read<SelectRowsModeProvider>();
    final selectedRows = selectRowsModeProvider.selectedRows.toList();

    if (selectedRows.isEmpty) return;

    selectedRows.sort();

    final rowsToCopy = selectedRows.map((rowIndex) {
      final originalRow = sheet.sheetRows[rowIndex];
      final clonedNotes = originalRow.chords
          .map((note) => MusicalNote(
                pitch: note.pitch,
                octave: note.octave,
                type: note.type,
                isBeamed: note.isBeamed,
                unicodeCharacter: note.unicodeCharacter,
                noteY: note.noteY,
                topTimeSignatureCharacter: note.topTimeSignatureCharacter,
                bottomTimeSignatureCharacter: note.bottomTimeSignatureCharacter,
                keySignatureName: note.keySignatureName,
                keySignatureClefType: note.keySignatureClefType,
                clefType: note.clefType,
                accidentalCharacter: note.accidentalCharacter,
                isTiedToNext: note.isTiedToNext,
                isCrescendoStart: note.isCrescendoStart,
                crescendoEndIndex: note.crescendoEndIndex,
                isDecrescendoStart: note.isDecrescendoStart,
                decrescendoEndIndex: note.decrescendoEndIndex,
                slurEndIndex: note.slurEndIndex,
                dynamicCharacter: note.dynamicCharacter,
                rehearsalMarking: note.rehearsalMarking,
                tempoNumber: note.tempoNumber,
                swing: note.swing,
                swingText: note.swingText,
                isUpsideDown: note.isUpsideDown,
              ))
          .toList();

      return SheetRows(
        chords: clonedNotes,
        rowProperties: RowProperties(
          tempoNumber: originalRow.rowProperties.tempoNumber,
          swing: originalRow.rowProperties.swing,
          swingText: originalRow.rowProperties.swingText,
        ),
      );
    }).toList();

    final clipboardItem = ClipboardItem(
      dateCopied: DateTime.now(),
      rows: rowsToCopy,
    );

    try {
      await host.dbHelper.insertClipboardItem(clipboardItem);
      ToastUtils.showToast('Copied ${selectedRows.length} rows to clipboard.');
    } catch (e) {
      print('Error saving to clipboard: $e');
      ToastUtils.showToast('Failed to copy to clipboard.', isError: true);
    }
  }

  void pasteRows(ClipboardItem clipboardItem) {
    final selectedNoteProvider =
        host.context.read<CurrentSelectedNoteProvider>();
    final rowSpacingProvider = host.context.read<ListOfSpacingForEachRow>();
    var rowSpacingList = rowSpacingProvider.rowSpacingList;

    int insertionIndex = selectedNoteProvider.selectedRow + 1;

    final rowsToInsert = clipboardItem.rows.map((clipboardRow) {
      final clonedNotes = clipboardRow.chords
          .map((note) => MusicalNote(
                pitch: note.pitch,
                octave: note.octave,
                type: note.type,
                isBeamed: note.isBeamed,
                unicodeCharacter: note.unicodeCharacter,
                noteY: note.noteY,
                topTimeSignatureCharacter: note.topTimeSignatureCharacter,
                bottomTimeSignatureCharacter: note.bottomTimeSignatureCharacter,
                keySignatureName: note.keySignatureName,
                keySignatureClefType: note.keySignatureClefType,
                clefType: note.clefType,
                accidentalCharacter: note.accidentalCharacter,
                isTiedToNext: note.isTiedToNext,
                isCrescendoStart: note.isCrescendoStart,
                crescendoEndIndex: note.crescendoEndIndex,
                isDecrescendoStart: note.isDecrescendoStart,
                decrescendoEndIndex: note.decrescendoEndIndex,
                slurEndIndex: note.slurEndIndex,
                dynamicCharacter: note.dynamicCharacter,
                rehearsalMarking: note.rehearsalMarking,
                tempoNumber: note.tempoNumber,
                swing: note.swing,
                swingText: note.swingText,
                isUpsideDown: note.isUpsideDown,
              ))
          .toList();

      return SheetRows(
        chords: clonedNotes,
        rowProperties: RowProperties(
          tempoNumber: clipboardRow.rowProperties.tempoNumber,
          swing: clipboardRow.rowProperties.swing,
          swingText: clipboardRow.rowProperties.swingText,
        ),
      );
    }).toList();

    sheet.sheetRows.insertAll(insertionIndex, rowsToInsert);

    for (int i = 0; i < rowsToInsert.length; i++) {
      rowSpacingList.insert(insertionIndex + i, host.defaultNoteSpacing);
    }

    rowSpacingProvider.updateRowSpacingList(rowSpacingList);

    sheet.sheetProperties
        .updateCurlyBracesForRowInsertion(insertionIndex, rowsToInsert.length);

    selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
        insertionIndex, rowsToInsert[0].chords.isNotEmpty ? 0 : -1);

    for (int i = 0; i < rowsToInsert.length; i++) {
      final rowIndex = insertionIndex + i;
      host.updateRowSpacing(
          rowIndex, selectedNoteProvider, sheet.sheetRows[rowIndex].chords);
    }

    _ensureCompleteLastRowGroup(rowSpacingProvider, rowSpacingList);

    ToastUtils.showToast('Pasted ${rowsToInsert.length} rows.');
  }

  void _ensureCompleteLastRowGroup(
    ListOfSpacingForEachRow rowSpacingProvider,
    List<double> rowSpacingList,
  ) {
    final int rowsPerGroup = sheet.format.rowsPerGroup;

    if (rowsPerGroup == 1) return;

    final int totalRows = sheet.sheetRows.length;
    final int remainder = totalRows % rowsPerGroup;

    if (remainder == 0) return;

    final int rowsToAdd = rowsPerGroup - remainder;
    final List<String> clefs = sheet.format.defaultClefsFor(sheet.keyboardType);

    for (int i = 0; i < rowsToAdd; i++) {
      final newRow =
          SheetRows(chords: [], rowProperties: RowProperties(tempoNumber: 0));

      final int clefIndex = remainder + i;
      if (clefIndex < clefs.length) {
        newRow.chords.add(MusicalNote(
          pitch: "G",
          octave: 4,
          type: NoteType.clef,
          isBeamed: false,
          unicodeCharacter: clefs[clefIndex],
          clefType: clefs[clefIndex],
        ));
      }

      sheet.sheetRows.add(newRow);
      rowSpacingList.add(host.defaultNoteSpacing);
    }

    rowSpacingProvider.updateRowSpacingList(rowSpacingList);

    sheet.sheetProperties
        .updateCurlyBracesForRowInsertion(totalRows, rowsToAdd);
  }

  void showClipboardPopup() {
    showDialog(
      context: host.context,
      builder: (context) => ClipboardPopup(
        onPasteItem: (clipboardItem) {
          pasteRows(clipboardItem);
        },
      ),
    );
  }
}
