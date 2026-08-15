import 'dart:async';
import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
import 'package:music_keyboard/models/row_properties.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/models/sheet_properties.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/models/keyboard_type.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/providers/is_connected_provider.dart';
import 'package:music_keyboard/src/providers/list_of_spacing_for_each_row.dart';
import 'package:music_keyboard/src/providers/selected_accidental_provider.dart';
import 'package:music_keyboard/src/widgets/keyboard/sheet_keyboard_widgets/dynamics_keyboard.dart';
import 'package:music_keyboard/src/widgets/main_sheet/music_sheet_container.dart';
import 'package:music_keyboard/src/utils/pdf_exporter.dart';
import 'package:music_keyboard/src/utils/screenshot_saver.dart';
import 'package:music_keyboard/src/utils/toast_utils.dart';
import 'package:music_keyboard/src/widgets/main_sheet/title_popup.dart';
import 'package:music_keyboard/src/widgets/keyboard/tempo_popup.dart';
import 'package:music_keyboard/src/widgets/keyboard/sheet_keyboard_widgets/rehearsal_markings_popup.dart';
import 'package:music_keyboard/src/providers/row_spacing_provider.dart';
import 'package:music_keyboard/src/providers/select_rows_mode_provider.dart';
import 'package:music_keyboard/src/utils/haptic_feedback_utils.dart';
import 'package:music_keyboard/src/widgets/shared/banner_ad_widget.dart';
import 'package:music_keyboard/src/services/dynamic_link_service.dart';
import 'package:music_keyboard/src/services/firestore_service.dart';
import 'package:music_keyboard/src/providers/auth_provider.dart' as app;
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:music_keyboard/src/screens/keyboard_screen/row_overflow_controller.dart';
import 'package:music_keyboard/src/screens/keyboard_screen/chord_handling_controller.dart';
import 'package:music_keyboard/src/screens/keyboard_screen/backspace_handler.dart';
import 'package:music_keyboard/src/screens/keyboard_screen/clipboard_service.dart';
import 'package:music_keyboard/src/screens/keyboard_screen/auto_save_controller.dart';
import 'package:music_keyboard/src/screens/keyboard_screen/keyboard_screen_tools_menu.dart';
import 'package:music_keyboard/src/screens/keyboard_screen/bar_popup.dart';
import 'package:music_keyboard/src/screens/keyboard_screen/loading_overlay.dart';
import 'package:music_keyboard/src/screens/keyboard_screen/keyboard_layout_switcher.dart'
    as keyboard_layout_switcher;

class KeyboardScreen extends StatelessWidget {
  const KeyboardScreen({super.key, this.initialSheet});

  final Sheet? initialSheet;
  static const routeName = '/keyboard';

  @override
  Widget build(BuildContext context) {
    final Sheet? routeArgs =
        initialSheet ?? ModalRoute.of(context)?.settings.arguments as Sheet?;

    return NoteInputScreen(initialSheet: routeArgs);
  }
}

class NoteInputScreen extends StatefulWidget {
  const NoteInputScreen({super.key, this.initialSheet});

  final Sheet? initialSheet;

  @override
  _NoteInputScreenState createState() => _NoteInputScreenState();
}

class _NoteInputScreenState extends State<NoteInputScreen>
    implements
        RowOverflowHost,
        ChordHandlingHost,
        BackspaceHandlerHost,
        ClipboardHost,
        AutoSaveHost {
  final ScreenshotController screenshotController = ScreenshotController();
  @override
  late Sheet sheet;
  @override
  int maxNotesPerRow = 18;
  @override
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
  @override
  bool isBeamLockActive = false;
  DateTime? _lastTapTime;
  bool isViewingOtherUsersSheet = false;

  String _selectedBarUnicode = '\ue030';
  final BarPopupOverlay _barPopup = BarPopupOverlay();
  final LoadingOverlayController _loadingOverlay = LoadingOverlayController();

  VoidCallback? _clearHighlightingCallback;
  @override
  VoidCallback? get clearHighlightingCallback => _clearHighlightingCallback;

  Function()? _shouldShowTieButtonCallback;
  Function()? _shouldShowFlipNoteCallback;

  Function(int row, int index)? _zoomToNoteCallback;

  VoidCallback? _guitarKeyboardResetCallback;

  int? _pdfRenderStartRow;
  int? _pdfRenderEndRow;
  bool _pdfShowTitleAndComposer = true;

  VoidCallback? _guitarSpaceHandler;

  /// Reset guitar keyboard technique states when a new row is created
  void resetGuitarKeyboardTechniqueStates() {
    if (_guitarKeyboardResetCallback != null) {
      _guitarKeyboardResetCallback!();
    }
  }

  // Database helper for clipboard operations
  late SheetDatabaseHelper _dbHelper;
  @override
  SheetDatabaseHelper get dbHelper => _dbHelper;
  final FirestoreService _firestoreService = FirestoreService();
  @override
  FirestoreService get firestoreService => _firestoreService;
  String? _syncUserId;
  @override
  String? get syncUserId => _syncUserId;

  late final RowOverflowController rowOverflowController =
      RowOverflowController(host: this);
  late final ChordHandlingController chordController =
      ChordHandlingController(host: this);
  late final BackspaceHandler backspaceHandler = BackspaceHandler(host: this);
  late final ClipboardService clipboardService = ClipboardService(host: this);
  late final AutoSaveController autoSaveController =
      AutoSaveController(host: this);

  @override
  void hostSetState(VoidCallback fn) => setState(fn);

  @override
  void markAsChanged() => autoSaveController.markAsChanged();

  void _markAsChanged() => autoSaveController.markAsChanged();

  @override
  bool updateRowSpacing(
          int rowIndex,
          CurrentSelectedNoteProvider selectedNoteProvider,
          List<MusicalNote> notes) =>
      rowOverflowController.updateRowSpacing(
          rowIndex, selectedNoteProvider, notes);

  void handleAddToChord(MusicalNote note) {
    setState(() => chordController.handleAddToChord(note));
  }

  void handleConvertToChord(MusicalNote note) {
    setState(() => chordController.handleConvertToChord(note));
  }

  void handleRemoveFromChord(MusicalNote note) {
    setState(() => chordController.handleRemoveFromChord(note));
  }

  void handleFavouriteChordTapped(MusicalNote chord) {
    setState(() =>
        chordController.handleFavouriteChordTapped(chord, updateRowSpacing));
  }

  void _clearHighlighting() => backspaceHandler.clearHighlighting();

  void handleBackspacePress() {
    setState(() {
      backspaceHandler.handleBackspacePress();
    });
  }

  void forceNewRow() {
    setState(() {
      final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
      rowOverflowController.forceNewRow(selectedNoteProvider);
    });
  }

  @override
  void initState() {
    super.initState();
    // Initialize sheetNoteRows with passed data or default
    sheet = widget.initialSheet ??
        Sheet(sheetRows: [
          SheetRows(chords: [], rowProperties: RowProperties(tempoNumber: 0))
        ], sheetProperties: SheetProperties());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize dbHelper with auth info
    final authProvider = Provider.of<app.AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    final ownerName = authProvider.user?.displayName;
    _dbHelper = SheetDatabaseHelper(
      userId: userId,
      ownerName: ownerName,
    );
    _syncUserId = userId;

    if (sheet.userId != null && sheet.userId!.isNotEmpty && userId != null) {
      isViewingOtherUsersSheet = sheet.userId != userId;
    } else {
      isViewingOtherUsersSheet = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rowSpacingListProvider = context.read<ListOfSpacingForEachRow>();
      List<double> initialSpacing =
          List.filled(sheet.sheetRows.length, 26.0, growable: true);
      rowSpacingListProvider.updateRowSpacingList(initialSpacing);

      final rowSpacingProvider = context.read<RowSpacingProvider>();
      rowSpacingProvider
          .updateBetweenRowSpacing(sheet.sheetProperties.rowSpacing);

      final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
      if (sheet.sheetRows.isNotEmpty && sheet.sheetRows[0].chords.isNotEmpty) {
        selectedNoteProvider.updateSelectedIndexAndInsertionPoint(0, 0);
      }

      for (int i = 0; i < sheet.sheetRows.length; i++) {
        updateRowSpacing(i, selectedNoteProvider, sheet.sheetRows[i].chords);
      }

      autoSaveController.initializeAutoSave();
    });
  }

  @override
  void dispose() {
    if (autoSaveController.hasUnsavedChanges && sheet.id != null) {
      _dbHelper.updateSheet(sheet);
      if (_syncUserId != null) {
        _firestoreService.updateSheet(sheet, _syncUserId!);
      }
    }
    autoSaveController.dispose();

    _barPopup.remove();
    _loadingOverlay.remove();
    super.dispose();
  }

  bool handleKeyPress(MusicalNote note) {
    bool rowOverflowed = false;
    try {
      final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
      final accidentalProvider = context.read<SelectedAccidentalProvider>();

      final selectedAccidental = accidentalProvider.selectedAccidental;

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
          clefType: note.clefType,
          childNotes: note.childNotes,
          duration: note.duration);

      setState(() {
        selectedNoteProvider.addNote(
            noteWithAccidental, sheet.sheetRows, context);

        rowOverflowed = updateRowSpacing(
            selectedNoteProvider.selectedRow,
            selectedNoteProvider,
            sheet.sheetRows[selectedNoteProvider.selectedRow].chords);

        if (rowOverflowed && sheet.keyboardType == KeyboardType.guitarTab) {
          resetGuitarKeyboardTechniqueStates();
        }

        _markAsChanged();

        if (_shouldShowTieButtonCallback != null) {
          _shouldShowTieButtonCallback!();
        }
        if (_shouldShowFlipNoteCallback != null) {
          _shouldShowFlipNoteCallback!();
        }

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
    return rowOverflowed;
  }

  void _toggleDynamicsKeyboard() {
    setState(() {
      _showDynamicsKeyboard = !_showDynamicsKeyboard;
    });
  }

  Future<void> _saveSheetCopy() async {
    try {
      final authProvider =
          Provider.of<app.AuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.uid;

      if (currentUserId == null) {
        ToastUtils.showToast("You must be logged in to save a copy",
            isError: true);
        return;
      }

      final copiedSheet = Sheet(
        sheetRows: sheet.sheetRows.map((row) {
          final clonedNotes = row.chords
              .map((note) => MusicalNote(
                    pitch: note.pitch,
                    octave: note.octave,
                    type: note.type,
                    isBeamed: note.isBeamed,
                    unicodeCharacter: note.unicodeCharacter,
                    noteY: note.noteY,
                    topTimeSignatureCharacter: note.topTimeSignatureCharacter,
                    bottomTimeSignatureCharacter:
                        note.bottomTimeSignatureCharacter,
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
              tempoNumber: row.rowProperties.tempoNumber,
              swing: row.rowProperties.swing,
              swingText: row.rowProperties.swingText,
            ),
          );
        }).toList(),
        sheetProperties: SheetProperties(
          title: sheet.sheetProperties.title,
          composer: sheet.sheetProperties.composer,
          rowSpacing: sheet.sheetProperties.rowSpacing,
          curlyBraceGroups: sheet.sheetProperties.curlyBraceGroups
              .map((group) => CurlyBraceGroup(
                  startRow: group.startRow, endRow: group.endRow))
              .toList(),
        ),
        format: sheet.format,
        keyboardType: sheet.keyboardType,
      );

      await _dbHelper.insertSheet(copiedSheet);
      if (_syncUserId != null) {
        await _firestoreService.addSheet(copiedSheet, _syncUserId!);
      }

      ToastUtils.showToast("Sheet copied successfully!");

      Navigator.pushReplacementNamed(
        context,
        KeyboardScreen.routeName,
        arguments: copiedSheet,
      );
    } catch (e) {
      print('Error saving sheet copy: $e');
      ToastUtils.showToast("Failed to save copy: ${e.toString()}",
          isError: true);
    }
  }

  Future<void> _shareSheet() async {
    final authProvider = Provider.of<app.AuthProvider>(context, listen: false);
    if (authProvider.user == null) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(
              'Sign in to share this sheet with friends.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            actions: <Widget>[
              Center(
                child: SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                      Navigator.pushNamed(
                          context, '/login'); // Go to login screen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF242038),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Sign In / Sign Up',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    try {
      final dynamicLinkService = DynamicLinkService();
      final Uri shareLink = await dynamicLinkService.createDynamicLink(sheet);
      final shareText =
          "Check out this sheet written on Mote'z Notes $shareLink";
      await Share.share(shareText);
    } catch (e) {
      print('Error sharing sheet: $e');
      ToastUtils.showToast("Failed to share sheet!", isError: true);
    }
  }

  Future<void> handleExportPress() async {
    try {
      _loadingOverlay.show(context);

      final rowSpacingProvider = context.read<RowSpacingProvider>();

      await PdfExporter.exportMultiPageToPdf(
        sheetRows: sheet.sheetRows,
        rowSpacing: rowSpacingProvider.rowSpacing,
        title: sheet.sheetProperties.title,
        composer: sheet.sheetProperties.composer,
        screenshotController: screenshotController,
        sheetFormat: sheet.format,
        updateSheetForCapture: (int startRow, int endRow, bool showTitle) {
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

      _loadingOverlay.remove();

      setState(() {
        _pdfRenderStartRow = null;
        _pdfRenderEndRow = null;
        _pdfShowTitleAndComposer = true;
      });

      ToastUtils.showToast("Multi-page PDF exported successfully!");
    } catch (e) {
      _loadingOverlay.remove();

      print("Export error: $e");
      ToastUtils.showToast("Export failed: ${e.toString()}", isError: true);
    }
  }

  void _showBarPopup(BuildContext context) {
    HapticFeedbackUtils.lightVibration();
    _barPopup.show(context, onSelected: (unicode) {
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
    });
  }

  Widget _buildKeyboardLayout() {
    return keyboard_layout_switcher.buildKeyboardLayout(
      sheet: sheet,
      showNotesKeyboard: showNotesKeyboard,
      onToggleKeyboard: (isNotes) {
        setState(() {
          showNotesKeyboard = isNotes;
        });
      },
      onKeyPress: handleKeyPress,
      onAddToChord: handleAddToChord,
      onRemoveFromChord: handleRemoveFromChord,
      onConvertToChord: handleConvertToChord,
      dbHelper: _dbHelper,
      onFavouriteChordTapped: handleFavouriteChordTapped,
      favouritesVersion: chordController.favouritesVersion,
      onRegisterSpaceHandler: (handler) {
        _guitarSpaceHandler = handler;
      },
      onRegisterResetHandler: (handler) {
        _guitarKeyboardResetCallback = handler;
      },
      onNewRowCreated: () {
        resetGuitarKeyboardTechniqueStates();
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
            top: true,
            bottom: false,
            child: Column(children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Column(
                        children: [
                          const SizedBox(height: 50),
                          MusicSheetContainer(
                            screenSize: screenSize,
                            screenshotController: screenshotController,
                            sheetNoteRows: sheet.sheetRows,
                            sheetFormat: sheet.format,
                            keyboardType: sheet.keyboardType,
                            musicSheetWidth: musicSheetWidth,
                            statusBarHeight: statusBarHeight,
                            sheetProperties: sheet.sheetProperties,
                            renderStartRow: _pdfRenderStartRow,
                            renderEndRow: _pdfRenderEndRow,
                            showTitleAndComposer: _pdfShowTitleAndComposer,
                            isReadOnly: isViewingOtherUsersSheet,
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
                            onCopyRowsCallback:
                                clipboardService.copySelectedRows,
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),

                    // Floating Tools Menu
                    if (!isViewingOtherUsersSheet)
                      KeyboardScreenToolsMenu(
                        showButton: !selectRowsModeProvider.isSelectRowsMode,
                        showToolsMenu: showToolsMenu,
                        statusBarHeight: statusBarHeight,
                        onToggleToolsMenu: () {
                          setState(() {
                            showToolsMenu = !showToolsMenu;
                            showMenu = false;
                          });
                        },
                        onDismiss: () {
                          setState(() {
                            showToolsMenu = false;
                            showMenu = false;
                          });
                        },
                        onTitleTap: () {
                          setState(() {
                            showToolsMenu = false;
                          });
                          showDialog(
                            context: context,
                            builder: (context) => TitlePopup(
                              initialTitle: sheet.sheetProperties.title,
                              initialComposer: sheet.sheetProperties.composer,
                              onSave: (newTitle, newComposer) {
                                setState(() {
                                  sheet.sheetProperties.title = newTitle;
                                  sheet.sheetProperties.composer = newComposer;
                                });
                                // Mark as changed for auto-save
                                _markAsChanged();
                              },
                            ),
                          );
                        },
                        onAddNewLineTap: () {
                          setState(() {
                            showToolsMenu = false;
                          });
                          forceNewRow();
                        },
                        onTempoTap: () {
                          setState(() {
                            showToolsMenu = false;
                          });
                          final selectedNoteProvider =
                              context.read<CurrentSelectedNoteProvider>();
                          final currentRowProperties = sheet
                              .sheetRows[selectedNoteProvider.selectedRow]
                              .rowProperties;
                          showDialog(
                            context: context,
                            builder: (context) => TempoPopup(
                              initialTempo: currentRowProperties.tempoNumber,
                              initialSwing: currentRowProperties.swing,
                              initialSwingText: currentRowProperties.swingText,
                              onSave: (tempo, swing, swingText) {
                                setState(() {
                                  sheet
                                      .sheetRows[
                                          selectedNoteProvider.selectedRow]
                                      .rowProperties
                                      .tempoNumber = tempo;
                                  sheet
                                      .sheetRows[
                                          selectedNoteProvider.selectedRow]
                                      .rowProperties
                                      .swing = swing;
                                  sheet
                                      .sheetRows[
                                          selectedNoteProvider.selectedRow]
                                      .rowProperties
                                      .swingText = swingText;
                                });
                              },
                            ),
                          );
                        },
                        onRehearsalTap: () {
                          setState(() {
                            showToolsMenu = false;
                          });
                          final selectedNoteProvider =
                              context.read<CurrentSelectedNoteProvider>();

                          // Check if there's a selected note
                          if (sheet.sheetRows[selectedNoteProvider.selectedRow]
                                  .chords.isEmpty ||
                              selectedNoteProvider.selectedIndex >=
                                  sheet
                                      .sheetRows[
                                          selectedNoteProvider.selectedRow]
                                      .chords
                                      .length) {
                            // Show message if no note is selected
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a note first'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          showDialog(
                            context: context,
                            builder: (context) => RehearsalMarkingsPopup(
                              onSave: (rehearsalMarking) {
                                setState(() {
                                  final selectedNote = sheet
                                          .sheetRows[
                                              selectedNoteProvider.selectedRow]
                                          .chords[
                                      selectedNoteProvider.selectedIndex];
                                  selectedNote.rehearsalMarking =
                                      rehearsalMarking;
                                });
                              },
                            ),
                          );
                        },
                        onSelectRowsTap: () {
                          setState(() {
                            showToolsMenu = false;
                          });
                          final selectRowsModeProvider =
                              context.read<SelectRowsModeProvider>();
                          selectRowsModeProvider.enterSelectRowsMode();
                          // Clear any highlighted notes when entering select rows mode
                          _clearHighlighting();
                        },
                        onClipboardTap: () {
                          setState(() {
                            showToolsMenu = false;
                          });
                          clipboardService.showClipboardPopup();
                        },
                      ),

                    // Floating Menu Button - Top left
                    Positioned(
                      top: 60,
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

                    // Floating Share Button - Below menu button
                    Positioned(
                      top: 105,
                      left: 5,
                      child: GestureDetector(
                        onTap: _shareSheet,
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
                            Icons.share,
                            color: Color.fromARGB(255, 0, 0, 0),
                            size: 24,
                          ),
                        ),
                      ),
                    ),

                    // Floating Favourite Chord Button - Below share button
                    Positioned(
                      top: 150,
                      left: 5,
                      child: Consumer<CurrentSelectedNoteProvider>(
                        builder: (context, selectedNoteProvider, _) {
                          final row = selectedNoteProvider.selectedRow;
                          final index = selectedNoteProvider.selectedIndex;
                          if (row < 0 ||
                              row >= sheet.sheetRows.length ||
                              index < 0 ||
                              index >= sheet.sheetRows[row].chords.length) {
                            return const SizedBox.shrink();
                          }
                          final note = sheet.sheetRows[row].chords[index];
                          if (note.type != NoteType.chord &&
                              note.type != NoteType.fret) {
                            return const SizedBox.shrink();
                          }
                          // Kick off a DB check only when the chord changes.
                          chordController.checkFavouriteStatus(note);
                          final isFavourited =
                              chordController.favouriteChordId != null;
                          return GestureDetector(
                            onTap: () => chordController.toggleFavourite(note),
                            child: Container(
                              width: 35,
                              height: 35,
                              decoration: BoxDecoration(
                                color: isFavourited
                                    ? Colors.red.shade50
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color:
                                      isFavourited ? Colors.red : Colors.black,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    spreadRadius: 2,
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isFavourited
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isFavourited ? Colors.red : Colors.black,
                                size: 20,
                              ),
                            ),
                          );
                        },
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
                        top: statusBarHeight + 65, // Below the menu button
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
                                    await autoSaveController
                                        .saveSheetToDatabase();
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

                    // Save Copy Widget - Read-Only Mode (Positioned above ad banner)
                    if (isViewingOtherUsersSheet)
                      Positioned(
                        bottom: 5, // Above the ad banner
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Material(
                            elevation: 5,
                            shadowColor: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${sheet.ownerName ?? 'Unknown'}'s sheet",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 46,
                                    child: ElevatedButton(
                                      onPressed: _saveSheetCopy,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF242038),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        elevation: 4,
                                      ),
                                      child: const Text(
                                        'Save Copy',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Keyboard Section Pinned to Bottom
                    if (!isViewingOtherUsersSheet)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: ColoredBox(
                          color: const Color.fromARGB(255, 255, 253, 253),
                          child: Container(
                            height: 357,
                            padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    if (_showDynamicsKeyboard)
                                      DynamicsKeyboard(
                                        onToggleKeyboard:
                                            _toggleDynamicsKeyboard,
                                        sheetNoteRows: sheet.sheetRows,
                                      )
                                    else
                                      _buildKeyboardLayout(),
                                  ],
                                ),
                                if (!_showDynamicsKeyboard)
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(width: 12),
                                        if (sheet.keyboardType !=
                                            KeyboardType.guitarTab) ...[
                                          //Dynamics button
                                          Flexible(
                                              flex: 1, // 10%
                                              child: SizedBox(
                                                height: 30,
                                                child: ElevatedButton(
                                                  onPressed:
                                                      _toggleDynamicsKeyboard,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.grey[100],
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      side: BorderSide(
                                                          color: Colors.black,
                                                          width: 1),
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                  child: Transform.translate(
                                                      offset:
                                                          const Offset(-1, 1),
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
                                                        selectedNoteProvider,
                                                        _) =>
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
                                                            .toggleConnection(
                                                                true);
                                                      });
                                                    } else {
                                                      // Single tap
                                                      if (isBeamLockActive) {
                                                        setState(() {
                                                          isBeamLockActive =
                                                              false;
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
                                                            .chords
                                                            .isNotEmpty) {
                                                          setState(() {
                                                            final selectedNote = sheet
                                                                    .sheetRows[
                                                                        selectedNoteProvider
                                                                            .selectedRow]
                                                                    .chords[
                                                                selectedNoteProvider
                                                                    .selectedIndex];
                                                            selectedNote
                                                                    .isBeamed =
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
                                                                      .chords
                                                                      .isNotEmpty &&
                                                                  sheet
                                                                          .sheetRows[selectedNoteProvider
                                                                              .selectedRow]
                                                                          .chords
                                                                          .length >
                                                                      selectedNoteProvider
                                                                          .selectedIndex &&
                                                                  sheet
                                                                      .sheetRows[
                                                                          selectedNoteProvider
                                                                              .selectedRow]
                                                                      .chords[selectedNoteProvider
                                                                          .selectedIndex]
                                                                      .isBeamed)
                                                              ? Colors.grey[400]
                                                              : Colors
                                                                  .grey[100],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                        color: Colors.black,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          'BEAM',
                                                          style: TextStyle(
                                                            color:
                                                                isBeamLockActive
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .black,
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        if (isBeamLockActive)
                                                          const Icon(Icons.lock,
                                                              color:
                                                                  Colors.white,
                                                              size: 12),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              )),
                                        ],
                                        const SizedBox(width: 7),
                                        Flexible(
                                            flex: 2,
                                            child: SizedBox(
                                              height: 30,
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  if (sheet.keyboardType ==
                                                      KeyboardType.guitarTab) {
                                                    // Use the guitar keyboard's space handler so that
                                                    // endIndices for active techniques (harmonic, bend,
                                                    // vibrato, etc.) are updated before the new fret
                                                    if (_guitarSpaceHandler !=
                                                        null) {
                                                      _guitarSpaceHandler!();
                                                    } else {
                                                      handleKeyPress(
                                                          MusicalNote(
                                                        pitch: 'G',
                                                        octave: 4,
                                                        type: NoteType.fret,
                                                        duration: 0.0,
                                                        childNotes: [],
                                                      ));
                                                    }
                                                  } else {
                                                    handleKeyPress(MusicalNote(
                                                        pitch: "D",
                                                        octave: 4,
                                                        type: NoteType.space,
                                                        isBeamed: false,
                                                        unicodeCharacter:
                                                            _selectedBarUnicode));
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.grey[100],
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
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
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.grey[100],
                                                    shape:
                                                        RoundedRectangleBorder(
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
                                                        MainAxisAlignment
                                                            .center,
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
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.black,
                                                            fontSize: 19,
                                                            fontFamily:
                                                                'Bravura',
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
                                                        BorderRadius.circular(
                                                            8),
                                                    side: BorderSide(
                                                        color: Colors.black,
                                                        width: 1),
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                ),
                                                child: const Icon(
                                                    Icons.backspace,
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
                      ),

                    const Align(
                      alignment: Alignment.topCenter,
                      child: BannerAdWidget(),
                    ),
                  ],
                ),
              ),
            ])));
  }
}
