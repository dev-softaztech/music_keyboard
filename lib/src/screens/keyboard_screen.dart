import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
import 'package:music_keyboard/models/row_properties.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/models/sheet_properties.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/models/clipboard_item.dart';
import 'package:music_keyboard/src/widgets/clipboard_popup.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/providers/is_connected_provider.dart';
import 'package:music_keyboard/src/providers/list_of_spacing_for_each_row.dart';
import 'package:music_keyboard/src/providers/selected_accidental_provider.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_width_calculator.dart';
import 'package:music_keyboard/src/widgets/keyboard/dynamics_keyboard.dart';
import 'package:music_keyboard/src/widgets/keyboard/notes_keyboard_layout.dart';
import 'package:music_keyboard/src/widgets/main_sheet/music_sheet_container.dart';
import 'package:music_keyboard/src/utils/pdf_exporter.dart';
import 'package:music_keyboard/src/utils/screenshot_saver.dart';
import 'package:music_keyboard/src/utils/toast_utils.dart';
import 'package:music_keyboard/src/widgets/main_sheet/title_popup.dart';
import 'package:music_keyboard/src/widgets/keyboard/tempo_popup.dart';
import 'package:music_keyboard/src/widgets/keyboard/rehearsal_markings_popup.dart';
import 'package:music_keyboard/src/providers/row_spacing_provider.dart';
import 'package:music_keyboard/src/providers/select_rows_mode_provider.dart';
import 'package:music_keyboard/src/providers/undo_manager.dart';
import 'package:music_keyboard/src/widgets/shared/popup_theme.dart';
import 'package:music_keyboard/src/widgets/shared/pdf_export_loading_overlay.dart';
import 'package:music_keyboard/src/utils/haptic_feedback_utils.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';

class KeyboardScreen extends StatelessWidget {
  const KeyboardScreen({super.key, this.initialSheet});

  final Sheet? initialSheet;
  static const routeName = '/keyboard';

  @override
  Widget build(BuildContext context) {
    // Get the arguments passed from navigation if initialSheetRows is null
    final Sheet? routeArgs =
        initialSheet ?? ModalRoute.of(context)?.settings.arguments as Sheet?;

    return NoteInputScreen(initialSheet: routeArgs);
  }
} //need to resolve errors when adding first notes to new lines

class NoteInputScreen extends StatefulWidget {
  const NoteInputScreen({super.key, this.initialSheet});

  final Sheet? initialSheet;

  @override
  _NoteInputScreenState createState() => _NoteInputScreenState();
}

class _NoteInputScreenState extends State<NoteInputScreen> {
  final ScreenshotController screenshotController = ScreenshotController();
  late Sheet sheet;
  int maxNotesPerRow = 18;
  double defaultNoteSpacing = 26;

  bool showClefs = true;
  bool showBars = false;
  bool showTimeSignatures = false;
  bool showNotes = false;

  bool showNotesKeyboard = false;
  bool _showDynamicsKeyboard = false;
  bool showSymbolsKeyboard = false;
  bool isTieing = false;
  bool showMenu = false;
  bool showToolsMenu = false;
  bool isBeamLockActive = false;
  DateTime? _lastTapTime;

  //String keyType = "clefs";
  String _selectedBarUnicode = '\ue030';
  OverlayEntry? _barOverlayEntry;
  OverlayEntry? _loadingOverlayEntry;

  // Callback function to clear highlighting
  VoidCallback? _clearHighlightingCallback;

  // Callback functions for button state checks
  Function()? _shouldShowTieButtonCallback;
  Function()? _shouldShowFlipNoteCallback;

  // Callback function for zooming to a note
  Function(int row, int index)? _zoomToNoteCallback;

  // PDF export state variables
  int? _pdfRenderStartRow;
  int? _pdfRenderEndRow;
  bool _pdfShowTitleAndComposer = true;

  // Database helper for clipboard operations
  final SheetDatabaseHelper _dbHelper = SheetDatabaseHelper();

  // Auto-save functionality
  bool _hasUnsavedChanges = false;
  Timer? _autoSaveTimer;

  /// Mark that changes have been made to the sheet
  void _markAsChanged() {
    _hasUnsavedChanges = true;
  }

  /// Save the sheet to the database if there are unsaved changes
  Future<void> _saveSheetToDatabase() async {
    if (!_hasUnsavedChanges || sheet.id == null) return;

    try {
      print('DEBUG: Saving sheet with id ${sheet.id}');
      print('DEBUG: Sheet has ${sheet.sheetRows.length} rows');
      if (sheet.sheetRows.isNotEmpty) {
        print('DEBUG: First row has ${sheet.sheetRows[0].notes.length} notes');
      }
      await _dbHelper.updateSheet(sheet);
      _hasUnsavedChanges = false;
      print('DEBUG: Sheet saved successfully');
    } catch (e) {
      print('Error saving sheet to database: $e');
    }
  }

  /// Initialize auto-save timer
  void _initializeAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _saveSheetToDatabase();
    });
  }

  /// Copy selected rows to clipboard
  Future<void> _copySelectedRows() async {
    final selectRowsModeProvider = context.read<SelectRowsModeProvider>();
    final selectedRows = selectRowsModeProvider.selectedRows.toList();

    if (selectedRows.isEmpty) return;

    // Sort selected rows to maintain order
    selectedRows.sort();

    // Deep clone the selected rows
    final rowsToCopy = selectedRows.map((rowIndex) {
      final originalRow = sheet.sheetRows[rowIndex];
      final clonedNotes = originalRow.notes
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
        notes: clonedNotes,
        rowProperties: RowProperties(
          tempoNumber: originalRow.rowProperties.tempoNumber,
          swing: originalRow.rowProperties.swing,
          swingText: originalRow.rowProperties.swingText,
        ),
      );
    }).toList();

    // Save to database
    final clipboardItem = ClipboardItem(
      dateCopied: DateTime.now(),
      rows: rowsToCopy,
    );

    try {
      await _dbHelper.insertClipboardItem(clipboardItem);
      ToastUtils.showToast('Copied ${selectedRows.length} rows to clipboard.');
    } catch (e) {
      print('Error saving to clipboard: $e');
      ToastUtils.showToast('Failed to copy to clipboard.', isError: true);
    }
  }

  /// Paste rows from clipboard item after the currently selected row
  void _pasteRows(ClipboardItem clipboardItem) {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    final rowSpacingProvider = context.read<ListOfSpacingForEachRow>();
    var rowSpacingList = rowSpacingProvider.rowSpacingList;

    // Get the insertion index (after currently selected row)
    int insertionIndex = selectedNoteProvider.selectedRow + 1;

    // Deep clone the clipboard rows for insertion
    final rowsToInsert = clipboardItem.rows.map((clipboardRow) {
      final clonedNotes = clipboardRow.notes
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
        notes: clonedNotes,
        rowProperties: RowProperties(
          tempoNumber: clipboardRow.rowProperties.tempoNumber,
          swing: clipboardRow.rowProperties.swing,
          swingText: clipboardRow.rowProperties.swingText,
        ),
      );
    }).toList();

    // Insert the rows
    sheet.sheetRows.insertAll(insertionIndex, rowsToInsert);

    // Add corresponding spacing entries
    for (int i = 0; i < rowsToInsert.length; i++) {
      rowSpacingList.insert(insertionIndex + i, defaultNoteSpacing);
    }

    // Update row spacing provider
    rowSpacingProvider.updateRowSpacingList(rowSpacingList);

    // Update curly brace groups for the row insertion
    sheet.sheetProperties
        .updateCurlyBracesForRowInsertion(insertionIndex, rowsToInsert.length);

    // Update cursor position to the first inserted row
    selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
        insertionIndex, rowsToInsert[0].notes.isNotEmpty ? 0 : -1);

    // Show confirmation message
    ToastUtils.showToast('Pasted ${rowsToInsert.length} rows.');
  }

  /// Show clipboard popup
  void _showClipboardPopup() {
    showDialog(
      context: context,
      builder: (context) => ClipboardPopup(
        onPasteItem: (clipboardItem) {
          _pasteRows(clipboardItem);
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Initialize sheetNoteRows with passed data or default
    sheet = widget.initialSheet ??
        Sheet(sheetRows: [
          SheetRows(notes: [], rowProperties: RowProperties(tempoNumber: 0))
        ], sheetProperties: SheetProperties());

    // Set the rowSpacing value from SheetProperties to RowSpacingProvider after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rowSpacingListProvider = context.read<ListOfSpacingForEachRow>();
      if (sheet.format == SheetFormat.twoRows) {
        rowSpacingListProvider.updateRowSpacingList([26, 26]);
      } else if (sheet.format == SheetFormat.fourRows) {
        rowSpacingListProvider.updateRowSpacingList([26, 26, 26, 26]);
      }

      final rowSpacingProvider = context.read<RowSpacingProvider>();
      rowSpacingProvider
          .updateBetweenRowSpacing(sheet.sheetProperties.rowSpacing);

      // Set the selected index to the first clef note
      final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
      if (sheet.sheetRows.isNotEmpty && sheet.sheetRows[0].notes.isNotEmpty) {
        selectedNoteProvider.updateSelectedIndexAndInsertionPoint(0, 0);
      }

      // Initialize auto-save timer
      _initializeAutoSave();
    });
  }

  @override
  void dispose() {
    // Save any unsaved changes before disposing
    if (_hasUnsavedChanges && sheet.id != null) {
      _dbHelper.updateSheet(sheet);
    }
    // Cancel auto-save timer
    _autoSaveTimer?.cancel();
    // Clean up any active overlays
    _removeBarOverlay();
    _removeLoadingOverlay();
    super.dispose();
  }

  void handleKeyPress(MusicalNote note) {
    try {
      final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
      final accidentalProvider = context.read<SelectedAccidentalProvider>();

      // Get the selected accidental
      final selectedAccidental = accidentalProvider.selectedAccidental;

      // Create a new note with the selected accidental
      final noteWithAccidental = MusicalNote(
          pitch: note.pitch,
          octave: note.octave,
          type: note.type,
          isBeamed: note.isBeamed,
          unicodeCharacter: note.unicodeCharacter,
          accidentalCharacter: selectedAccidental,
          noteY: note.noteY,
          topTimeSignatureCharacter: note.topTimeSignatureCharacter,
          bottomTimeSignatureCharacter: note.bottomTimeSignatureCharacter,
          keySignatureName: note.keySignatureName,
          keySignatureClefType: note.keySignatureClefType,
          clefType: note.clefType);

      setState(() {
        // Add the note first
        selectedNoteProvider.addNote(
            noteWithAccidental, sheet.sheetRows, context);

        updateRowSpacing(selectedNoteProvider.selectedRow, selectedNoteProvider,
            sheet.sheetRows[selectedNoteProvider.selectedRow].notes);

        // Mark as changed for auto-save
        _markAsChanged();

        // Call the button state callback functions from MusicSheetContainer
        if (_shouldShowTieButtonCallback != null) {
          _shouldShowTieButtonCallback!();
        }
        if (_shouldShowFlipNoteCallback != null) {
          _shouldShowFlipNoteCallback!();
        }

        // Zoom to the newly added note
        if (_zoomToNoteCallback != null) {
          _zoomToNoteCallback!(
            selectedNoteProvider.selectedRow,
            selectedNoteProvider.selectedIndex,
          );
        }
      });
    } catch (e) {
      print("Error adding note: $e");
    }
  }

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

  /// Checks if the specified row contains any bar notes
  bool _hasBarNotesInRow(int rowIndex) {
    for (var note in sheet.sheetRows[rowIndex].notes) {
      if (note.type == NoteType.bar) {
        return true;
      }
    }
    return false;
  }

  /// Handles row overflow when there are no bar notes in the current row
  void _handleRowOverflowWithoutBars(
      CurrentSelectedNoteProvider selectedNoteProvider,
      ListOfSpacingForEachRow rowSpacingProvider,
      List<double> rowSpacingList,
      double smallestSpacingSize,
      List<MusicalNote> notes,
      double maxRowSize) {
    // Create new rows based on sheet format
    final int rowsToAdd = sheet.format.rowsPerGroup;
    final List<String> clefs = sheet.format.defaultClefs;

    // Calculate where the current connected group ends
    final int rowsPerGroup = sheet.format.rowsPerGroup;
    final int groupStartRow =
        (selectedNoteProvider.selectedRow ~/ rowsPerGroup) * rowsPerGroup;
    final int groupEndRow =
        math.min(groupStartRow + rowsPerGroup - 1, sheet.sheetRows.length - 1);
    final int insertionPoint = groupEndRow + 1;

    // Insert new connected rows after the entire current connected group
    for (int i = 0; i < rowsToAdd; i++) {
      final newRow =
          SheetRows(notes: [], rowProperties: RowProperties(tempoNumber: 0));

      // Add appropriate clef for each row
      if (i < clefs.length) {
        newRow.notes.add(MusicalNote(
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

    var overflowNotes = sheet.sheetRows[selectedNoteProvider.selectedRow].notes;
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

    // Determine which row in the new group to move to
    // For piano mode: move to the same type of row (treble to treble, bass to bass)
    int targetRowIndex = insertionPoint; // Default to first new row

    if (sheet.format == SheetFormat.twoRows && rowsToAdd == 2) {
      // In piano mode, determine if current row is treble or bass
      final currentRowIndex = selectedNoteProvider.selectedRow;
      final isCurrentRowTreble = _isRowInTreblePosition(currentRowIndex);

      // Move to the corresponding row type in the new group
      targetRowIndex = isCurrentRowTreble
          ? insertionPoint // Treble row (first in new group)
          : insertionPoint + 1; // Bass row (second in new group)
    }

    _moveMultipleOverflowingNotesToRow(
        selectedNoteProvider, startIndex, endIndex, targetRowIndex);

    // Update cursor position to be safe after moving notes
    final currentRowNotesLength = sheet.sheetRows[targetRowIndex].notes.length;
    //if (selectedNoteProvider.selectedIndex >= currentRowNotesLength) {
    selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
        targetRowIndex, math.max(0, currentRowNotesLength - 1));
    //}

    updateRowSpacing(selectedNoteProvider.selectedRow, selectedNoteProvider,
        sheet.sheetRows[selectedNoteProvider.selectedRow].notes);
    rowSpacingProvider.updateRowSpacingList(rowSpacingList);

    // Update curly brace groups for the row insertion
    sheet.sheetProperties
        .updateCurlyBracesForRowInsertion(insertionPoint, rowsToAdd);
  }

  /// Determines if a row is in a treble position (first row of a connected group)
  bool _isRowInTreblePosition(int rowIndex) {
    if (sheet.format == SheetFormat.single) return true;

    final rowsPerGroup = sheet.format.rowsPerGroup;
    return (rowIndex % rowsPerGroup) == 0;
  }

  /// Handles row overflow when there are bar notes in the current row
  void _handleRowOverflowWithBars(
    CurrentSelectedNoteProvider selectedNoteProvider,
    ListOfSpacingForEachRow rowSpacingProvider,
    List<double> rowSpacingList,
  ) {
    // Find the last bar boundaries in the row
    final barBoundaries =
        _findLastBarBoundaries(selectedNoteProvider.selectedRow);
    int lastBarStartIndex = barBoundaries['startIndex']!;
    int lastBarEndIndex = barBoundaries['endIndex']!;

    // Calculate the number of notes in the current bar
    int notesInLastBar = lastBarEndIndex - lastBarStartIndex + 1;

    // Ensure we have a next row to move to
    _ensureNextRowExists(selectedNoteProvider, rowSpacingProvider,
        rowSpacingList, notesInLastBar);

    // Move the entire last bar to the next row
    _moveMultipleOverflowingNotes(
        selectedNoteProvider, lastBarStartIndex, lastBarEndIndex);
  }

  /// Finds the boundaries of the last bar in the specified row
  Map<String, int> _findLastBarBoundaries(int rowIndex) {
    int lastBarStartIndex = 0;
    int lastBarEndIndex = sheet.sheetRows[rowIndex].notes.length - 1;

    // Find the last bar line in the current row
    int lastBarLineIndex = -1;
    for (int i = sheet.sheetRows[rowIndex].notes.length - 1; i >= 0; i--) {
      if (sheet.sheetRows[rowIndex].notes[i].type == NoteType.bar) {
        lastBarLineIndex = i;
        break;
      }
    }

    // Set the start of the last bar
    if (lastBarLineIndex != -1) {
      lastBarStartIndex = lastBarLineIndex + 1;
    } else {
      lastBarStartIndex = 0; // No bar lines found, start from beginning
    }

    // The end is always the end of the row
    lastBarEndIndex = sheet.sheetRows[rowIndex].notes.length - 1;

    return {
      'startIndex': lastBarStartIndex,
      'endIndex': lastBarEndIndex,
    };
  }

  /// Ensures that a next row exists with enough space for the notes to be moved
  void _ensureNextRowExists(
    CurrentSelectedNoteProvider selectedNoteProvider,
    ListOfSpacingForEachRow rowSpacingProvider,
    List<double> rowSpacingList,
    int notesInCurrentBar,
  ) {
    if (sheet.sheetRows.length - 1 <= selectedNoteProvider.selectedRow) {
      // Create a new row if we're at the last row
      sheet.sheetRows.insert(selectedNoteProvider.selectedRow + 1,
          SheetRows(notes: [], rowProperties: RowProperties(tempoNumber: 0)));
      rowSpacingList.insert(rowSpacingList.length, defaultNoteSpacing);
      rowSpacingProvider.updateRowSpacingList(rowSpacingList);

      // Update curly brace groups for the row insertion
      sheet.sheetProperties.updateCurlyBracesForRowInsertion(
          selectedNoteProvider.selectedRow + 1, 1);
    } else if (sheet
                .sheetRows[selectedNoteProvider.selectedRow + 1].notes.length +
            notesInCurrentBar >
        maxNotesPerRow) {
      // If the next row doesn't have enough space, create a new row
      sheet.sheetRows.insert(selectedNoteProvider.selectedRow + 1,
          SheetRows(notes: [], rowProperties: RowProperties(tempoNumber: 0)));
      rowSpacingList.insert(rowSpacingList.length, defaultNoteSpacing);
      rowSpacingProvider.updateRowSpacingList(rowSpacingList);

      // Update curly brace groups for the row insertion
      sheet.sheetProperties.updateCurlyBracesForRowInsertion(
          selectedNoteProvider.selectedRow + 1, 1);
    }
  }

  /// Moves the last bar from the current row to the next row
  void _moveMultipleOverflowingNotes(
    CurrentSelectedNoteProvider selectedNoteProvider,
    int lastBarStartIndex,
    int lastBarEndIndex,
  ) {
    _moveMultipleOverflowingNotesToRow(selectedNoteProvider, lastBarStartIndex,
        lastBarEndIndex, selectedNoteProvider.selectedRow + 1);
  }

  /// Moves multiple notes from the current row to a specific target row
  void _moveMultipleOverflowingNotesToRow(
    CurrentSelectedNoteProvider selectedNoteProvider,
    int startIndex,
    int endIndex,
    int targetRowIndex,
  ) {
    // Collect all notes to move
    List<MusicalNote> notesToMove = [];
    for (int i = startIndex; i <= endIndex; i++) {
      notesToMove
          .add(sheet.sheetRows[selectedNoteProvider.selectedRow].notes[i]);
    }

    // Remove the notes from the current row (in reverse order to maintain indices)
    for (int i = endIndex; i >= startIndex; i--) {
      sheet.sheetRows[selectedNoteProvider.selectedRow].notes.removeAt(i);
    }

    // Determine insertion index: after clef if present, otherwise at beginning
    int insertIndex = 0;
    if (sheet.sheetRows[targetRowIndex].notes.isNotEmpty &&
        sheet.sheetRows[targetRowIndex].notes[0].type == NoteType.clef) {
      insertIndex = 1;
    }

    // Insert the notes at the calculated position
    for (int i = 0; i < notesToMove.length; i++) {
      sheet.sheetRows[targetRowIndex].notes
          .insert(insertIndex + i, notesToMove[i]);
    }

    if (sheet.sheetRows[selectedNoteProvider.selectedRow].notes.isNotEmpty &&
        sheet.sheetRows[selectedNoteProvider.selectedRow].notes.last.type ==
            NoteType.bar) {
      sheet.sheetRows[selectedNoteProvider.selectedRow].notes.removeLast();
    }

    // Update spacing for both the current row and the target row
    updateRowSpacing(selectedNoteProvider.selectedRow, selectedNoteProvider,
        sheet.sheetRows[selectedNoteProvider.selectedRow].notes);
    updateRowSpacing(targetRowIndex, selectedNoteProvider,
        sheet.sheetRows[targetRowIndex].notes);

    // Update the cursor position to the target row
    if (selectedNoteProvider.insertionIndex >= maxNotesPerRow ||
        selectedNoteProvider.insertionIndex >
            (maxNotesPerRow - notesToMove.length)) {
      selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
          targetRowIndex, notesToMove.length - 1);
    }
  }

  void updateRowSpacing(
      int rowIndex,
      CurrentSelectedNoteProvider selectedNoteProvider,
      List<MusicalNote> notes) {
    final rowSpacingProvider = context.read<ListOfSpacingForEachRow>();
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

    // For Piano format, update spacing for entire connected group
    if (sheet.format == SheetFormat.twoRows) {
      _updateConnectedRowGroupSpacing(rowIndex, selectedNoteProvider,
          rowSpacingProvider, rowSpacingList, listOfSpacingSizes);
    } else {
      // Single format - original behavior
      _updateSingleRowSpacing(rowIndex, selectedNoteProvider, notes,
          rowSpacingProvider, rowSpacingList, listOfSpacingSizes);
    }
  }

  /// Updates spacing for a single row (original behavior)
  void _updateSingleRowSpacing(
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

    for (int i = 0; i < listOfSpacingSizes.length; i++) {
      if (clefAndKeySigLength + (countOfNormalNotes * listOfSpacingSizes[i]) <
          maxRowSize) {
        rowSpacingList[rowIndex] = listOfSpacingSizes[i];
        adjustedSpacingFitsAllNotesOnSingleLine = true;
        break;
      }
    }

    if (!adjustedSpacingFitsAllNotesOnSingleLine) {
      handleRowOverflow(selectedNoteProvider, rowSpacingProvider,
          rowSpacingList, listOfSpacingSizes.last, notes, maxRowSize);
    }

    rowSpacingProvider.updateRowSpacingList(rowSpacingList);
  }

  /// Updates spacing for connected row groups (Piano format)
  void _updateConnectedRowGroupSpacing(
      int rowIndex,
      CurrentSelectedNoteProvider selectedNoteProvider,
      ListOfSpacingForEachRow rowSpacingProvider,
      List<double> rowSpacingList,
      List<double> listOfSpacingSizes) {
    final int rowsPerGroup = sheet.format.rowsPerGroup;

    // Find the connected group that contains this row
    final int groupStartRow = (rowIndex ~/ rowsPerGroup) * rowsPerGroup;
    final int groupEndRow =
        math.min(groupStartRow + rowsPerGroup - 1, sheet.sheetRows.length - 1);

    // Calculate spacing requirements for each row in the group
    double maxClefAndKeySigLength = 0.0;
    double maxCountOfNormalNotes = 0.0;

    for (int i = groupStartRow; i <= groupEndRow; i++) {
      if (i < sheet.sheetRows.length) {
        var clefAndKeySigLength = 0.0;
        var countOfNormalNotes = 0.0;

        for (int j = 0; j < sheet.sheetRows[i].notes.length; j++) {
          final note = sheet.sheetRows[i].notes[j];

          if (note.type == NoteType.clef ||
              note.type == NoteType.timeSignature) {
            clefAndKeySigLength += getNoteWidth(note);
          } else if (note.type == NoteType.keySignature) {
            clefAndKeySigLength += getNoteWidth(note) + 10;
          } else {
            countOfNormalNotes++;
          }
        }

        // Use the row with the most space requirements to determine spacing
        maxClefAndKeySigLength =
            math.max(maxClefAndKeySigLength, clefAndKeySigLength);
        maxCountOfNormalNotes =
            math.max(maxCountOfNormalNotes, countOfNormalNotes);
      }
    }

    double maxRowSize = 1200;
    var adjustedSpacingFitsAllNotesOnSingleLine = false;
    double selectedSpacing = listOfSpacingSizes.last;

    // Find the appropriate spacing for the most demanding row
    for (int i = 0; i < listOfSpacingSizes.length; i++) {
      if (maxClefAndKeySigLength +
              (maxCountOfNormalNotes * listOfSpacingSizes[i]) <
          maxRowSize) {
        selectedSpacing = listOfSpacingSizes[i];
        adjustedSpacingFitsAllNotesOnSingleLine = true;
        break;
      }
    }

    // Apply the same spacing to all rows in the connected group
    for (int i = groupStartRow; i <= groupEndRow; i++) {
      if (i < sheet.sheetRows.length) {
        rowSpacingList[i] = selectedSpacing;
      }
    }

    if (!adjustedSpacingFitsAllNotesOnSingleLine) {
      // Find the row with the most notes to determine which one should overflow
      int mostNotesRowIndex = groupStartRow;
      int maxNotes = sheet.sheetRows[groupStartRow].notes.length;

      for (int i = groupStartRow + 1; i <= groupEndRow; i++) {
        if (i < sheet.sheetRows.length &&
            sheet.sheetRows[i].notes.length > maxNotes) {
          maxNotes = sheet.sheetRows[i].notes.length;
          mostNotesRowIndex = i;
        }
      }

      selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
          mostNotesRowIndex,
          sheet.sheetRows[mostNotesRowIndex].notes.length - 1);

      handleRowOverflow(
          selectedNoteProvider,
          rowSpacingProvider,
          rowSpacingList,
          listOfSpacingSizes.last,
          sheet.sheetRows[mostNotesRowIndex].notes,
          maxRowSize);
    } else {
      rowSpacingProvider.updateRowSpacingList(rowSpacingList);
    }
  }

  void _toggleDynamicsKeyboard() {
    setState(() {
      _showDynamicsKeyboard = !_showDynamicsKeyboard;
    });
  }

  void forceNewRow() {
    setState(() {
      if (sheet.sheetRows.isNotEmpty) {
        final selectedNoteProvider =
            context.read<CurrentSelectedNoteProvider>();
        final rowSpacingProvider = context.read<ListOfSpacingForEachRow>();
        var rowSpacingList = rowSpacingProvider.rowSpacingList;

        final int rowsToAdd = sheet.format.rowsPerGroup;
        final List<String> clefs = sheet.format.defaultClefs;

        // Calculate where the current connected group ends
        final int rowsPerGroup = sheet.format.rowsPerGroup;
        final int groupStartRow =
            (selectedNoteProvider.selectedRow ~/ rowsPerGroup) * rowsPerGroup;
        final int groupEndRow = math.min(
            groupStartRow + rowsPerGroup - 1, sheet.sheetRows.length - 1);
        final int insertionPoint = groupEndRow + 1;

        // Insert new connected rows after the entire current connected group
        for (int i = 0; i < rowsToAdd; i++) {
          final newRow = SheetRows(
              notes: [], rowProperties: RowProperties(tempoNumber: 0));

          // Add appropriate clef for each row
          if (i < clefs.length) {
            newRow.notes.add(MusicalNote(
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

        rowSpacingProvider.updateRowSpacingList(rowSpacingList);

        // Update curly brace groups for the row insertion
        sheet.sheetProperties
            .updateCurlyBracesForRowInsertion(insertionPoint, rowsToAdd);

        // Determine which row in the new group to move to
        // For piano mode: move to the same type of row (treble to treble, bass to bass)
        int targetRowIndex = insertionPoint; // Default to first new row

        if (sheet.format == SheetFormat.twoRows && rowsToAdd == 2) {
          // In piano mode, determine if current row is treble or bass
          final currentRowIndex = selectedNoteProvider.selectedRow;
          final isCurrentRowTreble = _isRowInTreblePosition(currentRowIndex);

          // Move to the corresponding row type in the new group
          targetRowIndex = isCurrentRowTreble
              ? insertionPoint // Treble row (first in new group)
              : insertionPoint + 1; // Bass row (second in new group)
        }

        // Move cursor to the appropriate row in the new group
        selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
            targetRowIndex, clefs.isNotEmpty ? 0 : -1);

        print(
            "Added $rowsToAdd new row(s). Total rows: ${sheet.sheetRows.length}");
      }
    });
  }

  // Remove the last note from the list
  void handleBackspacePress() {
    // Clear any active highlighting first to prevent app crashes
    // when notes in the highlight range get removed
    _clearHighlighting();

    setState(() {
      final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

      if (selectedNoteProvider.selectedRow == 0 &&
          selectedNoteProvider.insertionIndex == 0) {
        return;
      }

      final rowSpacingProvider = context.read<ListOfSpacingForEachRow>();
      var rowSpacingList = rowSpacingProvider.rowSpacingList;
      final selectedRow = selectedNoteProvider.selectedRow;
      int selectedIndex = selectedNoteProvider.selectedIndex;
      final notes = sheet.sheetRows[selectedRow].notes;

      if (notes.isEmpty) {
        sheet.sheetRows.remove(sheet.sheetRows[selectedRow]);

        rowSpacingList.remove(rowSpacingList[selectedRow]);
        rowSpacingProvider.updateRowSpacingList(rowSpacingList);

        selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
            selectedRow - 1,
            sheet.sheetRows[selectedRow - 1].notes.isEmpty
                ? 0
                : sheet.sheetRows[selectedRow - 1].notes.length - 1);
      } else if (notes.isNotEmpty && selectedNoteProvider.insertionIndex >= 0) {
        if (selectedIndex >= notes.length) {
          selectedIndex = notes.length - 1;
        }

        MusicalNote noteToRemove = notes[selectedIndex];

        // Handle slur indices
        for (var note in notes) {
          if (note.slurEndIndex == selectedNoteProvider.insertionIndex) {
            note.slurEndIndex = null;
          }
        }

        // Save state for undo before removing the note
        context.read<SheetUndoManager>().saveState(sheet.sheetRows);

        // Remove the note
        notes.remove(noteToRemove);

        // Update cursor position before removing the note
        selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
            selectedRow, selectedIndex - 1);

        // After removing the note, check and update crescendo/decrescendo end indices
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

        selectedNoteProvider.adjustSlurIndicesForSpaceNote(
            noteToRemove, notes, removedNoteIndex, false);
      }

      updateRowSpacing(selectedRow, selectedNoteProvider, notes);

      // Mark as changed for auto-save
      _markAsChanged();
    });
  }

  // Helper method to clear any active highlighting
  void _clearHighlighting() {
    // Use the callback to clear highlighting in MusicSheetContainer
    if (_clearHighlightingCallback != null) {
      _clearHighlightingCallback!();
    }
  }

  // Save the current screenshot to the gallery and show a toast
  Future<void> handleSavePress() async {
    try {
      final image = await screenshotController.capture();
      if (image != null) {
        await saveImageToGallery(image);
        ToastUtils.showToast("Saved to Camera Roll!");
      } else {
        ToastUtils.showToast("Screenshot capture failed!", isError: true);
      }
    } catch (e) {
      print("Screenshot error: $e");
      ToastUtils.showToast("Screenshot failed: ${e.toString()}", isError: true);
    }
  }

  Future<void> handleExportPress() async {
    try {
      // Show loading overlay with music animation
      _showLoadingOverlay();

      final rowSpacingProvider = context.read<RowSpacingProvider>();

      // Use the new multi-page export functionality
      await PdfExporter.exportMultiPageToPdf(
        sheetRows: sheet.sheetRows,
        rowSpacing: rowSpacingProvider.rowSpacing,
        title: sheet.sheetProperties.title,
        composer: sheet.sheetProperties.composer,
        screenshotController: screenshotController,
        sheetFormat: sheet.format,
        updateSheetForCapture: (int startRow, int endRow, bool showTitle) {
          // Update the MusicSheetContainer to show only specific rows
          setState(() {
            _pdfRenderStartRow = startRow;
            _pdfRenderEndRow = endRow;
            _pdfShowTitleAndComposer = showTitle;
          });
        },
        captureScreenshot: () async {
          final image = await screenshotController.capture();
          if (image == null) {
            throw Exception('Failed to capture screenshot');
          }
          return image;
        },
      );

      // Remove loading overlay
      _removeLoadingOverlay();

      // Reset PDF rendering state to show all rows normally
      setState(() {
        _pdfRenderStartRow = null;
        _pdfRenderEndRow = null;
        _pdfShowTitleAndComposer = true;
      });

      ToastUtils.showToast("Multi-page PDF exported successfully!");
    } catch (e) {
      // Remove loading overlay if still showing
      _removeLoadingOverlay();

      print("Export error: $e");
      ToastUtils.showToast("Export failed: ${e.toString()}", isError: true);
    }
  }

  void _showBarPopup(BuildContext context) {
    _removeBarOverlay(); // Remove any existing overlay first

    // Trigger haptic feedback when bars popup appears
    HapticFeedbackUtils.lightVibration();

    final screenSize = MediaQuery.of(context).size;
    final List<String> unicodeOptions = [
      '\ue030',
      '\ue031',
      '\ue032',
      '\ue040',
      '\ue041',
      '\ue042',
    ];
    const double popupWidth = 200.0;
    const double buttonSize = 80.0;
    const int crossAxisCount = 3;
    final int rowCount = (unicodeOptions.length / crossAxisCount).ceil();
    final double popupHeight = (buttonSize * rowCount) + 32.0;

    _barOverlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeBarOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: (screenSize.width - popupWidth) / 2,
            bottom: 85,
            child: Material(
              elevation: 0,
              borderRadius: BorderRadius.circular(PopupTheme.borderRadius),
              child: Container(
                padding: const EdgeInsets.all(PopupTheme.standardPadding),
                decoration: PopupTheme.dialogDecoration,
                width: popupWidth,
                height: popupHeight,
                child: _buildBarPopupContent(unicodeOptions),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_barOverlayEntry!);
  }

  void _removeBarOverlay() {
    _barOverlayEntry?.remove();
    _barOverlayEntry = null;
  }

  void _showLoadingOverlay() {
    _removeLoadingOverlay(); // Remove any existing overlay first

    _loadingOverlayEntry = OverlayEntry(
      builder: (context) => const PdfExportLoadingOverlay(),
    );

    Overlay.of(context).insert(_loadingOverlayEntry!);
  }

  void _removeLoadingOverlay() {
    _loadingOverlayEntry?.remove();
    _loadingOverlayEntry = null;
  }

  Widget _buildBarPopupContent(List<String> unicodeOptions) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemCount: unicodeOptions.length,
      itemBuilder: (context, index) {
        final unicode = unicodeOptions[index];
        return InkWell(
          onTap: () {
            setState(() {
              _selectedBarUnicode = unicode;
            });
            handleKeyPress(MusicalNote(
              pitch: "D",
              octave: 4,
              type: NoteType.bar,
              isBeamed: false,
              unicodeCharacter: unicode,
            ));
            _removeBarOverlay();
          },
          child: Container(
            decoration: PopupTheme.gridItemDecoration,
            child: Center(
                child: Transform.translate(
              offset: const Offset(0, 20),
              child: Text(
                unicode,
                style: const TextStyle(
                  fontFamily: 'Bravura',
                  fontSize: 40,
                  color: PopupTheme.textPrimary,
                ),
              ),
            )),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = MediaQuery.of(context).size;
    final statusBarHeight = mediaQuery.padding.top;
    final double musicSheetWidth = sheet.format.config.musicSheetWidth;
    final selectRowsModeProvider = Provider.of<SelectRowsModeProvider>(context);

    return Scaffold(
        body: SafeArea(
            // Keeps content out of status bar area
            top: true,
            bottom: false,
            child: Column(children: [
              // "AppBar" that's only as tall as the status bar

              Expanded(
                child: Stack(
                  children: [
                    // Music Sheet taking full available height above the keyboard
                    Positioned.fill(
                      child: Column(
                        children: [
                          MusicSheetContainer(
                            screenSize: screenSize,
                            screenshotController: screenshotController,
                            sheetNoteRows: sheet.sheetRows,
                            sheetFormat: sheet.format,
                            musicSheetWidth: musicSheetWidth,
                            statusBarHeight: statusBarHeight,
                            sheetProperties: sheet.sheetProperties,
                            renderStartRow: _pdfRenderStartRow,
                            renderEndRow: _pdfRenderEndRow,
                            showTitleAndComposer: _pdfShowTitleAndComposer,
                            onClearHighlightingCallback:
                                (clearHighlightingCallback) {
                              _clearHighlightingCallback =
                                  clearHighlightingCallback;
                            },
                            onButtonStateCallbacks:
                                (shouldShowTieButton, shouldShowFlipNote) {
                              _shouldShowTieButtonCallback =
                                  shouldShowTieButton;
                              _shouldShowFlipNoteCallback = shouldShowFlipNote;
                            },
                            onZoomToNoteCallback: (zoomToNoteCallback) {
                              _zoomToNoteCallback = zoomToNoteCallback;
                            },
                            onCopyRowsCallback: _copySelectedRows,
                          ),
                          const Spacer(), // Pushes the keyboard container to the bottom
                        ],
                      ),
                    ),

                    // Floating Tools Menu Button - Top Right
                    if (!selectRowsModeProvider.isSelectRowsMode)
                      Positioned(
                        top: 10,
                        right: 5,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              showToolsMenu = !showToolsMenu;
                              showMenu = false;
                            });
                          },
                          child: Container(
                            width: 35,
                            height: 35,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.black,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  spreadRadius: 2,
                                  blurRadius: 5,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.build,
                              color: Color.fromARGB(255, 0, 0, 0),
                              size: 24,
                            ),
                          ),
                        ),
                      ),

                    // Tap outside to close menu (positioned first so it's behind the menu)
                    if (showToolsMenu)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              showToolsMenu = false;
                              showMenu = false;
                            });
                          },
                          child: Container(
                            color: Colors.transparent,
                          ),
                        ),
                      ),

                    // Popup Menu - appears next to the menu button (positioned after overlay so it's on top)
                    if (showToolsMenu)
                      Positioned(
                        top: statusBarHeight + 15, // Below the menu button
                        right: 15,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 150,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      showToolsMenu = false;
                                    });
                                    showDialog(
                                      context: context,
                                      builder: (context) => TitlePopup(
                                        initialTitle:
                                            sheet.sheetProperties.title,
                                        initialComposer:
                                            sheet.sheetProperties.composer,
                                        onSave: (newTitle, newComposer) {
                                          setState(() {
                                            sheet.sheetProperties.title =
                                                newTitle;
                                            sheet.sheetProperties.composer =
                                                newComposer;
                                          });
                                        },
                                      ),
                                    );
                                  },
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.title,
                                            size: 20, color: Colors.black),
                                        SizedBox(width: 8),
                                        Text('Title',
                                            style: TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ),
                                // Divider
                                Container(
                                  height: 1,
                                  color: Colors.grey[300],
                                ),
                                // Add Button
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      showToolsMenu = false;
                                    });
                                    forceNewRow();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.add,
                                            size: 20, color: Colors.black),
                                        SizedBox(width: 8),
                                        Text('Add New Line',
                                            style: TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ),
                                // Divider
                                Container(
                                  height: 1,
                                  color: Colors.grey[300],
                                ),
                                // Tempo Button
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      showToolsMenu = false;
                                    });
                                    final selectedNoteProvider = context
                                        .read<CurrentSelectedNoteProvider>();
                                    final currentRowProperties = sheet
                                        .sheetRows[
                                            selectedNoteProvider.selectedRow]
                                        .rowProperties;
                                    showDialog(
                                      context: context,
                                      builder: (context) => TempoPopup(
                                        initialTempo:
                                            currentRowProperties.tempoNumber,
                                        initialSwing:
                                            currentRowProperties.swing,
                                        initialSwingText:
                                            currentRowProperties.swingText,
                                        onSave: (tempo, swing, swingText) {
                                          setState(() {
                                            sheet
                                                .sheetRows[selectedNoteProvider
                                                    .selectedRow]
                                                .rowProperties
                                                .tempoNumber = tempo;
                                            sheet
                                                .sheetRows[selectedNoteProvider
                                                    .selectedRow]
                                                .rowProperties
                                                .swing = swing;
                                            sheet
                                                .sheetRows[selectedNoteProvider
                                                    .selectedRow]
                                                .rowProperties
                                                .swingText = swingText;
                                          });
                                        },
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.speed,
                                            size: 20, color: Colors.black),
                                        SizedBox(width: 8),
                                        Text('Tempo',
                                            style: TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ),
                                // Divider
                                Container(
                                  height: 1,
                                  color: Colors.grey[300],
                                ),
                                // Rehearsal Markings Button
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      showToolsMenu = false;
                                    });
                                    final selectedNoteProvider = context
                                        .read<CurrentSelectedNoteProvider>();

                                    // Check if there's a selected note
                                    if (sheet
                                            .sheetRows[selectedNoteProvider
                                                .selectedRow]
                                            .notes
                                            .isEmpty ||
                                        selectedNoteProvider.selectedIndex >=
                                            sheet
                                                .sheetRows[selectedNoteProvider
                                                    .selectedRow]
                                                .notes
                                                .length) {
                                      // Show message if no note is selected
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Please select a note first'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                      return;
                                    }

                                    showDialog(
                                      context: context,
                                      builder: (context) =>
                                          RehearsalMarkingsPopup(
                                        onSave: (rehearsalMarking) {
                                          setState(() {
                                            final selectedNote = sheet
                                                    .sheetRows[
                                                        selectedNoteProvider
                                                            .selectedRow]
                                                    .notes[
                                                selectedNoteProvider
                                                    .selectedIndex];
                                            selectedNote.rehearsalMarking =
                                                rehearsalMarking;
                                          });
                                        },
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.music_note,
                                            size: 20, color: Colors.black),
                                        SizedBox(width: 8),
                                        Text('Rehearsal',
                                            style: TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ),
                                // Divider
                                Container(
                                  height: 1,
                                  color: Colors.grey[300],
                                ),
                                // Select Rows Button
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      showToolsMenu = false;
                                    });
                                    final selectRowsModeProvider =
                                        context.read<SelectRowsModeProvider>();
                                    selectRowsModeProvider
                                        .enterSelectRowsMode();
                                    // Clear any highlighted notes when entering select rows mode
                                    _clearHighlighting();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.check_box_outlined,
                                            size: 20, color: Colors.black),
                                        SizedBox(width: 8),
                                        Text('Select Rows',
                                            style: TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ),
                                // Divider
                                Container(
                                  height: 1,
                                  color: Colors.grey[300],
                                ),
                                // Clipboard Button
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      showToolsMenu = false;
                                    });
                                    _showClipboardPopup();
                                  },
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.content_paste,
                                            size: 20, color: Colors.black),
                                        SizedBox(width: 8),
                                        Text('Clipboard',
                                            style: TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ),

                                // Title Button
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Floating Menu Button - Top left
                    Positioned(
                      top: 10,
                      left: 5,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            showMenu = !showMenu;
                            showToolsMenu = false;
                          });
                        },
                        child: Container(
                          width: 35,
                          height: 35,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.black,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.menu,
                            color: Color.fromARGB(255, 0, 0, 0),
                            size: 24,
                          ),
                        ),
                      ),
                    ),

                    // Tap outside to close menu (positioned first so it's behind the menu)
                    if (showMenu)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              showMenu = false;
                              showToolsMenu = false;
                            });
                          },
                          child: Container(
                            color: Colors.transparent,
                          ),
                        ),
                      ),

                    // Popup Menu - appears next to the menu button (positioned after overlay so it's on top)
                    if (showMenu)
                      Positioned(
                        top: statusBarHeight + 15, // Below the menu button
                        left: 15,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Home Button
                                InkWell(
                                  onTap: () async {
                                    setState(() {
                                      showMenu = false;
                                    });
                                    // Save the sheet before navigating home
                                    await _saveSheetToDatabase();
                                    // Reset insertion and selected note index to default
                                    final selectedNoteProvider = context
                                        .read<CurrentSelectedNoteProvider>();
                                    selectedNoteProvider
                                        .updateSelectedIndexAndInsertionPoint(
                                            0, -1);
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      '/',
                                      (route) => false,
                                    );
                                  },
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.home,
                                            size: 20, color: Colors.black),
                                        SizedBox(width: 8),
                                        Text('Home',
                                            style: TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ),
                                // Divider
                                Container(
                                  height: 1,
                                  color: Colors.grey[300],
                                ),
                                // Save Button
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      showMenu = false;
                                    });
                                    handleSavePress();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.save,
                                            size: 20, color: Colors.black),
                                        SizedBox(width: 8),
                                        Text('Save',
                                            style: TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ),
                                // Divider
                                Container(
                                  height: 1,
                                  color: Colors.grey[300],
                                ),
                                // Export Button
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      showMenu = false;
                                    });
                                    handleExportPress();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.picture_as_pdf,
                                            size: 20, color: Colors.black),
                                        SizedBox(width: 8),
                                        Text('Export',
                                            style: TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Keyboard Section Pinned to Bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ColoredBox(
                        color: const Color.fromARGB(255, 255, 253, 253),
                        child: Container(
                          height: 314,
                          padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  if (_showDynamicsKeyboard)
                                    DynamicsKeyboard(
                                      onToggleKeyboard: _toggleDynamicsKeyboard,
                                      sheetNoteRows: sheet.sheetRows,
                                    )
                                  else
                                    NotesKeyboardLayout(
                                      sheetNoteRows: sheet.sheetRows,
                                      showNotesKeyboard: showNotesKeyboard,
                                      sheetFormat: sheet.format,
                                      onToggleKeyboard: (isNotes) {
                                        setState(() {
                                          showNotesKeyboard = isNotes;
                                        });
                                      },
                                      onKeyPress: handleKeyPress,
                                    ),
                                ],
                              ),
                              if (!_showDynamicsKeyboard)
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(width: 12),
                                      //Dynamics button
                                      Flexible(
                                          flex: 1, // 10%
                                          child: SizedBox(
                                            height: 30,
                                            child: ElevatedButton(
                                              onPressed:
                                                  _toggleDynamicsKeyboard,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.grey[100],
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  side: BorderSide(
                                                      color: Colors.black,
                                                      width: 1),
                                                ),
                                                padding: EdgeInsets.zero,
                                              ),
                                              child: Transform.translate(
                                                  offset: const Offset(-1, 1),
                                                  child: Text(
                                                    '  \uE52F',
                                                    style: const TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 27,
                                                      //fontWeight: FontWeight.bold,
                                                      fontFamily: 'Bravura',
                                                    ),
                                                  )),
                                            ),
                                          )),
                                      const SizedBox(width: 7),
                                      Flexible(
                                          flex: 2, // 20%
                                          child: Consumer<
                                              CurrentSelectedNoteProvider>(
                                            builder: (context,
                                                    selectedNoteProvider, _) =>
                                                GestureDetector(
                                              onTap: () {
                                                final now = DateTime.now();
                                                if (_lastTapTime != null &&
                                                    now.difference(
                                                            _lastTapTime!) <
                                                        const Duration(
                                                            seconds: 1)) {
                                                  // Double tap
                                                  setState(() {
                                                    isBeamLockActive =
                                                        !isBeamLockActive;
                                                    final isConnectedProvider =
                                                        context.read<
                                                            IsConnectedProvider>();
                                                    isConnectedProvider
                                                        .toggleConnection(true);
                                                  });
                                                } else {
                                                  // Single tap
                                                  if (isBeamLockActive) {
                                                    setState(() {
                                                      isBeamLockActive = false;
                                                      final isConnectedProvider =
                                                          context.read<
                                                              IsConnectedProvider>();
                                                      isConnectedProvider
                                                          .toggleConnection(
                                                              false);
                                                    });
                                                  } else {
                                                    if (sheet
                                                        .sheetRows[
                                                            selectedNoteProvider
                                                                .selectedRow]
                                                        .notes
                                                        .isNotEmpty) {
                                                      setState(() {
                                                        final selectedNote = sheet
                                                                .sheetRows[
                                                                    selectedNoteProvider
                                                                        .selectedRow]
                                                                .notes[
                                                            selectedNoteProvider
                                                                .selectedIndex];
                                                        selectedNote.isBeamed =
                                                            !selectedNote
                                                                .isBeamed;
                                                      });
                                                    }
                                                  }
                                                }
                                                _lastTapTime = now;
                                              },
                                              child: Container(
                                                //width: 85,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  color: isBeamLockActive
                                                      ? Colors.black
                                                      : (selectedNoteProvider
                                                                      .selectedIndex !=
                                                                  -1 &&
                                                              sheet
                                                                  .sheetRows[
                                                                      selectedNoteProvider
                                                                          .selectedRow]
                                                                  .notes
                                                                  .isNotEmpty &&
                                                              sheet
                                                                      .sheetRows[
                                                                          selectedNoteProvider
                                                                              .selectedRow]
                                                                      .notes
                                                                      .length >
                                                                  selectedNoteProvider
                                                                      .selectedIndex &&
                                                              sheet
                                                                  .sheetRows[
                                                                      selectedNoteProvider
                                                                          .selectedRow]
                                                                  .notes[selectedNoteProvider
                                                                      .selectedIndex]
                                                                  .isBeamed)
                                                          ? Colors.grey[400]
                                                          : Colors.grey[100],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.black,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      'BEAM',
                                                      style: TextStyle(
                                                        color: isBeamLockActive
                                                            ? Colors.white
                                                            : Colors.black,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        //fontFamily: 'Bravura',
                                                      ),
                                                    ),
                                                    if (isBeamLockActive)
                                                      const Icon(Icons.lock,
                                                          color: Colors.white,
                                                          size: 12),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          )),
                                      const SizedBox(width: 7),
                                      Flexible(
                                          flex: 2,
                                          child: SizedBox(
                                            height: 30,
                                            child: ElevatedButton(
                                              onPressed: () {
                                                handleKeyPress(MusicalNote(
                                                    pitch: "D",
                                                    octave: 4,
                                                    type: NoteType.space,
                                                    isBeamed: false,
                                                    unicodeCharacter:
                                                        _selectedBarUnicode));
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.grey[100],
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  side: BorderSide(
                                                      color: Colors.black,
                                                      width: 1),
                                                ),
                                                padding: EdgeInsets.zero,
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Text(
                                                    'SPACE',
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )),
                                      const SizedBox(width: 7),
                                      Flexible(
                                          flex: 2, // 20%
                                          child: SizedBox(
                                            //width: 95,
                                            height: 30,
                                            child: GestureDetector(
                                              onLongPress: () {
                                                _showBarPopup(context);
                                              },
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  handleKeyPress(MusicalNote(
                                                      pitch: "D",
                                                      octave: 4,
                                                      type: NoteType.bar,
                                                      isBeamed: false,
                                                      unicodeCharacter:
                                                          _selectedBarUnicode));
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.grey[100],
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    side: const BorderSide(
                                                        color: Colors.black,
                                                        width: 1),
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Text(
                                                      'BARS',
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: 10,
                                                    ),
                                                    Transform.translate(
                                                      offset:
                                                          const Offset(0, 8),
                                                      child: Text(
                                                        _selectedBarUnicode,
                                                        style: const TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 19,
                                                          fontFamily: 'Bravura',
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                          )),
                                      const SizedBox(width: 7),
                                      Flexible(
                                          flex: 1, // 10%
                                          child: SizedBox(
                                            //width: 45,
                                            height: 30,
                                            child: ElevatedButton(
                                              onPressed: handleBackspacePress,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.grey[100],
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  side: BorderSide(
                                                      color: Colors.black,
                                                      width: 1),
                                                ),
                                                padding: EdgeInsets.zero,
                                              ),
                                              child: const Icon(Icons.backspace,
                                                  color: Color(0xFF242038),
                                                  size: 20),
                                            ),
                                          )),
                                      const SizedBox(width: 12),
                                    ])
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),

              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 50,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.black,
                        width: 1,
                      ),
                    ),
                    color: Colors.white,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'AD BANNER',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ])));
  }
}
