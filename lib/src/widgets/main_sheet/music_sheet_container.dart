import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/providers/list_of_spacing_for_each_row.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/drawing_helpers.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_width_calculator.dart';
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
  final double musicSheetWidth;
  final double statusBarHeight;
  final String title;
  final String composer;
  final Function(VoidCallback)? onClearHighlightingCallback;

  const MusicSheetContainer({
    super.key,
    required this.screenSize,
    required this.screenshotController,
    required this.sheetNoteRows,
    required this.musicSheetWidth,
    required this.statusBarHeight,
    required this.title,
    required this.composer,
    this.onClearHighlightingCallback,
  });

  @override
  _MusicSheetContainerState createState() => _MusicSheetContainerState();
}

class _MusicSheetContainerState extends State<MusicSheetContainer> {
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
  bool _showBeamRotationButton = false;
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
      _showBeamRotationButton = false;
      _editingDynamicIndex = null;
      _editingDynamicRow = null;
      _isEditingDynamic = false;
      _isDragging = false;
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
    setState(() {
      final double scaleFactor =
          initialScale * 0.9; // Using 0.9 as the zoom factor

      // Calculate the translation needed to center the content
      final double translationX =
          (widget.screenSize.width - (widget.musicSheetWidth * scaleFactor)) /
              2;

      // Create a matrix with scale first
      final Matrix4 scaleMatrix = Matrix4.identity()..scale(scaleFactor);

      // Then create a matrix with translation
      final Matrix4 translationMatrix = Matrix4.identity()
        ..setTranslationRaw(translationX, 50.0, 0);

      // Combine the matrices: first scale, then translate
      _transformationController.value = translationMatrix * scaleMatrix;
      isZoomed = false;
    });
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onZoomChanged);
    _transformationController.dispose();
    _cursorTimer.cancel();
    super.dispose();
  }

//continue here
//next I need to add code for skipping space notes when calculating size of slurs & cresendo
  void _handleTap(TapDownDetails details) {
    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final Offset localOffset =
          renderBox.globalToLocal(details.globalPosition);

      final Matrix4 transformMatrix = _transformationController.value;
      final Matrix4 inverseMatrix = Matrix4.inverted(transformMatrix);
      final vector_math.Vector3 transformedPosition = inverseMatrix
          .transform3(vector_math.Vector3(localOffset.dx, localOffset.dy, 0));

      final double tapX = transformedPosition.x;
      final double tapY = transformedPosition.y;

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

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localOffset = renderBox.globalToLocal(details.globalPosition);

    //  Get the TransformationController from InteractiveViewer
    final Matrix4 transformMatrix = _transformationController.value;

    //  Apply inverse transformation to adjust for zoom/pan
    final Matrix4 inverseMatrix = Matrix4.inverted(transformMatrix);
    final vector_math.Vector3 transformedPosition = inverseMatrix
        .transform3(vector_math.Vector3(localOffset.dx, localOffset.dy, 0));

    //  Now, transformedPosition.x and transformedPosition.y are the correct values
    final double tapX = transformedPosition.x;
    final double tapY = transformedPosition.y;

    int closestRowIndex = findClosestRow(widget.sheetNoteRows, tapY);

    // Check if a dynamic marking was tapped
    for (int i = 0;
        i < widget.sheetNoteRows[closestRowIndex].notes.length;
        i++) {
      final note = widget.sheetNoteRows[closestRowIndex].notes[i];
      if (note.isCrescendoStart || note.isDecrescendoStart) {
        var endIndex = note.isCrescendoStart
            ? (note.crescendoEndIndex! <
                    widget.sheetNoteRows[closestRowIndex].notes.length - 1
                ? note.crescendoEndIndex!
                : widget.sheetNoteRows[closestRowIndex].notes.length - 1)
            : note.decrescendoEndIndex! <
                    widget.sheetNoteRows[closestRowIndex].notes.length - 1
                ? note.decrescendoEndIndex!
                : widget.sheetNoteRows[closestRowIndex].notes.length - 1;

        final rect = getDynamicMarkingRect(i, endIndex, closestRowIndex);
        if (rect.contains(Offset(tapX, tapY))) {
          setState(() {
            _editingDynamicIndex = i;
            _editingDynamicRow = closestRowIndex;
            _totalDragDelta = Offset.zero;
          });
          return;
        }
      }
    }

    int closestNoteIndex = findClosestNoteIndex(
        widget.sheetNoteRows[closestRowIndex].notes, tapX, closestRowIndex);

    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    if (selectedNoteProvider.isBeaming) {
      //  Handle beaming mode
      selectedNoteProvider.handleBeamSelection(
          closestRowIndex, closestNoteIndex, widget.sheetNoteRows);
    } else if (selectedNoteProvider.isSlurring) {
      //  Handle beaming mode
      selectedNoteProvider.handleSlurSelection(
          closestRowIndex, closestNoteIndex, widget.sheetNoteRows);
    } else {
      // 🔹 Update provider with new insertion point
      selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
          closestRowIndex, closestNoteIndex);
    }

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
    });

    // Check for TIE condition
    if (closestNoteIndex > 0 &&
        closestNoteIndex <=
            widget.sheetNoteRows[closestRowIndex].notes.length) {
      MusicalNote currentNote =
          widget.sheetNoteRows[closestRowIndex].notes[closestNoteIndex - 1];
      if (closestNoteIndex <
          widget.sheetNoteRows[closestRowIndex].notes.length) {
        MusicalNote nextNote =
            widget.sheetNoteRows[closestRowIndex].notes[closestNoteIndex];
        if (currentNote.pitch == nextNote.pitch) {
          setState(() {
            _showTieButton = true;
          });
        }
      }
    }

    var showDynamicRemoveButton = _shouldShowDynamicRemove();
    var showBeamRemoveButton = _shouldShowBeamRemove();
    var showBeamAddButton = _shouldShowBeamAdd();
    var showSlurRemoveButton = _shouldShowSlurRemove();
    var showDecrescendoRemoveButton = _shouldShowDecrescendoRemove();
    var showCrescendoRemoveButton = _shouldShowCrescendoRemove();
    var showTieRemoveState = _shouldShowTieRemove();
    var showTempoEditButton = _shouldShowTempoEdit();
    var showBeamRotationButton = _shouldShowBeamRotation();

    setState(() {
      _showDynamicRemoveButton = showDynamicRemoveButton;
      _showBeamAddButton = showBeamAddButton;
      _showBeamRemoveButton = showBeamRemoveButton;
      _showSlurRemoveButton = showSlurRemoveButton;
      _showDecrescendoRemoveButton = showDecrescendoRemoveButton;
      _showCrescendoRemoveButton = showCrescendoRemoveButton;
      _showTieRemoveState = showTieRemoveState;
      _showTempoEditButton = showTempoEditButton;
      _showBeamRotationButton = showBeamRotationButton;
    });
  }

  void _handleLongPressStart(LongPressStartDetails details) {
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
        widget.sheetNoteRows[closestRowIndex].notes, tapX, closestRowIndex);

    if (noteIndex != -1) {
      setState(() {
        _dragRow = closestRowIndex;
        _dragStart = noteIndex;
        _dragEnd = noteIndex;
        _isDraggingLeftHandle = false;
        _isDraggingRightHandle = false;
        _fixedBoundary = null;
        _showHighlightButtons = true;
        //_showBeamAddButton = true;
        _showTieButton = false;
        _showDynamicRemoveButton = false;
        _totalDragDelta = Offset.zero;
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
            widget.sheetNoteRows[_editingDynamicRow!].notes,
            tapX,
            _editingDynamicRow!);
        setState(() {
          final note = widget
              .sheetNoteRows[_editingDynamicRow!].notes[_editingDynamicIndex!];
          if (note.isCrescendoStart) {
            note.crescendoEndIndex = closestNoteIndex.clamp(
                _editingDynamicIndex!,
                widget.sheetNoteRows[_editingDynamicRow!].notes.length - 1);
          } else {
            note.decrescendoEndIndex = closestNoteIndex.clamp(
                _editingDynamicIndex!,
                widget.sheetNoteRows[_editingDynamicRow!].notes.length - 1);
          }
        });
      } else if (_isDragging && _dragRow != null) {
        int closestNoteIndex = findClosestNoteIndex(
            widget.sheetNoteRows[_dragRow!].notes, tapX, _dragRow!);

        setState(() {
          // Handle different drag scenarios
          if (_isDraggingLeftHandle) {
            // Dragging left handle - update _dragStart, keep _dragEnd fixed
            _dragStart = closestNoteIndex.clamp(
                0, widget.sheetNoteRows[_dragRow!].notes.length - 1);
          } else if (_isDraggingRightHandle) {
            // Dragging right handle - update _dragEnd, keep _dragStart fixed
            _dragEnd = closestNoteIndex.clamp(
                0, widget.sheetNoteRows[_dragRow!].notes.length - 1);
          } else {
            // Default behavior for new selections
            _dragEnd = closestNoteIndex.clamp(
                0, widget.sheetNoteRows[_dragRow!].notes.length - 1);
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
          final Offset leftHandle =
              Offset(highlightRect.left, highlightRect.center.dy);
          final Offset rightHandle =
              Offset(highlightRect.right, highlightRect.center.dy);

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
    const double rowSpacing = 160.0;
    const double sheetHeight = 40.0;
    const double rowTotalHeight = rowSpacing + sheetHeight;
    const double verticalOffset = 250.0;
    const double startY = verticalOffset - (rowSpacing / 2);

    int rowIndex = ((tapY - startY) / rowTotalHeight).floor();

    // Ensure the row index is within valid bounds
    return rowIndex.clamp(0, rows.length - 1);
  }

  int findClosestNoteIndex(
      List<MusicalNote> notes, double tapX, int selectedRow) {
    if (notes.isEmpty) return 0;

    var rowSpacingList = context.read<ListOfSpacingForEachRow>().rowSpacingList;
    var currentRowSpacing = rowSpacingList[selectedRow];

    return calculateInsertionIndex(tapX, notes, currentRowSpacing);
  }

  double _getStaffTop(int rowIndex) {
    const double rowSpacing = 160.0;
    const double sheetHeight = 40.0;
    const double verticalOffset = 150.0;
    return verticalOffset + (rowIndex * (rowSpacing + sheetHeight));
  }

  Rect _calculateHighlightRect() {
    final rowNotes = widget.sheetNoteRows[_dragRow!].notes;
    final rowSpacingList =
        context.read<ListOfSpacingForEachRow>().rowSpacingList;
    final currentRowSpacing = rowSpacingList[_dragRow!];

    final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
    final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

    final double startX =
        calculateXPositionForIndex(start, rowNotes, currentRowSpacing);
    final double endX =
        calculateXPositionForIndex(end, rowNotes, currentRowSpacing);

    double staffTop = _getStaffTop(_dragRow!);
    double staffCenter = staffTop + 20;

    double min_y = double.infinity;
    double max_y = double.negativeInfinity;

    for (int i = start; i <= end; i++) {
      final note = rowNotes[i];
      double y = note.noteY;
      min_y = math.min(min_y, y - 15);
      max_y = math.max(max_y, y + 15);

      if (note.type == NoteType.clef) {
        min_y = min_y + 100;
        max_y = max_y + 125;
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
    final rowNotes = widget.sheetNoteRows[rowIndex].notes;
    final rowSpacingList =
        context.read<ListOfSpacingForEachRow>().rowSpacingList;
    final currentRowSpacing = rowSpacingList[rowIndex];

    final double startX =
        calculateXPositionForIndex(startIndex, rowNotes, currentRowSpacing);
    final double endX =
        calculateXPositionForIndex(endIndex, rowNotes, currentRowSpacing);

    double lowestY = double.negativeInfinity;
    bool hasUpsideDownNoteOnStaff = false;
    double staffTop = _getStaffTop(rowIndex);

    for (int i = startIndex; i <= endIndex; i++) {
      if (rowNotes[i].noteY > lowestY) {
        lowestY = rowNotes[i].noteY;
      }
      if (rowNotes[i].isUpsideDown && rowNotes[i].noteY >= staffTop) {
        hasUpsideDownNoteOnStaff = true;
      }
    }

    double staffBottomLineY = staffTop + 40; // 4 lines * 10 spacing
    double minDynamicY = staffBottomLineY + 20;
    double y = math.max(lowestY + 50, minDynamicY);

    if (hasUpsideDownNoteOnStaff) {
      y += 20;
    }

    return Rect.fromLTRB(startX, y - 7.5, endX + 70, y + 40);
  }

  // Helper methods for remove condition detection
  bool _shouldShowTieRemove() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    // Check if there's no active highlighted notes AND current selected note has isTiedToNext = true
    if (_dragStart == null && _dragEnd == null) {
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0 && index < widget.sheetNoteRows[row].notes.length) {
        return widget.sheetNoteRows[row].notes[index].isTiedToNext;
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

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].notes.length; i++) {
        final note = widget.sheetNoteRows[_dragRow!].notes[i];
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
        for (int i = 0; i < widget.sheetNoteRows[row].notes.length; i++) {
          final note = widget.sheetNoteRows[row].notes[i];
          if (note.isDecrescendoStart && note.decrescendoEndIndex != null) {
            if (i < index && note.decrescendoEndIndex! >= index) {
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

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].notes.length; i++) {
        final note = widget.sheetNoteRows[_dragRow!].notes[i];
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
        for (int i = 0; i < widget.sheetNoteRows[row].notes.length; i++) {
          final note = widget.sheetNoteRows[row].notes[i];
          if (note.isCrescendoStart && note.crescendoEndIndex != null) {
            if (i < index && note.crescendoEndIndex! >= index) {
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

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].notes.length; i++) {
        final note = widget.sheetNoteRows[_dragRow!].notes[i];
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
        for (int i = 0; i < widget.sheetNoteRows[row].notes.length; i++) {
          final note = widget.sheetNoteRows[row].notes[i];
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
        if (!widget.sheetNoteRows[_dragRow!].notes[i].isBeamed) {
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
        if (widget.sheetNoteRows[_dragRow!].notes[i].isBeamed) {
          return true;
        }
      }
    } else {
      final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0 && index < widget.sheetNoteRows[row].notes.length) {
        return widget.sheetNoteRows[row].notes[index].isBeamed;
      }
    }
    return false;
  }

  bool _shouldShowTempoEdit() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    final row = selectedNoteProvider.selectedRow;
    final index = selectedNoteProvider.selectedIndex;

    if (index > 0 &&
        index < widget.sheetNoteRows[row].notes.length &&
        widget.sheetNoteRows[row].notes[index].type == NoteType.bar) {
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

      if (index >= 0 && index < widget.sheetNoteRows[row].notes.length) {
        final dynamicChar =
            widget.sheetNoteRows[row].notes[index].dynamicCharacter;
        return dynamicChar.isNotEmpty;
      }
    }
    return false;
  }

  bool _shouldShowBeamRotation() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();

    // Check if there's no active highlighted notes AND current selected note is beamed
    if (_dragStart == null && _dragEnd == null) {
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0 && index < widget.sheetNoteRows[row].notes.length) {
        final selectedNote = widget.sheetNoteRows[row].notes[index];
        return selectedNote.isBeamed;
      }
    }
    return false;
  }

  String _getDynamicCharacter() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    final row = selectedNoteProvider.selectedRow;
    final index = selectedNoteProvider.selectedIndex;

    if (index >= 0 && index < widget.sheetNoteRows[row].notes.length) {
      return widget.sheetNoteRows[row].notes[index].dynamicCharacter;
    }
    return "";
  }

  // Remove action methods
  void _removeTie() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    //selectedNoteProvider.saveState(widget.sheetNoteRows);

    final row = selectedNoteProvider.selectedRow;
    final index = selectedNoteProvider.selectedIndex;

    if (index >= 0 && index < widget.sheetNoteRows[row].notes.length) {
      setState(() {
        widget.sheetNoteRows[row].notes[index].isTiedToNext = false;
      });
      _showTieRemoveState = false;
    }
  }

  void _removeDecrescendo() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    //selectedNoteProvider.saveState(widget.sheetNoteRows);

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Remove decrescendos in highlighted range
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].notes.length; i++) {
        final note = widget.sheetNoteRows[_dragRow!].notes[i];
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
        for (int i = 0; i < widget.sheetNoteRows[row].notes.length; i++) {
          final note = widget.sheetNoteRows[row].notes[i];
          if (note.isDecrescendoStart && note.decrescendoEndIndex != null) {
            if (i < index && note.decrescendoEndIndex! >= index) {
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
    //selectedNoteProvider.saveState(widget.sheetNoteRows);

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Remove crescendos in highlighted range
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].notes.length; i++) {
        final note = widget.sheetNoteRows[_dragRow!].notes[i];
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
        for (int i = 0; i < widget.sheetNoteRows[row].notes.length; i++) {
          final note = widget.sheetNoteRows[row].notes[i];
          if (note.isCrescendoStart && note.crescendoEndIndex != null) {
            if (i < index && note.crescendoEndIndex! >= index) {
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
    //selectedNoteProvider.saveState(widget.sheetNoteRows);

    if (_dragStart != null && _dragEnd != null && _dragRow != null) {
      // Remove slurs in highlighted range
      final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
      final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

      for (int i = 0; i < widget.sheetNoteRows[_dragRow!].notes.length; i++) {
        final note = widget.sheetNoteRows[_dragRow!].notes[i];
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
        for (int i = 0; i < widget.sheetNoteRows[row].notes.length; i++) {
          final note = widget.sheetNoteRows[row].notes[i];
          if (note.slurEndIndex != null) {
            if (i < index && note.slurEndIndex! >= index) {
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
        widget.sheetNoteRows[_dragRow!].notes[i].isBeamed = false;
      }
    } else {
      final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
      final row = selectedNoteProvider.selectedRow;
      final index = selectedNoteProvider.selectedIndex;

      if (index >= 0 && index < widget.sheetNoteRows[row].notes.length) {
        widget.sheetNoteRows[row].notes[index].isBeamed = false;
      }
    }

    _showBeamRemoveButton = false;
    _showBeamAddButton = true;
  }

  void _removeDynamicCharacter() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    //selectedNoteProvider.saveState(widget.sheetNoteRows);

    final row = selectedNoteProvider.selectedRow;
    final index = selectedNoteProvider.selectedIndex;

    if (index >= 0 && index < widget.sheetNoteRows[row].notes.length) {
      setState(() {
        widget.sheetNoteRows[row].notes[index].dynamicCharacter = "";
      });
    }

    _showDynamicRemoveButton = false;
  }

  void _showTempoPopup() {
    final selectedNoteProvider = context.read<CurrentSelectedNoteProvider>();
    final row = selectedNoteProvider.selectedRow;
    final index = selectedNoteProvider.selectedIndex;

    if (index >= 0 && index < widget.sheetNoteRows[row].notes.length) {
      final barNote = widget.sheetNoteRows[row].notes[index];

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

  @override
  Widget build(BuildContext context) {
    final selectedNoteProvider =
        Provider.of<CurrentSelectedNoteProvider>(context);
    final rowSpacingProvider = Provider.of<ListOfSpacingForEachRow>(context);

    var keyboardHeight = 333;
    var canvasHeight = widget.screenSize.height -
        AppBar().preferredSize.height -
        keyboardHeight -
        widget.statusBarHeight;

    return Column(
      children: [
        Stack(children: [
          GestureDetector(
              onTapDown: _handleTap,
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
                          const double rowSpacing = 160.0;
                          const double rowTotalHeight =
                              rowSpacing + sheetHeight;
                          const double verticalOffset = 150.0;

                          // Calculate total height based on number of rows
                          final double totalHeight = math.max(
                              verticalOffset +
                                  (rowTotalHeight *
                                      widget.sheetNoteRows.length),
                              1000.0 // Minimum height of 300px
                              );

                          return SizedBox(
                            width: widget.musicSheetWidth, // Force width
                            height: totalHeight, // Dynamic height based on rows
                            child: Stack(children: [
                              Positioned.fill(
                                child: Screenshot(
                                  controller: widget.screenshotController,
                                  child: CustomPaint(
                                    painter: MusicSheetPainter(
                                      title: widget.title,
                                      composer: widget.composer,
                                      sheetNoteRows: widget.sheetNoteRows,
                                      selectedRow:
                                          -1, // No selected row in screenshot
                                      selectedIndex:
                                          -1, // No selected index in screenshot
                                      showCursor:
                                          false, // Never show cursor in screenshot
                                      rowSpacingList:
                                          rowSpacingProvider.rowSpacingList,
                                      editingDynamicIndex: _editingDynamicIndex,
                                      editingDynamicRow: _editingDynamicRow,
                                    ),
                                    size: Size(widget.musicSheetWidth,
                                        totalHeight), // Dynamic height
                                  ),
                                ),
                              ),
                              CustomPaint(
                                painter: MusicSheetPainter(
                                  title: widget.title,
                                  composer: widget.composer,
                                  sheetNoteRows: widget.sheetNoteRows,
                                  selectedRow: selectedNoteProvider.selectedRow,
                                  selectedIndex:
                                      selectedNoteProvider.selectedIndex,
                                  showCursor: _showCursor,
                                  rowSpacingList:
                                      rowSpacingProvider.rowSpacingList,
                                  selectionStart: _dragStart,
                                  selectionEnd: _dragEnd,
                                  selectionRow: _dragRow,
                                  editingDynamicIndex: _editingDynamicIndex,
                                  editingDynamicRow: _editingDynamicRow,
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

          // Floating Reset Button (Only Shows When Zoomed)
          if (isZoomed)
            //Reset zoom
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
          /*//Undo
          Positioned(
              top: 90,
              right: 0,
              child: Material(
                color: Colors.transparent,
                elevation: 5,
                shadowColor: Colors.black.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                child: RawMaterialButton(
                  onPressed: () {
                    context
                        .read<CurrentSelectedNoteProvider>()
                        .undo(widget.sheetNoteRows);
                  },
                  fillColor: Colors.white,
                  constraints:
                      const BoxConstraints.tightFor(width: 35, height: 35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                    side: const BorderSide(color: Colors.black, width: 1),
                  ),
                  child: const Icon(
                    Icons.undo,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
              )),*/
          Positioned(
              top: 10,
              left: 0,
              right: 0,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (_showBeamRotationButton &&
                    selectedNoteProvider
                        .getBeamedGroupIndices(
                            selectedNoteProvider.selectedIndex,
                            widget
                                .sheetNoteRows[selectedNoteProvider.selectedRow]
                                .notes)
                        .isNotEmpty) ...[
                  _buildBeamCycleButton('Beam Rotate', () {
                    setState(() {
                      context
                          .read<CurrentSelectedNoteProvider>()
                          .switchBeamRotation(widget.sheetNoteRows);
                    });
                  },
                      widget
                          .sheetNoteRows[selectedNoteProvider.selectedRow]
                          .notes[selectedNoteProvider
                              .getBeamedGroupIndices(
                                  selectedNoteProvider.selectedIndex,
                                  widget
                                      .sheetNoteRows[
                                          selectedNoteProvider.selectedRow]
                                      .notes)
                              .first]
                          .beamDirectionLocked),
                ],
              ])),
          Positioned(
            bottom: 5,
            right: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_showDynamicRemoveButton) ...[
                  const SizedBox(height: 5),
                  _buildStyledButton(_getDynamicCharacter(), () {
                    _removeDynamicCharacter();
                  }, true, false),
                ],
                if (_showHighlightButtons || _showDecrescendoRemoveButton) ...[
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
                            .decrescendoNotes(_dragRow!, _dragStart!, _dragEnd!,
                                widget.sheetNoteRows);

                        _showDecrescendoRemoveButton = true;
                      }
                    }
                  }, true, !_showDecrescendoRemoveButton)
                ],
                if (_showHighlightButtons || _showCrescendoRemoveButton) ...[
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
                                widget.sheetNoteRows);

                        _showCrescendoRemoveButton = true;
                      }
                    }
                  }, true, !_showCrescendoRemoveButton)
                ],
                if (_showHighlightButtons || _showSlurRemoveButton) ...[
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
                            widget.sheetNoteRows);
                        _showSlurRemoveButton = true;
                      }
                    }
                  }, false, !_showSlurRemoveButton)
                ],
                if (_showHighlightButtons && _showBeamAddButton) ...[
                  const SizedBox(height: 5),
                  _buildStyledButton('BEAM', () {
                    if (_dragRow != null &&
                        _dragStart != null &&
                        _dragEnd != null) {
                      context.read<CurrentSelectedNoteProvider>().beamNotes(
                          _dragRow!,
                          _dragStart!,
                          _dragEnd!,
                          widget.sheetNoteRows);

                      _showBeamRemoveButton = true;
                      _showBeamAddButton = false;
                    }
                  }, false, true)
                ],
                if (_showBeamRemoveButton) ...[
                  const SizedBox(height: 5),
                  _buildStyledButton('BEAM', () {
                    _removeBeam();
                  }, false, false),
                ],
                if (_showTieButton) ...[
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
                          index + 1 < widget.sheetNoteRows[row].notes.length) {
                        MusicalNote currentNote =
                            widget.sheetNoteRows[row].notes[index];
                        MusicalNote nextNote =
                            widget.sheetNoteRows[row].notes[index + 1];

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

  Widget _buildBeamCycleButton(
      String label, VoidCallback onPressed, bool? beamCycleLock) {
    bool lockEnabled = beamCycleLock != null;
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
          side: BorderSide(
              color: lockEnabled ? Colors.red : Colors.black, width: 1),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Transform.translate(
              offset: beamCycleLock == null ? Offset(0, -2) : Offset(0, -5),
              child: Text(
                beamCycleLock == null
                    ? '-'
                    : beamCycleLock == true
                        ? '↓'
                        : '↑',
                style: TextStyle(
                  color: lockEnabled ? Colors.red : Colors.black,
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
