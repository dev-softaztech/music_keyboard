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
import 'package:music_keyboard/src/utils/music_sheet_utils/drawing_helpers.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_width_calculator.dart';
import 'package:music_keyboard/src/utils/pdf_exporter.dart';
import 'package:music_keyboard/src/widgets/main_sheet/music_sheet_painter.dart';
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
    with SingleTickerProviderStateMixin {
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
  int? _dragStart;
  int? _dragEnd;
  int? _dragRow;
  bool _isDragging = false;
  bool _isDraggingLeftHandle = false;
  bool _isDraggingRightHandle = false;
  // ignore: unused_field
  int? _fixedBoundary;
  int? _editingDynamicIndex;
  int? _editingDynamicRow;
  bool _isEditingDynamic = false;
  Offset _totalDragDelta = Offset.zero;
  double lineSpacing = 10;

  // Animation controller for smooth zoom transitions
  late AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;

  @override
  void initState() {
    super.initState();

    // Ensure entire music sheet width is visible on load
    initialScale = widget.screenSize.width / widget.musicSheetWidth;

    _transformationController = TransformationController();

    // Apply the initial scale and center horizontally
    final double scaleFactor =
        initialScale * 0.9; // Using 0.9 as the zoom factor

    // Calculate the translation needed to center the content
    final double translationX =
        (widget.screenSize.width - (widget.musicSheetWidth * scaleFactor)) / 2;

    // Create a matrix with scale first
    final Matrix4 scaleMatrix = Matrix4.identity()..scale(scaleFactor);

    // Then create a matrix with translation
    final Matrix4 translationMatrix = Matrix4.identity()
      ..setTranslationRaw(translationX, 50.0, 0);

    // Combine the matrices: first scale, then translate
    _transformationController.value = translationMatrix * scaleMatrix;

    // Listen for zoom changes
    _transformationController.addListener(_onZoomChanged);

    // Initialize animation controller for smooth zoom
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Ensure cursor blinks every 500ms without full app rebuild
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _showCursor = !_showCursor; // Toggle cursor visibility
      });
    });

    // Set up the callback for clearing highlighting
    if (widget.onClearHighlightingCallback != null) {
      widget.onClearHighlightingCallback!(clearHighlighting);
    }

    // Set up the callbacks for button state functions
    if (widget.onButtonStateCallbacks != null) {
      widget.onButtonStateCallbacks!(
          _updateTieButtonState, _updateFlipNoteButtonState);
    }

    // Set up the callback for zooming to a note
    if (widget.onZoomToNoteCallback != null) {
      widget.onZoomToNoteCallback!(_zoomToNote);
    }
  }

  /// Zoom and scroll to focus on a specific note with smooth animation
  void _zoomToNote(int rowIndex, int noteIndex) {
    final rowSpacingList =
        context.read<ListOfSpacingForEachRow>().rowSpacingList;
    final globalRowSpacingProvider = context.read<RowSpacingProvider>();

    if (rowIndex >= widget.sheetNoteRows.length || noteIndex < 0) return;

    final notes = widget.sheetNoteRows[rowIndex].chords;
    if (noteIndex >= notes.length) return;

    final currentRowSpacing = rowSpacingList[rowIndex];

    // Calculate note X position
    final noteX =
        calculateXPositionForIndex(noteIndex, notes, currentRowSpacing, false);

    // Calculate note Y position
    double rowSpacing = globalRowSpacingProvider.rowSpacing;
    const double rowHeight = 40.0;
    const double verticalOffset = 150.0;
    final double noteY =
        verticalOffset + (rowIndex * (rowSpacing + rowHeight)) + 50;

    // Target scale (zoom level)
    const double targetScale = 0.7;

    // Calculate the center of the VISIBLE canvas area (excluding keyboard and status bar)
    const double keyboardHeight = 312.0;
    final double appBarHeight = AppBar().preferredSize.height;
    final double visibleCanvasHeight = widget.screenSize.height -
        appBarHeight -
        keyboardHeight -
        widget.statusBarHeight;

    final double centerX = widget.screenSize.width / 2;
    final double centerY = visibleCanvasHeight / 2;

    // Account for the scale when calculating translation
    double translationX = centerX - (noteX * targetScale);
    double translationY = centerY - (noteY * targetScale);

    // Clamp translation to keep within canvas bounds
    final double canvasWidth = widget.musicSheetWidth;
    final double scaledCanvasWidth = canvasWidth * targetScale;
    final double scaledCanvasHeight =
        5000 * targetScale; // Approximate max height

    // Clamp X: ensure canvas doesn't scroll too far left or right
    // Only clamp if canvas is wider than screen
    if (scaledCanvasWidth > widget.screenSize.width) {
      final double minTranslationX =
          widget.screenSize.width - scaledCanvasWidth;
      final double maxTranslationX = 0;
      translationX = translationX.clamp(minTranslationX, maxTranslationX);
    }

    // Clamp Y: ensure canvas doesn't scroll too far up or down
    // Only clamp if canvas is taller than screen
    if (scaledCanvasHeight > visibleCanvasHeight) {
      final double minTranslationY = visibleCanvasHeight - scaledCanvasHeight;
      final double maxTranslationY = 0;
      translationY = translationY.clamp(minTranslationY, maxTranslationY);
    }

    // Create transformation matrix
    final Matrix4 targetMatrix = Matrix4.identity()
      ..translate(translationX, translationY)
      ..scale(targetScale);

    // Get current matrix
    final Matrix4 currentMatrix = _transformationController.value;

    // Create animation from current to target matrix
    _zoomAnimation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _zoomAnimationController,
      curve: Curves.easeInOut,
    ));

    // Listen to animation updates
    void animationListener() {
      _transformationController.value = _zoomAnimation!.value;
    }

    _zoomAnimationController.addListener(animationListener);

    // Cleanup and update state when animation completes
    _zoomAnimationController.forward(from: 0.0).then((_) {
      _zoomAnimationController.removeListener(animationListener);
      setState(() {
        isZoomed = true;
      });
    });
  }

  /// Wrapper functions to update button states
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

  /// Method to clear any active highlighting
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
    // Get current transformation matrix
    final Matrix4 currentMatrix = _transformationController.value;

    // Get current scale and translation
    final double currentScale = currentMatrix.getMaxScaleOnAxis();
    final double currentTranslationY = currentMatrix.getTranslation().y;

    // Target scale
    final double targetScale = initialScale * 0.9;

    // Calculate screen dimensions
    final double screenCenterX = widget.screenSize.width / 2;
    const double keyboardHeight = 312.0;
    final double appBarHeight = AppBar().preferredSize.height;
    final double visibleCanvasHeight = widget.screenSize.height -
        appBarHeight -
        keyboardHeight -
        widget.statusBarHeight;
    final double screenCenterY = visibleCanvasHeight / 2;

    // Get the inverse of current matrix to find the canvas point at screen center
    final Matrix4 inverseMatrix = Matrix4.inverted(currentMatrix);
    final vector_math.Vector3 canvasCenterPoint = inverseMatrix
        .transform3(vector_math.Vector3(screenCenterX, screenCenterY, 0));

    // Center the canvas horizontally (canvas center should be at screen center)
    final double canvasCenterX = widget.musicSheetWidth / 2;
    double translationX = screenCenterX - (canvasCenterX * targetScale);

    // For Y, keep the same canvas Y position at screen center
    double translationY = screenCenterY - (canvasCenterPoint.y * targetScale);

    // Clamp translation to keep within canvas bounds
    final double canvasWidth = widget.musicSheetWidth;
    final double scaledCanvasWidth = canvasWidth * targetScale;
    final double scaledCanvasHeight =
        5000 * targetScale; // Approximate max height

    // Clamp X: ensure canvas doesn't scroll too far left or right
    // Only clamp if canvas is wider than screen
    if (scaledCanvasWidth > widget.screenSize.width) {
      final double minTranslationX =
          widget.screenSize.width - scaledCanvasWidth;
      final double maxTranslationX = 0;
      translationX = translationX.clamp(minTranslationX, maxTranslationX);
    }

    // Clamp Y: ensure canvas doesn't scroll too far up or down
    // Only clamp if canvas is taller than screen
    if (scaledCanvasHeight > visibleCanvasHeight) {
      final double minTranslationY = visibleCanvasHeight - scaledCanvasHeight;
      final double maxTranslationY = 0;
      translationY = translationY.clamp(minTranslationY, maxTranslationY);
    }

    // Create target transformation matrix
    final Matrix4 targetMatrix = Matrix4.identity()
      ..translate(translationX, translationY)
      ..scale(targetScale);

    // Create animation from current to target matrix
    _zoomAnimation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _zoomAnimationController,
      curve: Curves.easeInOut,
    ));

    // Listen to animation updates
    void animationListener() {
      _transformationController.value = _zoomAnimation!.value;
    }

    _zoomAnimationController.addListener(animationListener);

    // Cleanup and update state when animation completes
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

  void _handleDoubleTap(TapDownDetails details) {
    // Skip if we're in highlight mode
    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      return;
    }

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localOffset = renderBox.globalToLocal(details.globalPosition);

    // Get the TransformationController from InteractiveViewer
    final Matrix4 transformMatrix = _transformationController.value;

    // Apply inverse transformation to adjust for zoom/pan
    final Matrix4 inverseMatrix = Matrix4.inverted(transformMatrix);
    final vector_math.Vector3 transformedPosition = inverseMatrix
        .transform3(vector_math.Vector3(localOffset.dx, localOffset.dy, 0));

    final double tapX = transformedPosition.x;
    final double tapY = transformedPosition.y;

    int closestRowIndex = findClosestRow(widget.sheetNoteRows, tapY);

    // Check if we're tapping on a dynamic marking - don't zoom if so
    for (int i = 0;
        i < widget.sheetNoteRows[closestRowIndex].chords.length;
        i++) {
      final note = widget.sheetNoteRows[closestRowIndex].chords[i];
      if (note.isCrescendoStart || note.isDecrescendoStart) {
        var endIndex = note.isCrescendoStart
            ? (note.crescendoEndIndex! <
                    widget.sheetNoteRows[closestRowIndex].chords.length - 1
                ? note.crescendoEndIndex!
                : widget.sheetNoteRows[closestRowIndex].chords.length - 1)
            : note.decrescendoEndIndex! <
                    widget.sheetNoteRows[closestRowIndex].chords.length - 1
                ? note.decrescendoEndIndex!
                : widget.sheetNoteRows[closestRowIndex].chords.length - 1;

        final rect = getDynamicMarkingRect(i, endIndex, closestRowIndex);
        if (rect.contains(Offset(tapX, tapY))) {
          return; // Don't zoom if tapping on dynamic marking
        }
      }
    }

    int closestNoteIndex = findClosestNoteIndex(
        widget.sheetNoteRows[closestRowIndex].chords, tapX, closestRowIndex);

    // Zoom to the double-tapped note
    _zoomToNote(closestRowIndex, closestNoteIndex);
  }

  void _handleTap(TapDownDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localOffset = renderBox.globalToLocal(details.globalPosition);

    final Matrix4 transformMatrix = _transformationController.value;
    final Matrix4 inverseMatrix = Matrix4.inverted(transformMatrix);
    final vector_math.Vector3 transformedPosition = inverseMatrix
        .transform3(vector_math.Vector3(localOffset.dx, localOffset.dy, 0));

    final double tapX = transformedPosition.x;
    final double tapY = transformedPosition.y;

    // Check if we're in Select Rows mode
    final selectRowsModeProvider = context.read<SelectRowsModeProvider>();
    if (selectRowsModeProvider.isSelectRowsMode) {
      // In select rows mode, only handle row tapping
      int tappedRow = findClosestRow(widget.sheetNoteRows, tapY);
      setState(() {
        selectRowsModeProvider.toggleRowSelection(tappedRow);
      });
      return;
    }

    // First check if tapping outside a selected dynamic marking to deselect it
    if (_editingDynamicIndex != null && _editingDynamicRow != null) {
      final note = widget
          .sheetNoteRows[_editingDynamicRow!].chords[_editingDynamicIndex!];
      var endIndex = note.isCrescendoStart
          ? (note.crescendoEndIndex! <
                  widget.sheetNoteRows[_editingDynamicRow!].chords.length - 1
              ? note.crescendoEndIndex!
              : widget.sheetNoteRows[_editingDynamicRow!].chords.length - 1)
          : note.decrescendoEndIndex! <
                  widget.sheetNoteRows[_editingDynamicRow!].chords.length - 1
              ? note.decrescendoEndIndex!
              : widget.sheetNoteRows[_editingDynamicRow!].chords.length - 1;

      final rect = getDynamicMarkingRect(
          _editingDynamicIndex!, endIndex, _editingDynamicRow!);

      // If tapping outside the current selected marking, deselect it
      if (!rect.contains(Offset(tapX, tapY))) {
        setState(() {
          _editingDynamicIndex = null;
          _editingDynamicRow = null;
          _totalDragDelta = Offset.zero;
        });
        // Continue to check if tapping on another marking or note
      } else {
        // Tapping inside the same marking, keep it selected
        return;
      }
    }

    // Handle highlight range interactions
    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      final Rect highlightRect = _calculateHighlightRect();
      final Offset leftHandle =
          Offset(highlightRect.left, highlightRect.center.dx);
      final Offset rightHandle =
          Offset(highlightRect.right, highlightRect.center.dx);

      const double handleRadius =
          50.0; // Slightly larger than visual handle for easier clicking

      // Check if clicking near left handle
      if ((Offset(tapX, tapY) - leftHandle).distance <= handleRadius) {
        setState(() {
          _isDraggingLeftHandle = true;
          _isDraggingRightHandle = false;
          _fixedBoundary = _dragEnd;
          _totalDragDelta = Offset.zero;
        });
        return;
      }

      // Check if clicking near right handle
      if ((Offset(tapX, tapY) - rightHandle).distance <= handleRadius) {
        setState(() {
          _isDraggingLeftHandle = false;
          _isDraggingRightHandle = true;
          _fixedBoundary = _dragStart;
          _totalDragDelta = Offset.zero;
        });
        return;
      }

      if (!highlightRect.inflate(20).contains(Offset(tapX, tapY))) {
        setState(() {
          _dragStart = null;
          _dragEnd = null;
          _dragRow = null;
          _isDraggingLeftHandle = false;
          _isDraggingRightHandle = false;
          _fixedBoundary = null;
          _showHighlightButtons = false;
        });
        return;
      }
      return; // Do nothing if tap is inside highlight
    }

    // IMPORTANT: Check ALL rows for dynamic markings BEFORE determining closest row
    // This prevents the issue where tapping on a marking selects the row below
    // because the marking is drawn below the staff
    for (int rowIndex = 0; rowIndex < widget.sheetNoteRows.length; rowIndex++) {
      for (int i = 0; i < widget.sheetNoteRows[rowIndex].chords.length; i++) {
        final note = widget.sheetNoteRows[rowIndex].chords[i];
        if (note.isCrescendoStart || note.isDecrescendoStart) {
          var endIndex = note.isCrescendoStart
              ? (note.crescendoEndIndex! <
                      widget.sheetNoteRows[rowIndex].chords.length - 1
                  ? note.crescendoEndIndex!
                  : widget.sheetNoteRows[rowIndex].chords.length - 1)
              : note.decrescendoEndIndex! <
                      widget.sheetNoteRows[rowIndex].chords.length - 1
                  ? note.decrescendoEndIndex!
                  : widget.sheetNoteRows[rowIndex].chords.length - 1;

          final rect = getDynamicMarkingRect(i, endIndex, rowIndex);
          if (rect.contains(Offset(tapX, tapY))) {
            setState(() {
              _editingDynamicIndex = i;
              _editingDynamicRow = rowIndex;
              _totalDragDelta = Offset.zero;
            });
            return;
          }
        }
      }
    }

    // Only determine closest row AFTER checking for dynamic markings
    int closestRowIndex = findClosestRow(widget.sheetNoteRows, tapY);

    int closestNoteIndex = findClosestNoteIndex(
        widget.sheetNoteRows[closestRowIndex].chords, tapX, closestRowIndex);

    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
        closestRowIndex, closestNoteIndex);

    // Reset buttons
    setState(() {
      _showHighlightButtons = false;
      _showTieButton = false;
      _showDynamicRemoveButton = false;
      _showBeamAddButton = false;
      _showBeamRemoveButton = false;
      _showSlurRemoveButton = false;
      _showTempoEditButton = false;
      _showDecrescendoRemoveButton = false;
      _showCrescendoRemoveButton = false;
      _editingDynamicIndex = null;
      _editingDynamicRow = null;

      _showMuteRemoveButton = false;
      _showPinchHarmonicRemoveButton = false;
      _showHarmonicRemoveButton = false;
      _showVibratoRemoveButton = false;
      _showBendRemoveButton = false;
      _showPreBendRemoveButton = false;
      _showBendReleaseRemoveButton = false;
      _showPreBendReleaseRemoveButton = false;
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

  void _handleLongPressStart(LongPressStartDetails details) {
    // Disable long press highlighting in read-only mode
    if (widget.isReadOnly) {
      return;
    }

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localOffset = renderBox.globalToLocal(details.globalPosition);

    final Matrix4 transformMatrix = _transformationController.value;
    final Matrix4 inverseMatrix = Matrix4.inverted(transformMatrix);
    final vector_math.Vector3 transformedPosition = inverseMatrix
        .transform3(vector_math.Vector3(localOffset.dx, localOffset.dy, 0));

    final double tapX = transformedPosition.x;
    final double tapY = transformedPosition.y;

    int closestRowIndex = findClosestRow(widget.sheetNoteRows, tapY);
    int noteIndex = findClosestNoteIndex(
        widget.sheetNoteRows[closestRowIndex].chords, tapX, closestRowIndex);

    if (noteIndex != -1) {
      setState(() {
        _dragRow = closestRowIndex;
        _dragStart = noteIndex;
        _dragEnd = noteIndex;
        _isDraggingLeftHandle = false;
        _isDraggingRightHandle = false;
        _fixedBoundary = null;
        _showHighlightButtons = true;
        _showTieButton = false;
        _showDynamicRemoveButton = false;
        _totalDragDelta = Offset.zero;
        _showFlipNoteButton = false;
      });
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    // If a drag is already active, just update its position.
    if (_isDragging || _isEditingDynamic) {
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final Offset localOffset = renderBox.globalToLocal(event.position);
      final Matrix4 transformMatrix = _transformationController.value;
      final Matrix4 inverseMatrix = Matrix4.inverted(transformMatrix);
      final vector_math.Vector3 transformedPosition = inverseMatrix
          .transform3(vector_math.Vector3(localOffset.dx, localOffset.dy, 0));
      final double tapX = transformedPosition.x;

      if (_isEditingDynamic && _editingDynamicRow != null) {
        int closestNoteIndex = findClosestNoteIndex(
            widget.sheetNoteRows[_editingDynamicRow!].chords,
            tapX,
            _editingDynamicRow!);
        setState(() {
          final note = widget
              .sheetNoteRows[_editingDynamicRow!].chords[_editingDynamicIndex!];
          if (note.isCrescendoStart) {
            note.crescendoEndIndex = closestNoteIndex.clamp(
                _editingDynamicIndex!,
                widget.sheetNoteRows[_editingDynamicRow!].chords.length - 1);
          } else {
            note.decrescendoEndIndex = closestNoteIndex.clamp(
                _editingDynamicIndex!,
                widget.sheetNoteRows[_editingDynamicRow!].chords.length - 1);
          }
        });
      } else if (_isDragging && _dragRow != null) {
        int closestNoteIndex = findClosestNoteIndex(
            widget.sheetNoteRows[_dragRow!].chords, tapX, _dragRow!);

        setState(() {
          // Handle different drag scenarios
          if (_isDraggingLeftHandle) {
            // Dragging left handle - update _dragStart, keep _dragEnd fixed
            _dragStart = closestNoteIndex.clamp(
                0, widget.sheetNoteRows[_dragRow!].chords.length - 1);
          } else if (_isDraggingRightHandle) {
            // Dragging right handle - update _dragEnd, keep _dragStart fixed
            _dragEnd = closestNoteIndex.clamp(
                0, widget.sheetNoteRows[_dragRow!].chords.length - 1);
          } else {
            // Default behavior for new selections
            _dragEnd = closestNoteIndex.clamp(
                0, widget.sheetNoteRows[_dragRow!].chords.length - 1);
          }
        });
      }
      _showBeamAddButton = _shouldShowBeamAdd();
      return;
    }

    // If no drag is active, but a selection is primed, accumulate the delta
    // and decide whether to start a drag or allow a scroll.
    if (_dragStart != null ||
        _editingDynamicIndex != null ||
        _isDraggingLeftHandle ||
        _isDraggingRightHandle) {
      _totalDragDelta += event.delta;

      // Use a threshold to avoid accidental drags from a tap.
      if (_totalDragDelta.distance < 10.0) return;

      // If movement is clearly horizontal, start a drag.
      if (_totalDragDelta.dx.abs() > _totalDragDelta.dy.abs() * 2.0) {
        // Before starting the drag, check if we need to detect which handle is being dragged
        if (_dragStart != null &&
            _dragEnd != null &&
            _dragRow != null &&
            !_isDraggingLeftHandle &&
            !_isDraggingRightHandle) {
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final Offset localOffset = renderBox.globalToLocal(event.position);
          final Matrix4 transformMatrix = _transformationController.value;
          final Matrix4 inverseMatrix = Matrix4.inverted(transformMatrix);
          final vector_math.Vector3 transformedPosition =
              inverseMatrix.transform3(
                  vector_math.Vector3(localOffset.dx, localOffset.dy, 0));
          final double currentX = transformedPosition.x;

          final Rect highlightRect = _calculateHighlightRect();

          // Determine which handle to drag based on which half of the highlight area the user clicked
          double highlightCenter =
              (highlightRect.left + highlightRect.right) / 2;

          if (currentX < highlightCenter) {
            // Dragging from left half - drag left handle
            _isDraggingLeftHandle = true;
            _isDraggingRightHandle = false;
            _fixedBoundary = _dragEnd;
          } else {
            // Dragging from right half - drag right handle
            _isDraggingLeftHandle = false;
            _isDraggingRightHandle = true;
            _fixedBoundary = _dragStart;
          }
        }

        setState(() {
          if (_dragStart != null ||
              _isDraggingLeftHandle ||
              _isDraggingRightHandle) _isDragging = true;
          if (_editingDynamicIndex != null) _isEditingDynamic = true;
        });
      }
      // Otherwise (if vertical or diagonal), it's a scroll. Cancel the primed selection.
      else {
        setState(() {
          _dragStart = null;
          _dragEnd = null;
          _dragRow = null;
          _isDraggingLeftHandle = false;
          _isDraggingRightHandle = false;
          _fixedBoundary = null;
          _showHighlightButtons = false;
          _editingDynamicIndex = null;
          _editingDynamicRow = null;
        });
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _totalDragDelta = Offset.zero;
    // If we were dragging, stop. The selection itself (_dragStart) remains
    // until the user taps a button or taps away.
    if (_isDragging || _isEditingDynamic) {
      setState(() {
        _isDragging = false;
        _isEditingDynamic = false;
        _isDraggingLeftHandle = false;
        _isDraggingRightHandle = false;
        _fixedBoundary = null;
      });
    }
  }

  /// **Find the closest row based on the Y position**
  int findClosestRow(List<SheetRows> rows, double tapY) {
    final globalRowSpacingProvider =
        Provider.of<RowSpacingProvider>(context, listen: false);
    double rowSpacing = globalRowSpacingProvider.rowSpacing;
    double sheetHeight = 40.0;
    double rowTotalHeight = rowSpacing + sheetHeight;
    const double verticalOffset = 250.0;

    // Calculate cumulative margin offsets for all rows (same logic as MusicSheetPainter)
    Map<int, double> cumulativeMarginOffsets = {};
    const double pageHeaderMargin = 50.0;
    const double pageFooterMargin = 50.0;

    final pageBreaks =
        PdfExporter.calculatePageBreaks(rows, rowSpacing, widget.sheetFormat);
    double cumulativeOffset = 0.0;

    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      cumulativeMarginOffsets[rowIndex] = cumulativeOffset;

      // Check if this row is at the start of a non-first page (add header margin)
      for (int i = 1; i < pageBreaks.length; i++) {
        final pageInfo = pageBreaks[i];
        if (rowIndex == pageInfo.startRow) {
          cumulativeOffset += pageHeaderMargin;
          break;
        }
      }

      // Check if this row is at the end of any page (add footer margin after it)
      for (int i = 0; i < pageBreaks.length - 1; i++) {
        final pageInfo = pageBreaks[i];
        if (rowIndex == pageInfo.endRow) {
          cumulativeOffset += pageFooterMargin;
          break;
        }
      }
    }

    // Find the closest row by checking each row's position including margins
    double closestDistance = double.infinity;
    int closestRowIndex = 0;

    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final double marginOffset = cumulativeMarginOffsets[rowIndex] ?? 0.0;
      final double rowY =
          verticalOffset + (rowIndex * rowTotalHeight) + marginOffset;
      final double distance = (tapY - rowY).abs();

      if (distance < closestDistance) {
        closestDistance = distance;
        closestRowIndex = rowIndex;
      }
    }

    // Ensure the row index is within valid bounds
    return closestRowIndex.clamp(0, rows.length - 1);
  }

  int findClosestNoteIndex(
      List<MusicalNote> notes, double tapX, int selectedRow) {
    if (notes.isEmpty) return -1;

    var rowSpacingList = context.read<ListOfSpacingForEachRow>().rowSpacingList;
    var currentRowSpacing = rowSpacingList[selectedRow];

    return calculateInsertionIndex(tapX, notes, currentRowSpacing,
        startingX: widget.keyboardType.startingNoteX);
  }

  double _getStaffTop(int rowIndex) {
    final globalRowSpacingProvider =
        Provider.of<RowSpacingProvider>(context, listen: false);
    double rowSpacing = globalRowSpacingProvider.rowSpacing;
    const double sheetHeight = 40.0;
    const double verticalOffset = 150.0;
    return verticalOffset + (rowIndex * (rowSpacing + sheetHeight));
  }

  Rect _calculateHighlightRect() {
    final rowNotes = widget.sheetNoteRows[_dragRow!].chords;
    final rowSpacingList =
        context.read<ListOfSpacingForEachRow>().rowSpacingList;
    final currentRowSpacing = rowSpacingList[_dragRow!];

    final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
    final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

    final double startX =
        calculateXPositionForIndex(start, rowNotes, currentRowSpacing, true);
    final double endX =
        calculateXPositionForIndex(end, rowNotes, currentRowSpacing, false);

    double staffTop = _getStaffTop(_dragRow!);
    double staffCenter = staffTop + 20;

    double min_y = double.infinity;
    double max_y = double.negativeInfinity;

    for (int i = start; i <= end; i++) {
      final note = rowNotes[i];
      double y = note.noteY;
      min_y = math.min(min_y, y - 15);
      max_y = math.max(max_y, y + 15);

      if (note.type == NoteType.rest ||
          note.type == NoteType.clef ||
          note.type == NoteType.bar ||
          note.type == NoteType.accidental ||
          note.type == NoteType.timeSignature ||
          note.type == NoteType.keySignature ||
          note.type == NoteType.accidental ||
          note.type == NoteType.space) {
        min_y = staffTop - 25;
        max_y = staffTop + (lineSpacing * 4) + 25;
      }

      if (note.type != NoteType.whole &&
          note.type != NoteType.rest &&
          note.type != NoteType.clef &&
          note.type != NoteType.bar &&
          note.type != NoteType.accidental) {
        final bool isUpsideDownNote = y < staffCenter;
        double stemHeight = 35.0;
        if (note.type == NoteType.thirtySecond ||
            note.type == NoteType.sixtyFourth) {
          stemHeight += 10.0;
        }

        if ((note.type == NoteType.eighth ||
                note.type == NoteType.sixteenth ||
                note.type == NoteType.thirtySecond ||
                note.type == NoteType.sixtyFourth) &&
            note.isBeamed) {
          var notesGroup = getConnectedNotesGroup(i, rowNotes);
          var connectedNotesGroup = notesGroup.notesGroup;
          if (connectedNotesGroup.isNotEmpty) {
            var notesGroupYs = getConnectedNotesGroupHighestY(
                connectedNotesGroup, 10.0, staffTop, staffCenter);
            double connectedGroupHighestY = notesGroupYs.highestY;
            double connectedGroupLowestY = notesGroupYs.lowestY;
            bool firstNoteUpsideDown = notesGroupYs.firstNoteY < staffCenter;

            if (!firstNoteUpsideDown) {
              stemHeight = (note.noteY - connectedGroupHighestY) + stemHeight;
            } else {
              stemHeight = (connectedGroupLowestY - note.noteY) + stemHeight;
            }

            if (notesGroupYs.doesGroupContain32ndOr64thNote) {
              stemHeight += 10.0;
            }
          }
        }

        if (isUpsideDownNote) {
          min_y = math.min(min_y, y - stemHeight);
        } else {
          max_y = math.max(max_y, y + stemHeight);
        }
      }
    }

    return Rect.fromLTRB(
      startX - 20,
      min_y,
      endX + 20,
      max_y,
    );
  }

  Rect getDynamicMarkingRect(int startIndex, int endIndex, int rowIndex) {
    final rowNotes = widget.sheetNoteRows[rowIndex].chords;
    final rowSpacingList =
        context.read<ListOfSpacingForEachRow>().rowSpacingList;
    final currentRowSpacing = rowSpacingList[rowIndex];

    final double startX = calculateXPositionForIndex(
        startIndex, rowNotes, currentRowSpacing, true);
    final double endX = calculateXPositionForIndex(
        endIndex, rowNotes, currentRowSpacing, false);

    double lowestY = double.negativeInfinity;
    bool hasUpsideDownNoteOnStaff = false;
    double staffTop = _getStaffTop(rowIndex);

    for (int i = startIndex; i <= endIndex; i++) {
      if (rowNotes[i].noteY > lowestY) {
        lowestY = rowNotes[i].noteY;
      }
      if (rowNotes[i].isUpsideDown == true && rowNotes[i].noteY >= staffTop) {
        hasUpsideDownNoteOnStaff = true;
      }
    }

    double staffBottomLineY = staffTop + 40; // 4 lines * 10 spacing
    double minDynamicY = staffBottomLineY + 20;
    double y = math.max(lowestY + 50, minDynamicY);

    if (hasUpsideDownNoteOnStaff) {
      y += 20;
    }

    // Make the hit area larger and more generous for easier tapping
    // Extend left, right, top, and bottom by extra padding
    return Rect.fromLTRB(startX - 10, y - 20, endX + 90, y + 50);
  }

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
        }
      }
    }
    return false;
  }

  // Helper methods for remove condition detection
  bool _shouldShowTieRemove() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    // Check if there's no active highlighted notes AND current selected note has isTiedToNext = true
    if (_dragStart == null && _dragEnd == null) {
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0 && index < widget.sheetNoteRows[row].chords.length) {
        return widget.sheetNoteRows[row].chords[index].isTiedToNext;
      }
    }
    return false;
  }

  bool _shouldShowDecrescendoRemove() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Check if active highlighted range contains a decrescendo
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final note = widget.sheetNoteRows[_dragRow!].chords[i];
        if (note.isDecrescendoStart && note.decrescendoEndIndex != null) {
          // Check if decrescendo overlaps with highlight range
          if ((i >= start && i <= end) ||
              (note.decrescendoEndIndex! >= start &&
                  note.decrescendoEndIndex! <= end)) {
            return true;
          }
        }
      }
    } else {
      // Check if current selected note is in range of existing decrescendo
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final note = widget.sheetNoteRows[row].chords[i];
          if (note.isDecrescendoStart && note.decrescendoEndIndex != null) {
            if (i <= index && note.decrescendoEndIndex! >= index) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  bool _shouldShowCrescendoRemove() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Check if active highlighted range contains a crescendo
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final note = widget.sheetNoteRows[_dragRow!].chords[i];
        if (note.isCrescendoStart && note.crescendoEndIndex != null) {
          // Check if crescendo overlaps with highlight range
          if ((i >= start && i <= end) ||
              (note.crescendoEndIndex! >= start &&
                  note.crescendoEndIndex! <= end)) {
            return true;
          }
        }
      }
    } else {
      // Check if current selected note is in range of existing crescendo
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final note = widget.sheetNoteRows[row].chords[i];
          if (note.isCrescendoStart && note.crescendoEndIndex != null) {
            if (i <= index && note.crescendoEndIndex! >= index) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  bool _shouldShowSlurRemove() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Check if active highlighted range contains a slur
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final note = widget.sheetNoteRows[_dragRow!].chords[i];
        if (note.slurEndIndex != null) {
          // Check if slur overlaps with highlight range
          if ((i >= start && i <= end) ||
              (note.slurEndIndex! >= start && note.slurEndIndex! <= end)) {
            return true;
          }
        }
      }
    } else {
      // Check if current selected note is in range of existing slur
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final note = widget.sheetNoteRows[row].chords[i];
          if (note.slurEndIndex != null) {
            if (i <= index && note.slurEndIndex! >= index) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

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
      // Check if any note in active highlighted range has isConnected = true
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

    // Check if there's no active highlighted notes AND current selected note has dynamicCharacter
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

    // Check if there's no active highlighted notes AND current selected note is valid
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
  bool _shouldShowMuteRemove() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Check if active highlighted range contains a crescendo
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final chord = widget.sheetNoteRows[_dragRow!].chords[i];
        if (chord.isMuteStart && chord.muteEndIndex != null) {
          // Check if crescendo overlaps with highlight range
          if ((i >= start && i <= end) ||
              (chord.muteEndIndex! >= start && chord.muteEndIndex! <= end)) {
            return true;
          }
        }
      }
    } else {
      // Check if current selected note is in range of existing crescendo
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final chord = widget.sheetNoteRows[row].chords[i];
          if (chord.isMuteStart && chord.muteEndIndex != null) {
            if (i <= index && chord.muteEndIndex! >= index) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  bool _shouldShowPinchHarmonicRemove() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Check if active highlighted range contains a crescendo
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final chord = widget.sheetNoteRows[_dragRow!].chords[i];
        if (chord.isPinchHarmonicStart && chord.pinchHarmonicEndIndex != null) {
          // Check if crescendo overlaps with highlight range
          if ((i >= start && i <= end) ||
              (chord.pinchHarmonicEndIndex! >= start &&
                  chord.pinchHarmonicEndIndex! <= end)) {
            return true;
          }
        }
      }
    } else {
      // Check if current selected note is in range of existing crescendo
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final chord = widget.sheetNoteRows[row].chords[i];
          if (chord.isPinchHarmonicStart &&
              chord.pinchHarmonicEndIndex != null) {
            if (i <= index && chord.pinchHarmonicEndIndex! >= index) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  bool _shouldShowHarmonicRemove() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Check if active highlighted range contains a crescendo
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final chord = widget.sheetNoteRows[_dragRow!].chords[i];
        if (chord.isHarmonicStart && chord.harmonicEndIndex != null) {
          // Check if crescendo overlaps with highlight range
          if ((i >= start && i <= end) ||
              (chord.harmonicEndIndex! >= start &&
                  chord.harmonicEndIndex! <= end)) {
            return true;
          }
        }
      }
    } else {
      // Check if current selected note is in range of existing crescendo
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final chord = widget.sheetNoteRows[row].chords[i];
          if (chord.isHarmonicStart && chord.harmonicEndIndex != null) {
            if (i <= index && chord.harmonicEndIndex! >= index) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  bool _shouldShowVibratoRemove() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Check if active highlighted range contains a crescendo
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final chord = widget.sheetNoteRows[_dragRow!].chords[i];
        if (chord.isVibratoStart && chord.vibratoEndIndex != null) {
          // Check if crescendo overlaps with highlight range
          if ((i >= start && i <= end) ||
              (chord.vibratoEndIndex! >= start &&
                  chord.vibratoEndIndex! <= end)) {
            return true;
          }
        }
      }
    } else {
      // Check if current selected note is in range of existing crescendo
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final chord = widget.sheetNoteRows[row].chords[i];
          if (chord.isVibratoStart && chord.vibratoEndIndex != null) {
            if (i <= index && chord.vibratoEndIndex! >= index) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  bool _shouldShowBendRemove() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Check if active highlighted range contains a crescendo
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final chord = widget.sheetNoteRows[_dragRow!].chords[i];
        final childNotes = chord.childNotes;
        if (childNotes != null) {
          for (int i = 0; i < childNotes.length; i++) {
            var note = childNotes[i];
            if (note.isBendStart && note.bendEndIndex != null) {
              // Check if crescendo overlaps with highlight range
              if ((i >= start && i <= end) ||
                  (note.bendEndIndex! >= start && note.bendEndIndex! <= end)) {
                return true;
              }
            }
          }
        }
      }
    } else {
      // Check if current selected note is in range of existing crescendo
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final chord = widget.sheetNoteRows[row].chords[i];
          final childNotes = chord.childNotes;
          if (childNotes != null) {
            for (int i = 0; i < childNotes.length; i++) {
              var note = childNotes[i];
              if (note.isBendStart && note.bendEndIndex != null) {
                if (i <= index && note.bendEndIndex! >= index) {
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

  bool _shouldShowPreBendRemove() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Check if active highlighted range contains a crescendo
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final chord = widget.sheetNoteRows[_dragRow!].chords[i];
        final childNotes = chord.childNotes;
        if (childNotes != null) {
          for (int i = 0; i < childNotes.length; i++) {
            var note = childNotes[i];
            if (note.isPreBendStart && note.preBendEndIndex != null) {
              // Check if crescendo overlaps with highlight range
              if ((i >= start && i <= end) ||
                  (note.preBendEndIndex! >= start &&
                      note.preBendEndIndex! <= end)) {
                return true;
              }
            }
          }
        }
      }
    } else {
      // Check if current selected note is in range of existing crescendo
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final chord = widget.sheetNoteRows[row].chords[i];
          final childNotes = chord.childNotes;
          if (childNotes != null) {
            for (int i = 0; i < childNotes.length; i++) {
              var note = childNotes[i];
              if (note.isPreBendStart && note.preBendEndIndex != null) {
                if (i <= index && note.preBendEndIndex! >= index) {
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

  bool _shouldShowBendReleaseRemove() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Check if active highlighted range contains a crescendo
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final chord = widget.sheetNoteRows[_dragRow!].chords[i];
        final childNotes = chord.childNotes;
        if (childNotes != null) {
          for (int i = 0; i < childNotes.length; i++) {
            var note = childNotes[i];
            if (note.isBendReleaseStart && note.bendReleaseEndIndex != null) {
              // Check if crescendo overlaps with highlight range
              if ((i >= start && i <= end) ||
                  (note.bendReleaseEndIndex! >= start &&
                      note.bendReleaseEndIndex! <= end)) {
                return true;
              }
            }
          }
        }
      }
    } else {
      // Check if current selected note is in range of existing crescendo
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final chord = widget.sheetNoteRows[row].chords[i];
          final childNotes = chord.childNotes;
          if (childNotes != null) {
            for (int i = 0; i < childNotes.length; i++) {
              var note = childNotes[i];
              if (note.isBendReleaseStart && note.bendReleaseEndIndex != null) {
                if (i <= index && note.bendReleaseEndIndex! >= index) {
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

  bool _shouldShowPreBendReleaseRemove() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Check if active highlighted range contains a crescendo
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final chord = widget.sheetNoteRows[_dragRow!].chords[i];
        final childNotes = chord.childNotes;
        if (childNotes != null) {
          for (int i = 0; i < childNotes.length; i++) {
            var note = childNotes[i];
            if (note.isPreBendReleaseStart &&
                note.preBendReleaseEndIndex != null) {
              // Check if crescendo overlaps with highlight range
              if ((i >= start && i <= end) ||
                  (note.preBendReleaseEndIndex! >= start &&
                      note.preBendReleaseEndIndex! <= end)) {
                return true;
              }
            }
          }
        }
      }
    } else {
      // Check if current selected note is in range of existing crescendo
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final chord = widget.sheetNoteRows[row].chords[i];
          final childNotes = chord.childNotes;
          if (childNotes != null) {
            for (int i = 0; i < childNotes.length; i++) {
              var note = childNotes[i];
              if (note.isPreBendReleaseStart &&
                  note.preBendReleaseEndIndex != null) {
                if (i <= index && note.preBendReleaseEndIndex! >= index) {
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

  String _getDynamicCharacter() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    final row = selectedNoteProvider.selectedRow;
    final index = selectedNoteProvider.selectedIndex;

    if (index >= 0 && index < widget.sheetNoteRows[row].chords.length) {
      return widget.sheetNoteRows[row].chords[index].dynamicCharacter;
    }
    return "";
  }

  /// Check if any of the selected rows already have curly braces
  bool _selectedRowsHaveCurlyBraces(List<int> selectedRows) {
    return widget.sheetProperties.curlyBraceGroups.any((group) {
      return selectedRows
          .any((row) => row >= group.startRow && row <= group.endRow);
    });
  }

  /// Get the connected row group index for a given row
  /// For example, if rowsPerGroup is 2 (piano), row 0 and 1 return 0, row 2 and 3 return 1, etc.
  int _getRowGroupIndex(int rowIndex) {
    final rowsPerGroup = widget.sheetFormat.rowsPerGroup;
    return rowIndex ~/ rowsPerGroup;
  }

  /// Check if all selected rows belong to the same connected row group
  bool _selectedRowsInSameGroup(List<int> selectedRows) {
    if (selectedRows.isEmpty) return false;

    final firstRowGroup = _getRowGroupIndex(selectedRows.first);
    return selectedRows.every((row) => _getRowGroupIndex(row) == firstRowGroup);
  }

  /// Get valid curly brace groups from selected rows
  /// Returns contiguous groups within each row group that have 2+ rows
  List<List<int>> _getValidBraceGroups(
      SelectRowsModeProvider selectRowsModeProvider) {
    final selectedRows = selectRowsModeProvider.selectedRows.toList();
    final validGroups = <List<int>>[];

    // Group selected rows by their row group
    final rowsByGroup = <int, List<int>>{};
    for (final row in selectedRows) {
      final groupIndex = _getRowGroupIndex(row);
      rowsByGroup.putIfAbsent(groupIndex, () => []).add(row);
    }

    // For each row group, find contiguous groups
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
      contiguousGroups.add([start, end]); // Add the last group

      // Add groups with 2+ rows
      for (final group in contiguousGroups) {
        if (group[1] - group[0] + 1 >= 2) {
          validGroups.add(group);
        }
      }
    }

    return validGroups;
  }

  // Remove action methods
  void _removeCurlyBraces() {
    context.read<SheetUndoManager>().saveState(widget.sheetNoteRows);

    final selectRowsModeProvider = context.read<SelectRowsModeProvider>();
    final selectedRows = selectRowsModeProvider.selectedRows.toList();

    setState(() {
      widget.sheetProperties.curlyBraceGroups.removeWhere((group) {
        return selectedRows
            .any((row) => row >= group.startRow && row <= group.endRow);
      });
    });
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
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    context.read<SheetUndoManager>().saveState(widget.sheetNoteRows);

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Remove decrescendos in highlighted range
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final note = widget.sheetNoteRows[_dragRow!].chords[i];
        if (note.isDecrescendoStart && note.decrescendoEndIndex != null) {
          if ((i >= start && i <= end) ||
              (note.decrescendoEndIndex! >= start &&
                  note.decrescendoEndIndex! <= end)) {
            note.isDecrescendoStart = false;
            note.decrescendoEndIndex = null;
          }
        }
      }
    } else {
      // Remove decrescendo affecting current selected note
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final note = widget.sheetNoteRows[row].chords[i];
          if (note.isDecrescendoStart && note.decrescendoEndIndex != null) {
            if (i <= index && note.decrescendoEndIndex! >= index) {
              note.isDecrescendoStart = false;
              note.decrescendoEndIndex = null;
            }
          }
        }
      }
    }

    _showDecrescendoRemoveButton = false;
  }

  void _removeCrescendo() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    context.read<SheetUndoManager>().saveState(widget.sheetNoteRows);

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Remove crescendos in highlighted range
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final note = widget.sheetNoteRows[_dragRow!].chords[i];
        if (note.isCrescendoStart && note.crescendoEndIndex != null) {
          if ((i >= start && i <= end) ||
              (note.crescendoEndIndex! >= start &&
                  note.crescendoEndIndex! <= end)) {
            note.isCrescendoStart = false;
            note.crescendoEndIndex = null;
          }
        }
      }
    } else {
      // Remove crescendo affecting current selected note
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final note = widget.sheetNoteRows[row].chords[i];
          if (note.isCrescendoStart && note.crescendoEndIndex != null) {
            if (i <= index && note.crescendoEndIndex! >= index) {
              note.isCrescendoStart = false;
              note.crescendoEndIndex = null;
            }
          }
        }
      }
    }

    _showCrescendoRemoveButton = false;
  }

  void _removeSlur() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    context.read<SheetUndoManager>().saveState(widget.sheetNoteRows);

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Remove slurs in highlighted range
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final note = widget.sheetNoteRows[_dragRow!].chords[i];
        if (note.slurEndIndex != null) {
          if ((i >= start && i <= end) ||
              (note.slurEndIndex! >= start && note.slurEndIndex! <= end)) {
            note.slurEndIndex = null;
          }
        }
      }
    } else {
      // Remove slur affecting current selected note
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final note = widget.sheetNoteRows[row].chords[i];
          if (note.slurEndIndex != null) {
            if (i <= index && note.slurEndIndex! >= index) {
              note.slurEndIndex = null;
            }
          }
        }
      }
    }

    _showSlurRemoveButton = false;
  }

  void _removeBeam() {
    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Set all notes in highlight range to isConnected = false
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
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    context.read<SheetUndoManager>().saveState(widget.sheetNoteRows);

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final note = widget.sheetNoteRows[_dragRow!].chords[i];
        if (note.isMuteStart && note.muteEndIndex != null) {
          if ((i >= start && i <= end) ||
              (note.muteEndIndex! >= start && note.muteEndIndex! <= end)) {
            note.isMuteStart = false;
            note.muteEndIndex = null;
          }
        }
      }
    } else {
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final note = widget.sheetNoteRows[row].chords[i];
          if (note.isMuteStart && note.muteEndIndex != null) {
            if (i <= index && note.muteEndIndex! >= index) {
              note.isMuteStart = false;
              note.muteEndIndex = null;
            }
          }
        }
      }
    }

    _showMuteRemoveButton = false;
  }

  void _removePinchHarmonic() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    context.read<SheetUndoManager>().saveState(widget.sheetNoteRows);

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final note = widget.sheetNoteRows[_dragRow!].chords[i];
        if (note.isPinchHarmonicStart && note.pinchHarmonicEndIndex != null) {
          if ((i >= start && i <= end) ||
              (note.pinchHarmonicEndIndex! >= start &&
                  note.pinchHarmonicEndIndex! <= end)) {
            note.isPinchHarmonicStart = false;
            note.pinchHarmonicEndIndex = null;
          }
        }
      }
    } else {
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final note = widget.sheetNoteRows[row].chords[i];
          if (note.isPinchHarmonicStart && note.pinchHarmonicEndIndex != null) {
            if (i <= index && note.pinchHarmonicEndIndex! >= index) {
              note.isPinchHarmonicStart = false;
              note.pinchHarmonicEndIndex = null;
            }
          }
        }
      }
    }

    _showPinchHarmonicRemoveButton = false;
  }

  void _removeHarmonic() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    context.read<SheetUndoManager>().saveState(widget.sheetNoteRows);

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final note = widget.sheetNoteRows[_dragRow!].chords[i];
        if (note.isHarmonicStart && note.harmonicEndIndex != null) {
          if ((i >= start && i <= end) ||
              (note.harmonicEndIndex! >= start &&
                  note.harmonicEndIndex! <= end)) {
            note.isHarmonicStart = false;
            note.harmonicEndIndex = null;
          }
        }
      }
    } else {
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final note = widget.sheetNoteRows[row].chords[i];
          if (note.isHarmonicStart && note.harmonicEndIndex != null) {
            if (i <= index && note.harmonicEndIndex! >= index) {
              note.isHarmonicStart = false;
              note.harmonicEndIndex = null;
            }
          }
        }
      }
    }

    _showHarmonicRemoveButton = false;
  }

  void _removeVibrato() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    context.read<SheetUndoManager>().saveState(widget.sheetNoteRows);

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Remove crescendos in highlighted range
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final note = widget.sheetNoteRows[_dragRow!].chords[i];
        if (note.isVibratoStart && note.vibratoEndIndex != null) {
          if ((i >= start && i <= end) ||
              (note.vibratoEndIndex! >= start &&
                  note.vibratoEndIndex! <= end)) {
            note.isVibratoStart = false;
            note.vibratoEndIndex = null;
          }
        }
      }
    } else {
      // Remove crescendo affecting current selected note
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final note = widget.sheetNoteRows[row].chords[i];
          if (note.isVibratoStart && note.vibratoEndIndex != null) {
            if (i <= index && note.vibratoEndIndex! >= index) {
              note.isVibratoStart = false;
              note.vibratoEndIndex = null;
            }
          }
        }
      }
    }

    _showVibratoRemoveButton = false;
  }

  void _removeBend() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    context.read<SheetUndoManager>().saveState(widget.sheetNoteRows);

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final chord = widget.sheetNoteRows[_dragRow!].chords[i];
        final childNotes = chord.childNotes;
        if (childNotes != null) {
          for (int i = 0; i < childNotes.length; i++) {
            var note = childNotes[i];
            if (note.isBendStart && note.bendEndIndex != null) {
              if ((i >= start && i <= end) ||
                  (note.bendEndIndex! >= start && note.bendEndIndex! <= end)) {
                note.isBendStart = false;
                note.bendEndIndex = null;
              }
            }
          }
        }
      }
    } else {
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final chord = widget.sheetNoteRows[row].chords[i];
          final childNotes = chord.childNotes;
          if (childNotes != null) {
            for (int i = 0; i < childNotes.length; i++) {
              var note = childNotes[i];
              if (note.isBendStart && note.bendEndIndex != null) {
                if (i <= index && note.bendEndIndex! >= index) {
                  note.isBendStart = false;
                  note.bendEndIndex = null;
                }
              }
            }
          }
        }
      }
    }

    _showBendRemoveButton = false;
  }

  void _removePreBend() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    context.read<SheetUndoManager>().saveState(widget.sheetNoteRows);

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final chord = widget.sheetNoteRows[_dragRow!].chords[i];
        final childNotes = chord.childNotes;
        if (childNotes != null) {
          for (int i = 0; i < childNotes.length; i++) {
            var note = childNotes[i];
            if (note.isPreBendStart && note.preBendEndIndex != null) {
              if ((i >= start && i <= end) ||
                  (note.preBendEndIndex! >= start &&
                      note.preBendEndIndex! <= end)) {
                note.isPreBendStart = false;
                note.preBendEndIndex = null;
              }
            }
          }
        }
      }
    } else {
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final chord = widget.sheetNoteRows[row].chords[i];
          final childNotes = chord.childNotes;
          if (childNotes != null) {
            for (int i = 0; i < childNotes.length; i++) {
              var note = childNotes[i];
              if (note.isPreBendStart && note.preBendEndIndex != null) {
                if (i <= index && note.preBendEndIndex! >= index) {
                  note.isPreBendStart = false;
                  note.preBendEndIndex = null;
                }
              }
            }
          }
        }
      }
    }

    _showPreBendRemoveButton = false;
  }

  void _removeBendRelease() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    context.read<SheetUndoManager>().saveState(widget.sheetNoteRows);

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final chord = widget.sheetNoteRows[_dragRow!].chords[i];
        final childNotes = chord.childNotes;
        if (childNotes != null) {
          for (int i = 0; i < childNotes.length; i++) {
            var note = childNotes[i];
            if (note.isBendReleaseStart && note.bendReleaseEndIndex != null) {
              if ((i >= start && i <= end) ||
                  (note.bendReleaseEndIndex! >= start &&
                      note.bendReleaseEndIndex! <= end)) {
                note.isBendReleaseStart = false;
                note.bendReleaseEndIndex = null;
              }
            }
          }
        }
      }
    } else {
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final chord = widget.sheetNoteRows[row].chords[i];
          final childNotes = chord.childNotes;
          if (childNotes != null) {
            for (int i = 0; i < childNotes.length; i++) {
              var note = childNotes[i];
              if (note.isBendReleaseStart && note.bendReleaseEndIndex != null) {
                if (i <= index && note.bendReleaseEndIndex! >= index) {
                  note.isBendReleaseStart = false;
                  note.bendReleaseEndIndex = null;
                }
              }
            }
          }
        }
      }
    }

    _showBendReleaseRemoveButton = false;
  }

  void _removePreBendRelease() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    context.read<SheetUndoManager>().saveState(widget.sheetNoteRows);

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].chords.length; i++) {
        final chord = widget.sheetNoteRows[_dragRow!].chords[i];
        final childNotes = chord.childNotes;
        if (childNotes != null) {
          for (int i = 0; i < childNotes.length; i++) {
            var note = childNotes[i];
            if (note.isPreBendReleaseStart &&
                note.preBendReleaseEndIndex != null) {
              if ((i >= start && i <= end) ||
                  (note.preBendReleaseEndIndex! >= start &&
                      note.preBendReleaseEndIndex! <= end)) {
                note.isPreBendReleaseStart = false;
                note.preBendReleaseEndIndex = null;
              }
            }
          }
        }
      }
    } else {
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0) {
        for (int i = 0; i < widget.sheetNoteRows[row].chords.length; i++) {
          final chord = widget.sheetNoteRows[row].chords[i];
          final childNotes = chord.childNotes;
          if (childNotes != null) {
            for (int i = 0; i < childNotes.length; i++) {
              var note = childNotes[i];
              if (note.isPreBendReleaseStart &&
                  note.preBendReleaseEndIndex != null) {
                if (i <= index && note.preBendReleaseEndIndex! >= index) {
                  note.isPreBendReleaseStart = false;
                  note.preBendReleaseEndIndex = null;
                }
              }
            }
          }
        }
      }
    }

    _showPreBendReleaseRemoveButton = false;
  }

  @override
  Widget build(BuildContext context) {
    final selectedNoteProvider =
        Provider.of<CurrentSelectedNoteProvider>(context);
    final rowSpacingProvider = Provider.of<ListOfSpacingForEachRow>(context);
    final globalRowSpacingProvider = Provider.of<RowSpacingProvider>(context);
    final selectRowsModeProvider = Provider.of<SelectRowsModeProvider>(context);

    // Adjust keyboard height based on read-only mode
    var keyboardHeight = widget.isReadOnly ? 0 : 312;
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
                  height: canvasHeight, // Adjust height as needed
                  color: const Color.fromARGB(
                      255, 199, 199, 199), // Background color
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    panEnabled: !_isDragging && !_isEditingDynamic,
                    scaleEnabled: !_isDragging && !_isEditingDynamic,
                    minScale: initialScale *
                        0.4, // Allows zooming out further if needed
                    maxScale: 3.0, // Allow zooming in up to 3x
                    boundaryMargin: const EdgeInsets.fromLTRB(
                        200, 200, 200, 9999), // Allow scrolling outside bounds
                    constrained: false,
                    child: Align(
                      // Ensures content is aligned properly
                      alignment: Alignment.topLeft,
                      child: Builder(
                        builder: (context) {
                          // Calculate dynamic height based on number of rows
                          const double sheetHeight = 40.0;
                          double rowSpacing =
                              globalRowSpacingProvider.rowSpacing;
                          double rowTotalHeight = rowSpacing + sheetHeight;

                          // Calculate total height based on rendered rows
                          final int startRow = widget.renderStartRow ?? 0;
                          final int endRow = widget.renderEndRow ??
                              (widget.sheetNoteRows.length - 1);
                          final int renderedRowCount = (endRow - startRow + 1)
                              .clamp(1, widget.sheetNoteRows.length);

                          // Adjust vertical offset for partial rendering
                          // For PDF export, we need to ensure the screenshot area includes the title/composer
                          // Increased padding to prevent cutoff at the top
                          final double adjustedVerticalOffset = (widget
                                          .renderStartRow !=
                                      null &&
                                  widget.renderEndRow != null &&
                                  widget.showTitleAndComposer)
                              ? 250.0 // Increased from 200 to match painter adjustment
                              : 150.0; // Increased from 50 to match painter adjustment

                          // Calculate A4-proportional height based on format configuration
                          final double a4ProportionalHeight =
                              widget.sheetFormat.config.a4ProportionalHeight;

                          // Calculate page margins - 50px header/footer for non-first pages
                          const double pageHeaderMargin = 50.0;
                          const double pageFooterMargin = 50.0;

                          // Calculate how many pages we need and add margins accordingly
                          final pageBreaks = PdfExporter.calculatePageBreaks(
                              widget.sheetNoteRows,
                              globalRowSpacingProvider.rowSpacing,
                              widget.sheetFormat);
                          double totalMarginsHeight = 0.0;

                          // Add footer margin for each page and header margin for non-first pages
                          for (int i = 0; i < pageBreaks.length; i++) {
                            totalMarginsHeight +=
                                pageFooterMargin; // Each page has footer margin
                            if (i > 0) {
                              totalMarginsHeight +=
                                  pageHeaderMargin; // Non-first pages have header margin
                            }
                          }

                          // Buffer space for capturing extended notation (slurs, high/low notes, dynamics)
                          // Only needed above first row and below last row during PDF export
                          const double rowVerticalBuffer = 120.0;
                          double additionalBufferHeight = 0.0;

                          if (widget.renderStartRow != null &&
                              widget.renderEndRow != null) {
                            // Add buffer above first row and below last row for PDF export
                            additionalBufferHeight =
                                rowVerticalBuffer * 2; // Top and bottom buffer
                          }

                          final double contentHeight = adjustedVerticalOffset +
                              (rowTotalHeight * renderedRowCount) +
                              additionalBufferHeight; // +totalMarginsHeight;

                          // Always use A4 proportional height, even for minimal content
                          final double totalHeight =
                              math.max(contentHeight, a4ProportionalHeight);

                          return SizedBox(
                            width: widget.musicSheetWidth, // Force width
                            height: totalHeight, // Dynamic height based on rows
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
                                      selectedRow:
                                          -1, // No selected row in screenshot
                                      selectedIndex:
                                          -1, // No selected index in screenshot
                                      showCursor:
                                          false, // Never show cursor in screenshot
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

                                // Replace the current sheet rows with the previous state
                                widget.sheetNoteRows.clear();
                                widget.sheetNoteRows.addAll(previousState);

                                // Update cursor position based on what still exists
                                int newRow = currentRow;
                                int newIndex = currentIndex;

                                // Check if the current row still exists
                                if (newRow >= widget.sheetNoteRows.length) {
                                  // Row doesn't exist, move to end of previous row
                                  newRow = widget.sheetNoteRows.length - 1;
                                  newIndex = widget
                                          .sheetNoteRows[newRow].chords.isEmpty
                                      ? 0
                                      : widget.sheetNoteRows[newRow].chords
                                              .length -
                                          1;
                                } else {
                                  // Row exists, check if the index still exists
                                  if (newIndex >=
                                      widget.sheetNoteRows[newRow].chords
                                          .length) {
                                    // Index doesn't exist, move to last note in the row
                                    newIndex = widget.sheetNoteRows[newRow]
                                            .chords.isEmpty
                                        ? 0
                                        : widget.sheetNoteRows[newRow].chords
                                                .length -
                                            1;
                                  }
                                }

                                // Update the cursor position
                                selectedNoteProvider
                                    .updateSelectedIndexAndInsertionPoint(
                                        newRow, newIndex);

                                // Clear any active highlighting
                                clearHighlighting();

                                // Trigger a rebuild
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

          // Floating Reset Button (Only Shows When Zoomed)
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
                  _buildNoteFlipButton('Flip Note', () {
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

                          note.isUpsideDown = note.isUpsideDown == false;
                        }
                      }
                    });
                  },
                      widget
                              .sheetNoteRows[selectedNoteProvider.selectedRow]
                              .chords[selectedNoteProvider.selectedIndex]
                              .isBeamed
                          ? widget
                              .sheetNoteRows[selectedNoteProvider.selectedRow]
                              .chords[selectedNoteProvider
                                  .getBeamedGroupIndices(
                                      selectedNoteProvider.selectedIndex,
                                      widget
                                          .sheetNoteRows[
                                              selectedNoteProvider.selectedRow]
                                          .chords)
                                  .first]
                              .isUpsideDown
                          : widget
                              .sheetNoteRows[selectedNoteProvider.selectedRow]
                              .chords[selectedNoteProvider.selectedIndex]
                              .isUpsideDown),
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
                            // Save state for undo
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
                            // Save state for undo
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
                    _buildStyledButton(_getDynamicCharacter(), () {
                      _removeDynamicCharacter();
                    }, true, false),
                  ],
                  if (_showHighlightButtons ||
                      _showDecrescendoRemoveButton &&
                          widget.keyboardType != KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    _buildStyledButton('\uE53F', () {
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
                  if (_showHighlightButtons ||
                      _showCrescendoRemoveButton &&
                          widget.keyboardType != KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    _buildStyledButton('\uE53E', () {
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
                  if (_showHighlightButtons ||
                      _showSlurRemoveButton &&
                          widget.keyboardType != KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    _buildStyledButton('SLUR', () {
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
                  if (_showHighlightButtons &&
                      _showBeamAddButton &&
                      widget.keyboardType != KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    _buildStyledButton('BEAM', () {
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
                    _buildStyledButton('BEAM', () {
                      _removeBeam();
                    }, false, false),
                  ],
                  if (_showTieButton &&
                      widget.keyboardType != KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    _buildStyledButton('TIE', () {
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

                          if (currentNote.pitch == nextNote.pitch) {
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
                    _buildStyledButton('TEMPO', () {
                      _showTempoPopup();
                    }, false, true),
                  ],
//CONTINUE HERE
                  //Guitar tab buttons
                  //P.M
                  if (_showHighlightButtons ||
                      _showMuteRemoveButton &&
                          widget.keyboardType == KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    _buildStyledButton('P.M.', () {
                      if (_showMuteRemoveButton) {
                        _removeMute();
                      } else {
                        if (_dragRow != null &&
                            _dragStart != null &&
                            _dragEnd != null) {
                          context
                              .read<CurrentSelectedNoteProvider>()
                              .decrescendoNotes(_dragRow!, _dragStart!,
                                  _dragEnd!, widget.sheetNoteRows, context);

                          _showMuteRemoveButton = true;
                          _showPinchHarmonicRemoveButton = false;
                          _showHarmonicRemoveButton = false;
                        }
                      }
                    }, true, !_showMuteRemoveButton)
                  ],
                  //P.H
                  if (_showHighlightButtons ||
                      _showCrescendoRemoveButton &&
                          widget.keyboardType == KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    _buildStyledButton('\uE53E', () {
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
                  //Ham.
                  if (_showHighlightButtons ||
                      _showCrescendoRemoveButton &&
                          widget.keyboardType == KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    _buildStyledButton('\uE53E', () {
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
                  //Vibrato
                  if (_showHighlightButtons ||
                      _showCrescendoRemoveButton &&
                          widget.keyboardType == KeyboardType.guitarTab) ...[
                    const SizedBox(height: 5),
                    _buildStyledButton('\uE53E', () {
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
                  //bend
                  //pre-bend
                  //bend-release
                  //pre-bend-release
                ],
              ),
            ),
        ]),
        PreferredSize(
          preferredSize: const Size.fromHeight(2.0), // Border thickness
          child: Container(
            color: Colors.black, // Border color
            height: 2.0, // Border height
          ),
        ),
      ],
    );
  }

  Widget _buildStyledButton(
      String label, VoidCallback onPressed, bool useBravura, bool isAdd) {
    return Row(
      children: [
        Text(
          isAdd ? '+' : 'x',
          style: TextStyle(
            color: isAdd ? Color.fromARGB(255, 63, 63, 63) : Colors.red,
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
            onPressed: onPressed,
            fillColor: Colors.white,
            constraints: const BoxConstraints.tightFor(width: 50, height: 35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
              side: BorderSide(
                  color: isAdd ? Colors.black : Colors.red, width: 1),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            child: useBravura
                ? Transform.translate(
                    offset: label == '\uE53F' || label == '\uE53E'
                        ? const Offset(1, 5)
                        : const Offset(2, 2),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize:
                            label == '\uE53F' || label == '\uE53E' ? 27 : 22,
                        fontFamily: 'Bravura',
                      ),
                    ))
                : Text(
                    label,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                        fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteFlipButton(
      String label, VoidCallback onPressed, bool? isUpsideDown) {
    return Material(
      color: Colors.transparent,
      elevation: 5,
      shadowColor: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      child: RawMaterialButton(
        onPressed: onPressed,
        fillColor: Colors.white,
        constraints: const BoxConstraints.tightFor(width: 110, height: 25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
          side: BorderSide(color: Colors.black, width: 1),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Transform.translate(
              offset: Offset(0, -5),
              child: Text(
                isUpsideDown == true ? '↓' : '↑',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 21,
                ),
              )),
          SizedBox(
            width: 3,
          ),
          Text(
            label,
            style: const TextStyle(
                fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ]),
      ),
    );
  }
}
