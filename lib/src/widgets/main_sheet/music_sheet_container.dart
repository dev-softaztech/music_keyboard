import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/models/keyboard_type.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/providers/list_of_spacing_for_each_row.dart';
import 'package:music_keyboard/src/providers/row_spacing_provider.dart';
import 'package:music_keyboard/src/providers/select_rows_mode_provider.dart';
import 'package:music_keyboard/src/providers/undo_manager.dart';
import 'package:music_keyboard/models/sheet_properties.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_width_calculator.dart';
import 'package:music_keyboard/src/utils/pdf_exporter.dart';
import 'package:music_keyboard/src/widgets/main_sheet/music_sheet_gesture_controller.dart';
import 'package:music_keyboard/src/widgets/main_sheet/note_articulation_editor.dart';
import 'package:music_keyboard/src/widgets/main_sheet/music_sheet_painter.dart';
import 'package:music_keyboard/src/widgets/main_sheet/music_sheet_toolbar_buttons.dart';
import 'package:music_keyboard/src/widgets/keyboard/tempo_popup.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vector_math;

class MusicSheetContainer extends StatefulWidget {
  final Size screenSize;
  final ScreenshotController screenshotController;
  final List<SheetRows> sheetNoteRows;
  final SheetFormat sheetFormat;
  final KeyboardType keyboardType;
  final double musicSheetWidth;
  final double statusBarHeight;
  final SheetProperties sheetProperties;
  final Function(VoidCallback)? onClearHighlightingCallback;
  final Function(Function() shouldShowTieButton, Function() shouldShowFlipNote)?
      onButtonStateCallbacks;
  final Function(Function(int row, int index))? onZoomToNoteCallback;
  final Function()? onCopyRowsCallback;

  // New parameters for partial rendering
  final int? renderStartRow;
  final int? renderEndRow;
  final bool showTitleAndComposer;

  // Read-only mode flag
  final bool isReadOnly;

  const MusicSheetContainer({
    super.key,
    required this.screenSize,
    required this.screenshotController,
    required this.sheetNoteRows,
    required this.sheetFormat,
    required this.keyboardType,
    required this.musicSheetWidth,
    required this.statusBarHeight,
    required this.sheetProperties,
    this.onClearHighlightingCallback,
    this.onButtonStateCallbacks,
    this.onZoomToNoteCallback,
    this.onCopyRowsCallback,
    this.renderStartRow,
    this.renderEndRow,
    this.showTitleAndComposer = true,
    this.isReadOnly = false,
  });

  @override
  _MusicSheetContainerState createState() => _MusicSheetContainerState();
}

class _MusicSheetContainerState extends State<MusicSheetContainer>
    with SingleTickerProviderStateMixin
    implements MusicSheetGestureHost {
  late TransformationController _transformationController;
  late double initialScale;
  bool isZoomed = false;
  bool _showCursor = true;
  late Timer _cursorTimer;
  bool _showHighlightButtons = false;
  bool _showTieButton = false;
  bool _showDynamicRemoveButton = false;
  bool _showBeamAddButton = false;
  bool _showBeamRemoveButton = false;
  bool _showSlurRemoveButton = false;
  bool _showDecrescendoRemoveButton = false;
  bool _showCrescendoRemoveButton = false;
  bool _showTieRemoveState = false;
  bool _showTempoEditButton = false;
  bool _showFlipNoteButton = false;
  bool _showMuteRemoveButton = false;
  bool _showPinchHarmonicRemoveButton = false;
  bool _showHarmonicRemoveButton = false;
  bool _showVibratoRemoveButton = false;
  bool _showBendRemoveButton = false;
  bool _showPreBendRemoveButton = false;
  bool _showBendReleaseRemoveButton = false;
  bool _showPreBendReleaseRemoveButton = false;
  bool _showBendsPanel = false;

  late final MusicSheetGestureController _gesture =
      MusicSheetGestureController(host: this);

  int? get _dragStart => _gesture.dragStart;
  set _dragStart(int? value) => _gesture.dragStart = value;
  int? get _dragEnd => _gesture.dragEnd;
  set _dragEnd(int? value) => _gesture.dragEnd = value;
  int? get _dragRow => _gesture.dragRow;
  set _dragRow(int? value) => _gesture.dragRow = value;
  bool get _isDragging => _gesture.isDragging;
  set _isDragging(bool value) => _gesture.isDragging = value;
  set _isDraggingLeftHandle(bool value) =>
      _gesture.isDraggingLeftHandle = value;
  set _isDraggingRightHandle(bool value) =>
      _gesture.isDraggingRightHandle = value;
  set _fixedBoundary(int? value) => _gesture.fixedBoundary = value;
  int? get _editingDynamicIndex => _gesture.editingDynamicIndex;
  set _editingDynamicIndex(int? value) => _gesture.editingDynamicIndex = value;
  int? get _editingDynamicRow => _gesture.editingDynamicRow;
  set _editingDynamicRow(int? value) => _gesture.editingDynamicRow = value;
  bool get _isEditingDynamic => _gesture.isEditingDynamic;
  set _isEditingDynamic(bool value) => _gesture.isEditingDynamic = value;

  // MusicSheetGestureHost implementation
  @override
  TransformationController get transformationController =>
      _transformationController;
  @override
  List<SheetRows> get sheetNoteRows => widget.sheetNoteRows;
  @override
  SheetFormat get sheetFormat => widget.sheetFormat;
  @override
  KeyboardType get keyboardType => widget.keyboardType;
  @override
  bool get isReadOnly => widget.isReadOnly;
  @override
  void hostSetState(VoidCallback fn) => setState(fn);
  @override
  void zoomToNote(int rowIndex, int noteIndex) =>
      _zoomToNote(rowIndex, noteIndex);

  @override
  void onHighlightDismissed() {
    _showHighlightButtons = false;
    _showFlipNoteButton = _shouldShowFlipNote();
  }

  @override
  void onHighlightStarted() {
    _showHighlightButtons = true;
    _showTieButton = false;
    _showDynamicRemoveButton = false;
    _showFlipNoteButton = false;
  }

  @override
  void onSelectionCancelled() {
    _showHighlightButtons = false;
  }

  @override
  void updateBeamAddButtonDuringDrag() {
    _showBeamAddButton = _shouldShowBeamAdd();
  }

  @override
  void onNoteSelected() {
    // Reset buttons
    setState(() {
      _showHighlightButtons = false;
      _showBendsPanel = false;
      _showTieButton = false;
      _showDynamicRemoveButton = false;
      _showBeamAddButton = false;
      _showBeamRemoveButton = false;
      _showSlurRemoveButton = false;
      _showTempoEditButton = false;
      _showDecrescendoRemoveButton = false;
      _showCrescendoRemoveButton = false;

      _showMuteRemoveButton = false;
      _showPinchHarmonicRemoveButton = false;
      _showHarmonicRemoveButton = false;
      _showVibratoRemoveButton = false;
      _showBendRemoveButton = false;
      _showPreBendRemoveButton = false;
      _showBendReleaseRemoveButton = false;
      _showPreBendReleaseRemoveButton = false;

      _showFlipNoteButton = _shouldShowFlipNote();
    });

    var showDynamicRemoveButton = _shouldShowDynamicRemove();
    var showBeamRemoveButton = _shouldShowBeamRemove();
    var showBeamAddButton = _shouldShowBeamAdd();
    var showSlurRemoveButton = _shouldShowSlurRemove();
    var showDecrescendoRemoveButton = _shouldShowDecrescendoRemove();
    var showCrescendoRemoveButton = _shouldShowCrescendoRemove();
    var showTieButton = _shouldShowTieButton();
    var showTieRemoveState = _shouldShowTieRemove();
    var showTempoEditButton = _shouldShowTempoEdit();
    var showFlipNoteButton = _shouldShowFlipNote();

    var showMuteRemoveButton = _shouldShowMuteRemove();
    var showPinchHarmonicRemoveButton = _shouldShowPinchHarmonicRemove();
    var showHarmonicRemoveButton = _shouldShowHarmonicRemove();
    var showVibratoRemoveButton = _shouldShowVibratoRemove();
    var showBendRemoveButton = _shouldShowBendRemove();
    var showPreBendRemoveButton = _shouldShowPreBendRemove();
    var showBendReleaseRemoveButton = _shouldShowBendReleaseRemove();
    var showPreBendReleaseRemoveButton = _shouldShowPreBendReleaseRemove();

    setState(() {
      _showDynamicRemoveButton = showDynamicRemoveButton;
      _showBeamAddButton = showBeamAddButton;
      _showBeamRemoveButton = showBeamRemoveButton;
      _showSlurRemoveButton = showSlurRemoveButton;
      _showDecrescendoRemoveButton = showDecrescendoRemoveButton;
      _showCrescendoRemoveButton = showCrescendoRemoveButton;
      _showTieButton = showTieButton;
      _showTieRemoveState = showTieRemoveState;
      _showTempoEditButton = showTempoEditButton;
      _showFlipNoteButton = showFlipNoteButton;

      _showMuteRemoveButton = showMuteRemoveButton;
      _showPinchHarmonicRemoveButton = showPinchHarmonicRemoveButton;
      _showHarmonicRemoveButton = showHarmonicRemoveButton;
      _showVibratoRemoveButton = showVibratoRemoveButton;
      _showBendRemoveButton = showBendRemoveButton;
      _showPreBendRemoveButton = showPreBendRemoveButton;
      _showBendReleaseRemoveButton = showBendReleaseRemoveButton;
      _showPreBendReleaseRemoveButton = showPreBendReleaseRemoveButton;
    });
  }

  // Animation controller for smooth zoom transitions
  late AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;

  @override
  void initState() {
    super.initState();

    initialScale = widget.screenSize.width / widget.musicSheetWidth;

    _transformationController = TransformationController();

    final double scaleFactor =
        initialScale * 0.9; // Using 0.9 as the zoom factor

    final double translationX =
        (widget.screenSize.width - (widget.musicSheetWidth * scaleFactor)) / 2;

    final Matrix4 scaleMatrix = Matrix4.identity()..scale(scaleFactor);

    final Matrix4 translationMatrix = Matrix4.identity()
      ..setTranslationRaw(translationX, 50.0, 0);

    _transformationController.value = translationMatrix * scaleMatrix;

    _transformationController.addListener(_onZoomChanged);

    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _showCursor = !_showCursor; // Toggle cursor visibility
      });
    });

    if (widget.onClearHighlightingCallback != null) {
      widget.onClearHighlightingCallback!(clearHighlighting);
    }

    if (widget.onButtonStateCallbacks != null) {
      widget.onButtonStateCallbacks!(
          _updateTieButtonState, _updateFlipNoteButtonState);
    }

    if (widget.onZoomToNoteCallback != null) {
      widget.onZoomToNoteCallback!(_zoomToNote);
    }
  }

  void _zoomToNote(int rowIndex, int noteIndex) {
    final rowSpacingList =
        context.read<ListOfSpacingForEachRow>().rowSpacingList;
    final globalRowSpacingProvider = context.read<RowSpacingProvider>();

    if (rowIndex >= widget.sheetNoteRows.length || noteIndex < 0) return;

    final notes = widget.sheetNoteRows[rowIndex].chords;
    if (noteIndex >= notes.length) return;

    final currentRowSpacing = rowSpacingList[rowIndex];

    final noteX =
        calculateXPositionForIndex(noteIndex, notes, currentRowSpacing, false);

    double rowSpacing = globalRowSpacingProvider.rowSpacing;
    const double rowHeight = 40.0;
    const double verticalOffset = 150.0;
    final double noteY =
        verticalOffset + (rowIndex * (rowSpacing + rowHeight)) + 50;

    const double targetScale = 0.7;

    const double keyboardHeight = 357.0;
    final double appBarHeight = AppBar().preferredSize.height;
    final double visibleCanvasHeight = widget.screenSize.height -
        appBarHeight -
        keyboardHeight -
        widget.statusBarHeight;

    final double centerX = widget.screenSize.width / 2;
    final double centerY = visibleCanvasHeight / 2;

    double translationX = centerX - (noteX * targetScale);
    double translationY = centerY - (noteY * targetScale);

    final double canvasWidth = widget.musicSheetWidth;
    final double scaledCanvasWidth = canvasWidth * targetScale;
    final double scaledCanvasHeight = 5000 * targetScale;

    if (scaledCanvasWidth > widget.screenSize.width) {
      final double minTranslationX =
          widget.screenSize.width - scaledCanvasWidth;
      final double maxTranslationX = 0;
      translationX = translationX.clamp(minTranslationX, maxTranslationX);
    }

    if (scaledCanvasHeight > visibleCanvasHeight) {
      final double minTranslationY = visibleCanvasHeight - scaledCanvasHeight;
      final double maxTranslationY = 0;
      translationY = translationY.clamp(minTranslationY, maxTranslationY);
    }

    final Matrix4 targetMatrix = Matrix4.identity()
      ..translate(translationX, translationY)
      ..scale(targetScale);

    final Matrix4 currentMatrix = _transformationController.value;

    _zoomAnimation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _zoomAnimationController,
      curve: Curves.easeInOut,
    ));

    void animationListener() {
      _transformationController.value = _zoomAnimation!.value;
    }

    _zoomAnimationController.addListener(animationListener);

    _zoomAnimationController.forward(from: 0.0).then((_) {
      _zoomAnimationController.removeListener(animationListener);
      setState(() {
        isZoomed = true;
      });
    });
  }

  void _updateTieButtonState() {
    setState(() {
      _showTieButton = _shouldShowTieButton();
    });
  }

  void _updateFlipNoteButtonState() {
    setState(() {
      _showFlipNoteButton = _shouldShowFlipNote();
    });
  }

  void clearHighlighting() {
    setState(() {
      _dragStart = null;
      _dragEnd = null;
      _dragRow = null;
      _isDraggingLeftHandle = false;
      _isDraggingRightHandle = false;
      _fixedBoundary = null;
      _showHighlightButtons = false;
      _showTieButton = false;
      _showDynamicRemoveButton = false;
      _showBeamAddButton = false;
      _showBeamRemoveButton = false;
      _showSlurRemoveButton = false;
      _showDecrescendoRemoveButton = false;
      _showCrescendoRemoveButton = false;
      _showTieRemoveState = false;
      _showTempoEditButton = false;
      _showFlipNoteButton = false;
      _editingDynamicIndex = null;
      _editingDynamicRow = null;
      _isEditingDynamic = false;
      _isDragging = false;

      _showMuteRemoveButton = false;
      _showPinchHarmonicRemoveButton = false;
      _showHarmonicRemoveButton = false;
      _showVibratoRemoveButton = false;
      _showBendRemoveButton = false;
      _showPreBendRemoveButton = false;
      _showBendReleaseRemoveButton = false;
      _showPreBendReleaseRemoveButton = false;

      _showFlipNoteButton = _shouldShowFlipNote();
    });
  }

  void _onZoomChanged() {
    double currentScale = _transformationController.value.getMaxScaleOnAxis();
    bool newIsZoomed =
        (currentScale - initialScale).abs() > 0.01; // Avoid tiny differences

    if (newIsZoomed != isZoomed) {
      setState(() {
        isZoomed = newIsZoomed;
      });
    }
  }

  void _resetZoom() {
    final Matrix4 currentMatrix = _transformationController.value;
    final double targetScale = initialScale * 0.9;

    final double screenCenterX = widget.screenSize.width / 2;
    const double keyboardHeight = 357.0;
    final double appBarHeight = AppBar().preferredSize.height;
    final double visibleCanvasHeight = widget.screenSize.height -
        appBarHeight -
        keyboardHeight -
        widget.statusBarHeight;
    final double screenCenterY = visibleCanvasHeight / 2;

    final Matrix4 inverseMatrix = Matrix4.inverted(currentMatrix);
    final vector_math.Vector3 canvasCenterPoint = inverseMatrix
        .transform3(vector_math.Vector3(screenCenterX, screenCenterY, 0));

    final double canvasCenterX = widget.musicSheetWidth / 2;
    double translationX = screenCenterX - (canvasCenterX * targetScale);

    double translationY = screenCenterY - (canvasCenterPoint.y * targetScale);

    final double canvasWidth = widget.musicSheetWidth;
    final double scaledCanvasWidth = canvasWidth * targetScale;
    final double scaledCanvasHeight = 5000 * targetScale;

    if (scaledCanvasWidth > widget.screenSize.width) {
      final double minTranslationX =
          widget.screenSize.width - scaledCanvasWidth;
      final double maxTranslationX = 0;
      translationX = translationX.clamp(minTranslationX, maxTranslationX);
    }

    if (scaledCanvasHeight > visibleCanvasHeight) {
      final double minTranslationY = visibleCanvasHeight - scaledCanvasHeight;
      final double maxTranslationY = 0;
      translationY = translationY.clamp(minTranslationY, maxTranslationY);
    }

    final Matrix4 targetMatrix = Matrix4.identity()
      ..translate(translationX, translationY)
      ..scale(targetScale);

    _zoomAnimation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _zoomAnimationController,
      curve: Curves.easeInOut,
    ));

    void animationListener() {
      _transformationController.value = _zoomAnimation!.value;
    }

    _zoomAnimationController.addListener(animationListener);
    _zoomAnimationController.forward(from: 0.0).then((_) {
      _zoomAnimationController.removeListener(animationListener);
      setState(() {
        isZoomed = false;
      });
    });
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onZoomChanged);
    _transformationController.dispose();
    _zoomAnimationController.dispose();
    _cursorTimer.cancel();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) =>
      _gesture.handleDoubleTap(details);

  void _handleTap(TapDownDetails details) => _gesture.handleTap(details);

  void _handleLongPressStart(LongPressStartDetails details) =>
      _gesture.handleLongPressStart(details);

  void _handlePointerMove(PointerMoveEvent event) =>
      _gesture.handlePointerMove(event);

  void _handlePointerUp(PointerUpEvent event) =>
      _gesture.handlePointerUp(event);

  bool _shouldShowTieButton() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    final closestRowIndex = selectedNoteProvider.selectedRow;
    int closestNoteIndex = selectedNoteProvider.selectedIndex;
    final notes = widget.sheetNoteRows[closestRowIndex].chords;

    if (_dragStart == null && _dragEnd == null) {
      if (closestNoteIndex > 0 &&
          closestNoteIndex <=
              widget.sheetNoteRows[closestRowIndex].chords.length) {
        if (closestNoteIndex >= notes.length) {
          closestNoteIndex = notes.length - 1;
        }

        MusicalNote currentNote = notes[closestNoteIndex];
        if (closestNoteIndex < notes.length - 1) {
          MusicalNote nextNote = notes[closestNoteIndex + 1];

          if (currentNote.pitch == nextNote.pitch) {
            return true;
          }

          if (currentNote.type == NoteType.chord &&
              currentNote.childNotes != null &&
              currentNote.childNotes!.isNotEmpty) {
            if (nextNote.type == NoteType.chord &&
                nextNote.childNotes != null &&
                nextNote.childNotes!.isNotEmpty) {
              for (final child in currentNote.childNotes!) {
                if (nextNote.childNotes!.any((n) =>
                    n.pitch == child.pitch && n.octave == child.octave)) {
                  return true;
                }
              }
            } else {
              for (final child in currentNote.childNotes!) {
                if (child.pitch == nextNote.pitch &&
                    child.octave == nextNote.octave) {
                  return true;
                }
              }
            }
          }
        }
      }
    }
    return false;
  }

  bool _shouldShowTieRemove() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    if (_dragStart == null && _dragEnd == null) {
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0 && index < widget.sheetNoteRows[row].chords.length) {
        return widget.sheetNoteRows[row].chords[index].isTiedToNext;
      }
    }
    return false;
  }

  bool _shouldShowRangeRemove(ArticulationType type) {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    return shouldShowRangeMarkerRemove(
      type,
      sheetNoteRows: widget.sheetNoteRows,
      dragStart: _dragStart,
      dragEnd: _dragEnd,
      dragRow: _dragRow,
      selectedRow: selectedNoteProvider.selectedRow,
      selectedIndex: selectedNoteProvider.selectedIndex,
    );
  }

  void _removeRangeMarker(ArticulationType type) {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    context.read<SheetUndoManager>().saveState(widget.sheetNoteRows);
    removeRangeMarker(
      type,
      sheetNoteRows: widget.sheetNoteRows,
      dragStart: _dragStart,
      dragEnd: _dragEnd,
      dragRow: _dragRow,
      selectedRow: selectedNoteProvider.selectedRow,
      selectedIndex: selectedNoteProvider.selectedIndex,
    );
  }

  bool _shouldShowDecrescendoRemove() =>
      _shouldShowRangeRemove(ArticulationType.decrescendo);

  bool _shouldShowCrescendoRemove() =>
      _shouldShowRangeRemove(ArticulationType.crescendo);

  bool _shouldShowSlurRemove() => _shouldShowRangeRemove(ArticulationType.slur);

  bool _shouldShowBeamAdd() {
    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = start; i <= end; i++) {
        if (!widget.sheetNoteRows[_dragRow!].chords[i].isBeamed) {
          return true;
        }
      }
    }
    return false;
  }

  bool _shouldShowBeamRemove() {
    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = start; i <= end; i++) {
        if (widget.sheetNoteRows[_dragRow!].chords[i].isBeamed) {
          return true;
        }
      }
    } else {
      final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0 && index < widget.sheetNoteRows[row].chords.length) {
        return widget.sheetNoteRows[row].chords[index].isBeamed;
      }
    }
    return false;
  }

  bool _shouldShowTempoEdit() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    final row = selectedNoteProvider.selectedRow;
    final index = selectedNoteProvider.selectedIndex;

    if (index > 0 &&
        index < widget.sheetNoteRows[row].chords.length &&
        widget.sheetNoteRows[row].chords[index].type == NoteType.bar) {
      return true;
    }

    return false;
  }

  bool _shouldShowDynamicRemove() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    if (_dragStart == null && _dragEnd == null) {
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0 && index < widget.sheetNoteRows[row].chords.length) {
        final dynamicChar =
            widget.sheetNoteRows[row].chords[index].dynamicCharacter;
        return dynamicChar.isNotEmpty;
      }
    }
    return false;
  }

  bool _shouldShowFlipNote() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    if (_dragStart == null && _dragEnd == null) {
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (row >= 0 &&
          row < widget.sheetNoteRows.length &&
          index >= 0 &&
          index < widget.sheetNoteRows[row].chords.length) {
        final selectedNote = widget.sheetNoteRows[row].chords[index];
        return selectedNote.type != NoteType.accidental &&
            selectedNote.type != NoteType.bar &&
            selectedNote.type != NoteType.clef &&
            selectedNote.type != NoteType.keySignature &&
            selectedNote.type != NoteType.rest &&
            selectedNote.type != NoteType.space &&
            selectedNote.type != NoteType.timeSignature &&
            selectedNote.type != NoteType.whole;
      }
    }
    return false;
  }

  //Guitar tab
  bool _shouldShowMuteRemove() => _shouldShowRangeRemove(ArticulationType.mute);

  bool _shouldShowPinchHarmonicRemove() =>
      _shouldShowRangeRemove(ArticulationType.pinchHarmonic);

  bool _shouldShowHarmonicRemove() =>
      _shouldShowRangeRemove(ArticulationType.harmonic);

  bool _shouldShowVibratoRemove() =>
      _shouldShowRangeRemove(ArticulationType.vibrato);

  bool _shouldShowBendRemove() => _shouldShowRangeRemove(ArticulationType.bend);

  bool _shouldShowPreBendRemove() =>
      _shouldShowRangeRemove(ArticulationType.preBend);

  bool _shouldShowBendReleaseRemove() =>
      _shouldShowRangeRemove(ArticulationType.bendRelease);

  bool _shouldShowPreBendReleaseRemove() =>
      _shouldShowRangeRemove(ArticulationType.preBendRelease);

  String _getDynamicCharacter() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    final row = selectedNoteProvider.selectedRow;
    final index = selectedNoteProvider.selectedIndex;

    if (index >= 0 && index < widget.sheetNoteRows[row].chords.length) {
      return widget.sheetNoteRows[row].chords[index].dynamicCharacter;
    }
    return "";
  }

  bool _selectedRowsHaveCurlyBraces(List<int> selectedRows) {
    return widget.sheetProperties.curlyBraceGroups.any((group) {
      return selectedRows
          .any((row) => row >= group.startRow && row <= group.endRow);
    });
  }

  int _getRowGroupIndex(int rowIndex) {
    final rowsPerGroup = widget.sheetFormat.rowsPerGroup;
    return rowIndex ~/ rowsPerGroup;
  }

  List<List<int>> _getValidBraceGroups(
      SelectRowsModeProvider selectRowsModeProvider) {
    final selectedRows = selectRowsModeProvider.selectedRows.toList();
    final validGroups = <List<int>>[];

    final rowsByGroup = <int, List<int>>{};
    for (final row in selectedRows) {
      final groupIndex = _getRowGroupIndex(row);
      rowsByGroup.putIfAbsent(groupIndex, () => []).add(row);
    }

    for (final groupRows in rowsByGroup.values) {
      groupRows.sort(); // Ensure sorted
      final contiguousGroups = <List<int>>[];
      int start = groupRows[0];
      int end = groupRows[0];

      for (int i = 1; i < groupRows.length; i++) {
        if (groupRows[i] == end + 1) {
          end = groupRows[i];
        } else {
          contiguousGroups.add([start, end]);
          start = groupRows[i];
          end = groupRows[i];
        }
      }
      contiguousGroups.add([start, end]);

      for (final group in contiguousGroups) {
        if (group[1] - group[0] + 1 >= 2) {
          validGroups.add(group);
        }
      }
    }

    return validGroups;
  }

  void _removeTie() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    context.read<SheetUndoManager>().saveState(widget.sheetNoteRows);

    final row = selectedNoteProvider.selectedRow;
    final index = selectedNoteProvider.selectedIndex;

    if (index >= 0 && index < widget.sheetNoteRows[row].chords.length) {
      setState(() {
        widget.sheetNoteRows[row].chords[index].isTiedToNext = false;
      });
      _showTieRemoveState = false;
    }
  }

  void _removeDecrescendo() {
    _removeRangeMarker(ArticulationType.decrescendo);
    _showDecrescendoRemoveButton = false;
  }

  void _removeCrescendo() {
    _removeRangeMarker(ArticulationType.crescendo);
    _showCrescendoRemoveButton = false;
  }

  void _removeSlur() {
    _removeRangeMarker(ArticulationType.slur);
    _showSlurRemoveButton = false;
  }

  void _removeBeam() {
    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = start; i <= end; i++) {
        widget.sheetNoteRows[_dragRow!].chords[i].isBeamed = false;
      }
    } else {
      final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0 && index < widget.sheetNoteRows[row].chords.length) {
        widget.sheetNoteRows[row].chords[index].isBeamed = false;
      }
    }

    _showBeamRemoveButton = false;
    _showBeamAddButton = true;
  }

  void _removeDynamicCharacter() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    context.read<SheetUndoManager>().saveState(widget.sheetNoteRows);

    final row = selectedNoteProvider.selectedRow;
    final index = selectedNoteProvider.selectedIndex;

    if (index >= 0 && index < widget.sheetNoteRows[row].chords.length) {
      setState(() {
        widget.sheetNoteRows[row].chords[index].dynamicCharacter = "";
      });
    }

    _showDynamicRemoveButton = false;
  }

  void _showTempoPopup() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    final row = selectedNoteProvider.selectedRow;
    final index = selectedNoteProvider.selectedIndex;

    if (index >= 0 && index < widget.sheetNoteRows[row].chords.length) {
      final barNote = widget.sheetNoteRows[row].chords[index];

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return TempoPopup(
            initialTempo: barNote.tempoNumber,
            initialSwing: barNote.swing,
            initialSwingText: barNote.swingText,
            onSave: (double tempo, bool swing, String swingText) {
              setState(() {
                barNote.tempoNumber = tempo;
                barNote.swing = swing;
                barNote.swingText = swingText;
              });
            },
          );
        },
      );
    }
  }

  //Guitar tab
  void _removeMute() {
    _removeRangeMarker(ArticulationType.mute);
    _showMuteRemoveButton = false;
  }

  void _removePinchHarmonic() {
    _removeRangeMarker(ArticulationType.pinchHarmonic);
    _showPinchHarmonicRemoveButton = false;
  }

  void _removeHarmonic() {
    _removeRangeMarker(ArticulationType.harmonic);
    _showHarmonicRemoveButton = false;
  }

  void _removeVibrato() {
    _removeRangeMarker(ArticulationType.vibrato);
    _showVibratoRemoveButton = false;
  }

  void _removeBend() {
    _removeRangeMarker(ArticulationType.bend);
    _showBendRemoveButton = false;
  }

  void _removePreBend() {
    _removeRangeMarker(ArticulationType.preBend);
    _showPreBendRemoveButton = false;
  }

  void _removeBendRelease() {
    _removeRangeMarker(ArticulationType.bendRelease);
    _showBendReleaseRemoveButton = false;
  }

  void _removePreBendRelease() {
    _removeRangeMarker(ArticulationType.preBendRelease);
    _showPreBendReleaseRemoveButton = false;
  }

  @override
  Widget build(BuildContext context) {
    final selectedNoteProvider =
        Provider.of<CurrentSelectedNoteProvider>(context);
    final rowSpacingProvider = Provider.of<ListOfSpacingForEachRow>(context);
    final globalRowSpacingProvider = Provider.of<RowSpacingProvider>(context);
    final selectRowsModeProvider = Provider.of<SelectRowsModeProvider>(context);

    var keyboardHeight = widget.isReadOnly ? 0 : 357;
    var canvasHeight = widget.screenSize.height -
        AppBar().preferredSize.height -
        keyboardHeight -
        widget.statusBarHeight;

    return Column(
      children: [
        Stack(children: [
          GestureDetector(
              onTapDown: _handleTap,
              onDoubleTapDown: _handleDoubleTap,
              onLongPressStart: _handleLongPressStart,
              child: Listener(
                onPointerMove: _handlePointerMove,
                onPointerUp: _handlePointerUp,
                child: Container(
                  width: widget.screenSize.width,
                  height: canvasHeight,
                  color: const Color.fromARGB(255, 199, 199, 199),
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    panEnabled: !_isDragging && !_isEditingDynamic,
                    scaleEnabled: !_isDragging && !_isEditingDynamic,
                    minScale: initialScale *
                        0.4, // Allows zooming out further if needed
                    maxScale: 3.0, // Allow zooming in up to 3x
                    boundaryMargin:
                        const EdgeInsets.fromLTRB(200, 200, 200, 9999),
                    constrained: false,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Builder(
                        builder: (context) {
                          const double sheetHeight = 40.0;
                          double rowSpacing =
                              globalRowSpacingProvider.rowSpacing;
                          double rowTotalHeight = rowSpacing + sheetHeight;

                          final int startRow = widget.renderStartRow ?? 0;
                          final int endRow = widget.renderEndRow ??
                              (widget.sheetNoteRows.length - 1);
                          final int renderedRowCount = (endRow - startRow + 1)
                              .clamp(1, widget.sheetNoteRows.length);

                          // Adjust vertical offset for partial rendering
                          // For PDF export, we need to ensure the screenshot area includes the title/composer
                          // Increased padding to prevent cutoff at the top
                          final double adjustedVerticalOffset =
                              (widget.renderStartRow != null &&
                                      widget.renderEndRow != null &&
                                      widget.showTitleAndComposer)
                                  ? 250.0
                                  : 150.0;

                          final double a4ProportionalHeight =
                              widget.sheetFormat.config.a4ProportionalHeight;

                          const double pageHeaderMargin = 50.0;
                          const double pageFooterMargin = 50.0;

                          final pageBreaks = PdfExporter.calculatePageBreaks(
                              widget.sheetNoteRows,
                              globalRowSpacingProvider.rowSpacing,
                              widget.sheetFormat);
                          double totalMarginsHeight = 0.0;

                          for (int i = 0; i < pageBreaks.length; i++) {
                            totalMarginsHeight +=
                                pageFooterMargin; // Each page has footer margin
                            if (i > 0) {
                              totalMarginsHeight +=
                                  pageHeaderMargin; // Non-first pages have header margin
                            }
                          }

                          const double rowVerticalBuffer = 120.0;
                          double additionalBufferHeight = 0.0;

                          if (widget.renderStartRow != null &&
                              widget.renderEndRow != null) {
                            additionalBufferHeight = rowVerticalBuffer * 2;
                          }

                          final double contentHeight = adjustedVerticalOffset +
                              (rowTotalHeight * renderedRowCount) +
                              additionalBufferHeight;

                          final double totalHeight =
                              math.max(contentHeight, a4ProportionalHeight);

                          return SizedBox(
                            width: widget.musicSheetWidth,
                            height: totalHeight,
                            child: Stack(children: [
                              Positioned.fill(
                                child: Screenshot(
                                  controller: widget.screenshotController,
                                  child: CustomPaint(
                                    painter: MusicSheetPainter(
                                      title: widget.sheetProperties.title,
                                      composer: widget.sheetProperties.composer,
                                      sheetNoteRows: widget.sheetNoteRows,
                                      sheetFormat: widget.sheetFormat,
                                      keyboardType: widget.keyboardType,
                                      selectedRow: -1,
                                      selectedIndex: -1,
                                      showCursor: false,
                                      rowSpacingList:
                                          rowSpacingProvider.rowSpacingList,
                                      rowSpacing:
                                          globalRowSpacingProvider.rowSpacing,
                                      editingDynamicIndex: _editingDynamicIndex,
                                      editingDynamicRow: _editingDynamicRow,
                                      renderStartRow: widget.renderStartRow,
                                      renderEndRow: widget.renderEndRow,
                                      showTitleAndComposer:
                                          widget.showTitleAndComposer,
                                      selectedRowsForCurlyBrace:
                                          selectRowsModeProvider
                                                  .isSelectRowsMode
                                              ? selectRowsModeProvider
                                                  .selectedRows
                                              : null,
                                      curlyBraceGroups: widget
                                          .sheetProperties.curlyBraceGroups,
                                      isReadOnly: widget.isReadOnly,
                                    ),
                                    size: Size(widget.musicSheetWidth,
                                        totalHeight), // Dynamic height
                                  ),
                                ),
                              ),
                              CustomPaint(
                                painter: MusicSheetPainter(
                                  title: widget.sheetProperties.title,
                                  composer: widget.sheetProperties.composer,
                                  sheetNoteRows: widget.sheetNoteRows,
                                  sheetFormat: widget.sheetFormat,
                                  keyboardType: widget.keyboardType,
                                  selectedRow: selectedNoteProvider.selectedRow,
                                  selectedIndex:
                                      selectedNoteProvider.selectedIndex,
                                  showCursor: _showCursor &&
                                      !selectRowsModeProvider.isSelectRowsMode,
                                  rowSpacingList:
                                      rowSpacingProvider.rowSpacingList,
                                  rowSpacing:
                                      globalRowSpacingProvider.rowSpacing,
                                  selectionStart: _dragStart,
                                  selectionEnd: _dragEnd,
                                  selectionRow: _dragRow,
                                  editingDynamicIndex: _editingDynamicIndex,
                                  editingDynamicRow: _editingDynamicRow,
                                  selectedRowsForCurlyBrace:
                                      selectRowsModeProvider.isSelectRowsMode
                                          ? selectRowsModeProvider.selectedRows
                                          : null,
                                  curlyBraceGroups:
                                      widget.sheetProperties.curlyBraceGroups,
                                  isReadOnly: widget.isReadOnly,
                                ),
                                size: Size(widget.musicSheetWidth, totalHeight),
                              )
                            ]),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              )),

          //Undo
          if (!selectRowsModeProvider.isSelectRowsMode && !widget.isReadOnly)
            Positioned(
                top: 55,
                right: 5,
                child: Material(
                  color: Colors.transparent,
                  elevation: 5,
                  shadowColor: Colors.black.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Consumer<SheetUndoManager>(
                    builder: (context, undoManager, child) => RawMaterialButton(
                      onPressed: undoManager.canUndo
                          ? () {
                              final previousState = undoManager.undo();
                              if (previousState != null) {
                                final selectedNoteProvider =
                                    context.read<CurrentSelectedNoteProvider>();
                                final currentRow =
                                    selectedNoteProvider.selectedRow;
                                final currentIndex =
                                    selectedNoteProvider.selectedIndex;

                                widget.sheetNoteRows.clear();
                                widget.sheetNoteRows.addAll(previousState);

                                int newRow = currentRow;
                                int newIndex = currentIndex;

                                if (newRow >= widget.sheetNoteRows.length) {
                                  newRow = widget.sheetNoteRows.length - 1;
                                  newIndex = widget
                                          .sheetNoteRows[newRow].chords.isEmpty
                                      ? 0
                                      : widget.sheetNoteRows[newRow].chords
                                              .length -
                                          1;
                                } else {
                                  if (newIndex >=
                                      widget.sheetNoteRows[newRow].chords
                                          .length) {
                                    newIndex = widget.sheetNoteRows[newRow]
                                            .chords.isEmpty
                                        ? 0
                                        : widget.sheetNoteRows[newRow].chords
                                                .length -
                                            1;
                                  }
                                }

                                selectedNoteProvider
                                    .updateSelectedIndexAndInsertionPoint(
                                        newRow, newIndex);

                                clearHighlighting();

                                setState(() {});
                              }
                            }
                          : null,
                      fillColor: Colors.white,
                      constraints:
                          const BoxConstraints.tightFor(width: 35, height: 35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                        side: const BorderSide(color: Colors.black, width: 1),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      child: const Icon(
                        Icons.undo,
                        color: Colors.black,
                        size: 24,
                      ),
                    ),
                  ),
                )),

          // Floating Reset Zoom Button
          if (isZoomed)
            Positioned(
                top: widget.isReadOnly ? 10 : 100,
                right: 5,
                child: Material(
                  color: Colors.transparent,
                  elevation: 5,
                  shadowColor: Colors.black.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: RawMaterialButton(
                    onPressed: _resetZoom,
                    fillColor: Colors.white,
                    constraints:
                        const BoxConstraints.tightFor(width: 35, height: 35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                      side: const BorderSide(color: Colors.black, width: 1),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    child: const Icon(
                      Icons.zoom_out_map,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                )),
          Positioned(
              top: 10,
              left: 0,
              right: 0,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (_showFlipNoteButton &&
                    selectedNoteProvider.selectedRow >= 0 &&
                    selectedNoteProvider.selectedRow <
                        widget.sheetNoteRows.length &&
                    selectedNoteProvider.selectedIndex >= 0 &&
                    selectedNoteProvider.selectedIndex <
                        widget.sheetNoteRows[selectedNoteProvider.selectedRow]
                            .chords.length &&
                    widget.keyboardType != KeyboardType.guitarTab) ...[
                  buildNoteFlipButton('Flip Note', () {
                    setState(() {
                      if (_dragStart != null &&
                          _dragEnd != null &&
                          _dragRow != null) {
                        return;
                      } else {
                        if (selectedNoteProvider
                            .getBeamedGroupIndices(
                                selectedNoteProvider.selectedIndex,
                                widget
                                    .sheetNoteRows[
                                        selectedNoteProvider.selectedRow]
                                    .chords)
                            .isNotEmpty) {
                          context
                              .read<CurrentSelectedNoteProvider>()
                              .switchBeamRotation(
                                  widget.sheetNoteRows, context);
                        } else {
                          var note = widget
                              .sheetNoteRows[selectedNoteProvider.selectedRow]
                              .chords[selectedNoteProvider.selectedIndex];

                          if (note.type == NoteType.chord &&
                              note.childNotes != null &&
                              note.childNotes!.isNotEmpty) {
                            final bool currentState =
                                note.childNotes!.first.isUpsideDown ?? false;
                            final bool newState = !currentState;
                            for (var childNote in note.childNotes!) {
                              childNote.isUpsideDown = newState;
                            }
                            note.isUpsideDown = newState;
                          } else {
                            note.isUpsideDown = note.isUpsideDown == false;
                          }
                        }
                      }
                    });
                  }, () {
                    final beamedIndices =
                        selectedNoteProvider.getBeamedGroupIndices(
                            selectedNoteProvider.selectedIndex,
                            widget
                                .sheetNoteRows[selectedNoteProvider.selectedRow]
                                .chords);
                    final chord = widget
                        .sheetNoteRows[selectedNoteProvider.selectedRow]
                        .chords[selectedNoteProvider.selectedIndex];
                    if (chord.isBeamed && beamedIndices.isNotEmpty) {
                      return widget
                          .sheetNoteRows[selectedNoteProvider.selectedRow]
                          .chords[beamedIndices.first]
                          .isUpsideDown;
                    }
                    return chord.isUpsideDown;
                  }()),
                ],
              ])),
          // Select Rows Mode UI - Exit Button
          if (selectRowsModeProvider.isSelectRowsMode)
            Positioned(
              top: 10,
              right: 5,
              child: Material(
                color: Colors.transparent,
                elevation: 5,
                shadowColor: Colors.black.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                child: RawMaterialButton(
                  onPressed: () {
                    selectRowsModeProvider.exitSelectRowsMode();
                  },
                  fillColor: Colors.red,
                  constraints:
                      const BoxConstraints.tightFor(width: 50, height: 35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                    side: const BorderSide(color: Colors.white, width: 2),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  child: const Text(
                    'Exit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // Select Rows Mode UI - Remove Curly Braces Button
          if (selectRowsModeProvider.isSelectRowsMode &&
              _selectedRowsHaveCurlyBraces(
                  selectRowsModeProvider.selectedRows.toList()))
            Positioned(
              bottom: 52,
              left: 0,
              right: 120,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'x',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 21,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Material(
                      color: Colors.transparent,
                      elevation: 5,
                      shadowColor: Colors.black.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: RawMaterialButton(
                        onPressed: () {
                          setState(() {
                            context
                                .read<SheetUndoManager>()
                                .saveState(widget.sheetNoteRows);

                            // Remove curly braces from all selected rows
                            final selectedRows =
                                selectRowsModeProvider.selectedRows.toList();
                            widget.sheetProperties.curlyBraceGroups
                                .removeWhere((group) {
                              return selectedRows.any((row) =>
                                  row >= group.startRow && row <= group.endRow);
                            });
                          });
                        },
                        fillColor: Colors.white,
                        constraints: const BoxConstraints.tightFor(
                            width: 100, height: 35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                          side: const BorderSide(color: Colors.red, width: 1),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        child: const Text(
                          'Curly Braces',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Select Rows Mode UI - Copy Button
          if (selectRowsModeProvider.isSelectRowsMode &&
              selectRowsModeProvider.selectedRowCount >= 1)
            Positioned(
              bottom: 10,
              left: 120,
              right: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  elevation: 5,
                  shadowColor: Colors.black.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: RawMaterialButton(
                    onPressed: widget.onCopyRowsCallback,
                    fillColor: Colors.white,
                    constraints:
                        const BoxConstraints.tightFor(width: 80, height: 35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                      side: const BorderSide(color: Colors.black, width: 1),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.copy, size: 16, color: Colors.black),
                        SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Select Rows Mode UI - Add Curly Braces Button
          if (selectRowsModeProvider.isSelectRowsMode &&
              _getValidBraceGroups(selectRowsModeProvider).isNotEmpty)
            Positioned(
              bottom: 10,
              left: 0,
              right: 120,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+',
                      style: TextStyle(
                        color: Color.fromARGB(255, 63, 63, 63),
                        fontSize: 21,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Material(
                      color: Colors.transparent,
                      elevation: 5,
                      shadowColor: Colors.black.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: RawMaterialButton(
                        onPressed: () {
                          setState(() {
                            context
                                .read<SheetUndoManager>()
                                .saveState(widget.sheetNoteRows);

                            // Add curly brace groups for each valid contiguous group within the same row group with 2+ rows
                            final validGroups =
                                _getValidBraceGroups(selectRowsModeProvider);
                            for (final group in validGroups) {
                              final newGroup = CurlyBraceGroup(
                                startRow: group[0],
                                endRow: group[1],
                              );
                              widget.sheetProperties.curlyBraceGroups
                                  .add(newGroup);
                            }
                          });
                        },
                        fillColor: Colors.white,
                        constraints: const BoxConstraints.tightFor(
                            width: 100, height: 35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                          side: const BorderSide(color: Colors.black, width: 1),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        child: const Text(
                          'Curly Braces',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (!selectRowsModeProvider.isSelectRowsMode)
            Positioned(
              bottom: 5,
              right: 5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_showDynamicRemoveButton &&
                      widget.keyboardType != KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    buildStyledButton(_getDynamicCharacter(), () {
                      _removeDynamicCharacter();
                    }, true, false),
                  ],
                  if ((_showHighlightButtons || _showDecrescendoRemoveButton) &&
                      widget.keyboardType != KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    buildStyledButton('\uE53F', () {
                      if (_showDecrescendoRemoveButton) {
                        _removeDecrescendo();
                      } else {
                        if (_dragRow != null &&
                            _dragStart != null &&
                            _dragEnd != null) {
                          context
                              .read<CurrentSelectedNoteProvider>()
                              .decrescendoNotes(_dragRow!, _dragStart!,
                                  _dragEnd!, widget.sheetNoteRows, context);

                          _showDecrescendoRemoveButton = true;
                          _showCrescendoRemoveButton = false;
                        }
                      }
                    }, true, !_showDecrescendoRemoveButton)
                  ],
                  if ((_showHighlightButtons || _showCrescendoRemoveButton) &&
                      widget.keyboardType != KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    buildStyledButton('\uE53E', () {
                      if (_showCrescendoRemoveButton) {
                        _removeCrescendo();
                      } else {
                        if (_dragRow != null &&
                            _dragStart != null &&
                            _dragEnd != null) {
                          context
                              .read<CurrentSelectedNoteProvider>()
                              .crescendoNotes(_dragRow!, _dragStart!, _dragEnd!,
                                  widget.sheetNoteRows, context);

                          _showCrescendoRemoveButton = true;
                          _showDecrescendoRemoveButton = false;
                        }
                      }
                    }, true, !_showCrescendoRemoveButton)
                  ],
                  if ((_showHighlightButtons || _showSlurRemoveButton) &&
                      widget.keyboardType != KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    buildStyledButton('SLUR', () {
                      if (_showSlurRemoveButton) {
                        _removeSlur();
                      } else {
                        if (_dragRow != null &&
                            _dragStart != null &&
                            _dragEnd != null) {
                          context.read<CurrentSelectedNoteProvider>().slurNotes(
                              _dragRow!,
                              _dragStart!,
                              _dragEnd!,
                              widget.sheetNoteRows,
                              context);
                          _showSlurRemoveButton = true;
                        }
                      }
                    }, false, !_showSlurRemoveButton)
                  ],
                  if ((_showHighlightButtons && _showBeamAddButton) &&
                      widget.keyboardType != KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    buildStyledButton('BEAM', () {
                      if (_dragRow != null &&
                          _dragStart != null &&
                          _dragEnd != null) {
                        context.read<CurrentSelectedNoteProvider>().beamNotes(
                            _dragRow!,
                            _dragStart!,
                            _dragEnd!,
                            widget.sheetNoteRows,
                            context);

                        _showBeamRemoveButton = true;
                        _showBeamAddButton = false;
                      }
                    }, false, true)
                  ],
                  if (_showBeamRemoveButton &&
                      widget.keyboardType != KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    buildStyledButton('BEAM', () {
                      _removeBeam();
                    }, false, false),
                  ],
                  if (_showTieButton &&
                      widget.keyboardType != KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    buildStyledButton('TIE', () {
                      if (_showTieRemoveState) {
                        _removeTie();
                      } else {
                        final selectedNoteProvider =
                            context.read<CurrentSelectedNoteProvider>();
                        final row = selectedNoteProvider.selectedRow;
                        final index = selectedNoteProvider.selectedIndex;

                        if (index >= 0 &&
                            index + 1 <
                                widget.sheetNoteRows[row].chords.length) {
                          MusicalNote currentNote =
                              widget.sheetNoteRows[row].chords[index];
                          MusicalNote nextNote =
                              widget.sheetNoteRows[row].chords[index + 1];

                          bool canTie = currentNote.pitch == nextNote.pitch;

                          if (!canTie &&
                              currentNote.type == NoteType.chord &&
                              currentNote.childNotes != null &&
                              currentNote.childNotes!.isNotEmpty) {
                            if (nextNote.type == NoteType.chord &&
                                nextNote.childNotes != null &&
                                nextNote.childNotes!.isNotEmpty) {
                              canTie = currentNote.childNotes!.any((child) =>
                                  nextNote.childNotes!.any((n) =>
                                      n.pitch == child.pitch &&
                                      n.octave == child.octave));
                            } else {
                              canTie = currentNote.childNotes!.any((child) =>
                                  child.pitch == nextNote.pitch &&
                                  child.octave == nextNote.octave);
                            }
                          }

                          if (canTie) {
                            setState(() {
                              currentNote.isTiedToNext =
                                  !currentNote.isTiedToNext;
                            });
                            _showTieRemoveState = true;
                          }
                        }
                      }
                    }, false, !_showTieRemoveState),
                  ],
                  if (_showTempoEditButton) ...[
                    const SizedBox(height: 5),
                    buildStyledButton('TEMPO', () {
                      _showTempoPopup();
                    }, false, true),
                  ],
                  //Guitar tab buttons
                  //P.M
                  if ((_showHighlightButtons || _showMuteRemoveButton) &&
                      widget.keyboardType == KeyboardType.guitarTab &&
                      !_showBendsPanel) ...[
                    const SizedBox(height: 5),
                    buildStyledButton('P.M.', () {
                      if (_showMuteRemoveButton) {
                        _removeMute();
                      } else {
                        if (_dragRow != null &&
                            _dragStart != null &&
                            _dragEnd != null) {
                          context.read<CurrentSelectedNoteProvider>().muteNotes(
                              _dragRow!,
                              _dragStart!,
                              _dragEnd!,
                              widget.sheetNoteRows,
                              context);

                          _showMuteRemoveButton = true;
                          _showPinchHarmonicRemoveButton = false;
                          _showHarmonicRemoveButton = false;
                        }
                      }
                    }, false, !_showMuteRemoveButton)
                  ],
                  //P.H
                  if ((_showHighlightButtons ||
                          _showPinchHarmonicRemoveButton) &&
                      widget.keyboardType == KeyboardType.guitarTab &&
                      !_showBendsPanel) ...[
                    const SizedBox(height: 5),
                    buildStyledButton('P.H.', () {
                      if (_showPinchHarmonicRemoveButton) {
                        _removePinchHarmonic();
                      } else {
                        if (_dragRow != null &&
                            _dragStart != null &&
                            _dragEnd != null) {
                          context
                              .read<CurrentSelectedNoteProvider>()
                              .pinchHarmonicNotes(_dragRow!, _dragStart!,
                                  _dragEnd!, widget.sheetNoteRows, context);

                          _showPinchHarmonicRemoveButton = true;
                          _showMuteRemoveButton = false;
                          _showHarmonicRemoveButton = false;
                        }
                      }
                    }, false, !_showPinchHarmonicRemoveButton)
                  ],
                  //Ham.
                  if ((_showHighlightButtons || _showHarmonicRemoveButton) &&
                      widget.keyboardType == KeyboardType.guitarTab &&
                      !_showBendsPanel) ...[
                    const SizedBox(height: 5),
                    buildStyledButton('Ham.', () {
                      if (_showHarmonicRemoveButton) {
                        _removeHarmonic();
                      } else {
                        if (_dragRow != null &&
                            _dragStart != null &&
                            _dragEnd != null) {
                          context
                              .read<CurrentSelectedNoteProvider>()
                              .harmonicNotes(_dragRow!, _dragStart!, _dragEnd!,
                                  widget.sheetNoteRows, context);

                          _showHarmonicRemoveButton = true;
                          _showMuteRemoveButton = false;
                          _showPinchHarmonicRemoveButton = false;
                        }
                      }
                    }, false, !_showHarmonicRemoveButton)
                  ],
                  //Vibrato
                  if ((_showHighlightButtons || _showVibratoRemoveButton) &&
                      widget.keyboardType == KeyboardType.guitarTab &&
                      !_showBendsPanel) ...[
                    const SizedBox(height: 5),
                    buildStyledButton('\uE56E', () {
                      if (_showVibratoRemoveButton) {
                        _removeVibrato();
                      } else {
                        if (_dragRow != null &&
                            _dragStart != null &&
                            _dragEnd != null) {
                          context
                              .read<CurrentSelectedNoteProvider>()
                              .vibratoNotes(_dragRow!, _dragStart!, _dragEnd!,
                                  widget.sheetNoteRows, context);

                          _showVibratoRemoveButton = true;
                        }
                      }
                    }, true, !_showVibratoRemoveButton)
                  ],
                  //Bend
                  if (((_showHighlightButtons && _showBendsPanel) ||
                          _showBendRemoveButton) &&
                      widget.keyboardType == KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    buildStyledButton('', () {
                      if (_showBendRemoveButton) {
                        _removeBend();
                      } else {
                        if (_dragRow != null &&
                            _dragStart != null &&
                            _dragEnd != null) {
                          context.read<CurrentSelectedNoteProvider>().bendNotes(
                              _dragRow!,
                              _dragStart!,
                              _dragEnd!,
                              widget.sheetNoteRows,
                              context);

                          _showBendRemoveButton = true;
                          _showPreBendRemoveButton = false;
                          _showBendReleaseRemoveButton = false;
                          _showPreBendReleaseRemoveButton = false;
                        }
                      }
                    }, false, !_showBendRemoveButton,
                        svgAssetPath: 'assets/svgs/bend.svg')
                  ],
                  //pre-bend
                  if (((_showHighlightButtons && _showBendsPanel) ||
                          _showPreBendRemoveButton) &&
                      widget.keyboardType == KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    buildStyledButton('', () {
                      if (_showPreBendRemoveButton) {
                        _removePreBend();
                      } else {
                        if (_dragRow != null &&
                            _dragStart != null &&
                            _dragEnd != null) {
                          context
                              .read<CurrentSelectedNoteProvider>()
                              .preBendNotes(_dragRow!, _dragStart!, _dragEnd!,
                                  widget.sheetNoteRows, context);

                          _showPreBendRemoveButton = true;
                          _showBendRemoveButton = false;
                          _showBendReleaseRemoveButton = false;
                          _showPreBendReleaseRemoveButton = false;
                        }
                      }
                    }, false, !_showPreBendRemoveButton,
                        svgAssetPath: 'assets/svgs/pre-bend.svg')
                  ],
                  //bend-release
                  if (((_showHighlightButtons && _showBendsPanel) ||
                          _showBendReleaseRemoveButton) &&
                      widget.keyboardType == KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    buildStyledButton('', () {
                      if (_showBendReleaseRemoveButton) {
                        _removeBendRelease();
                      } else {
                        if (_dragRow != null &&
                            _dragStart != null &&
                            _dragEnd != null) {
                          context
                              .read<CurrentSelectedNoteProvider>()
                              .bendReleaseNotes(_dragRow!, _dragStart!,
                                  _dragEnd!, widget.sheetNoteRows, context);

                          _showBendReleaseRemoveButton = true;
                          _showPreBendRemoveButton = false;
                          _showBendRemoveButton = false;
                          _showPreBendReleaseRemoveButton = false;
                        }
                      }
                    }, false, !_showBendReleaseRemoveButton,
                        svgAssetPath: 'assets/svgs/bend-release.svg')
                  ],
                  //pre-bend-release
                  if (((_showHighlightButtons && _showBendsPanel) ||
                          _showPreBendReleaseRemoveButton) &&
                      widget.keyboardType == KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    buildStyledButton('', () {
                      if (_showPreBendReleaseRemoveButton) {
                        _removePreBendRelease();
                      } else {
                        if (_dragRow != null &&
                            _dragStart != null &&
                            _dragEnd != null) {
                          context
                              .read<CurrentSelectedNoteProvider>()
                              .preBendReleaseNotes(_dragRow!, _dragStart!,
                                  _dragEnd!, widget.sheetNoteRows, context);

                          _showPreBendReleaseRemoveButton = true;
                          _showPreBendRemoveButton = false;
                          _showBendReleaseRemoveButton = false;
                          _showBendRemoveButton = false;
                        }
                      }
                    }, false, !_showPreBendReleaseRemoveButton,
                        svgAssetPath: 'assets/svgs/pre-bend-release.svg')
                  ],
                  //BENDS toggle button
                  if (_showHighlightButtons &&
                      widget.keyboardType == KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    buildBendsToggleButton(_showBendsPanel, () {
                      setState(() {
                        _showBendsPanel = !_showBendsPanel;
                      });
                    }),
                  ],
                ],
              ),
            ),
        ]),
        PreferredSize(
          preferredSize: const Size.fromHeight(2.0),
          child: Container(
            color: Colors.black,
            height: 2.0,
          ),
        ),
      ],
    );
  }
}
