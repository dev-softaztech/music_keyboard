import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/models/keyboard_type.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/providers/list_of_spacing_for_each_row.dart';
import 'package:music_keyboard/src/providers/row_spacing_provider.dart';
import 'package:music_keyboard/src/providers/select_rows_mode_provider.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/drawing_helpers.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_width_calculator.dart';
import 'package:music_keyboard/src/utils/pdf_exporter.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' as vector_math;

/// Everything the gesture controller needs from `_MusicSheetContainerState`
/// that it doesn't own itself. Implemented by the State so the controller
/// stays independent of widget-tree/build concerns.
abstract class MusicSheetGestureHost {
  BuildContext get context;
  TransformationController get transformationController;
  List<SheetRows> get sheetNoteRows;
  SheetFormat get sheetFormat;
  KeyboardType get keyboardType;
  bool get isReadOnly;

  void hostSetState(VoidCallback fn);
  void zoomToNote(int rowIndex, int noteIndex);

  /// Tap landed outside the active highlight range - close it.
  void onHighlightDismissed();

  /// A note was newly selected via tap - reset/recompute button visibility.
  void onNoteSelected();

  /// A long-press started a fresh highlight range.
  void onHighlightStarted();

  /// A primed selection was cancelled because the pointer moved vertically.
  void onSelectionCancelled();

  /// Mirrors the (pre-existing, unguarded) beam-add-button refresh that runs
  /// on every pointer-move while dragging.
  void updateBeamAddButtonDuringDrag();
}

/// Owns the drag/highlight/dynamic-marking-edit gesture state for the music
/// sheet, and the five gesture handlers that mutate it.
class MusicSheetGestureController {
  MusicSheetGestureController({required this.host});

  final MusicSheetGestureHost host;

  int? dragStart;
  int? dragEnd;
  int? dragRow;
  bool isDragging = false;
  bool isDraggingLeftHandle = false;
  bool isDraggingRightHandle = false;
  int? fixedBoundary;
  int? editingDynamicIndex;
  int? editingDynamicRow;
  bool isEditingDynamic = false;
  Offset totalDragDelta = Offset.zero;

  static const double _lineSpacing = 10;

  void handleDoubleTap(TapDownDetails details) {
    // Skip if we're in highlight mode
    if (dragStart != null && dragEnd != null && dragRow != null) {
      return;
    }

    final RenderBox renderBox =
        host.context.findRenderObject() as RenderBox;
    final Offset localOffset = renderBox.globalToLocal(details.globalPosition);

    final Matrix4 transformMatrix = host.transformationController.value;
    final Matrix4 inverseMatrix = Matrix4.inverted(transformMatrix);
    final vector_math.Vector3 transformedPosition = inverseMatrix
        .transform3(vector_math.Vector3(localOffset.dx, localOffset.dy, 0));

    final double tapX = transformedPosition.x;
    final double tapY = transformedPosition.y;

    int closestRowIndex = findClosestRow(host.sheetNoteRows, tapY);

    // Check if we're tapping on a dynamic marking - don't zoom if so
    for (int i = 0;
        i < host.sheetNoteRows[closestRowIndex].chords.length;
        i++) {
      final note = host.sheetNoteRows[closestRowIndex].chords[i];
      if (note.isCrescendoStart || note.isDecrescendoStart) {
        var endIndex = note.isCrescendoStart
            ? (note.crescendoEndIndex! <
                    host.sheetNoteRows[closestRowIndex].chords.length - 1
                ? note.crescendoEndIndex!
                : host.sheetNoteRows[closestRowIndex].chords.length - 1)
            : note.decrescendoEndIndex! <
                    host.sheetNoteRows[closestRowIndex].chords.length - 1
                ? note.decrescendoEndIndex!
                : host.sheetNoteRows[closestRowIndex].chords.length - 1;

        final rect = getDynamicMarkingRect(i, endIndex, closestRowIndex);
        if (rect.contains(Offset(tapX, tapY))) {
          return; // Don't zoom if tapping on dynamic marking
        }
      }
    }

    int closestNoteIndex = findClosestNoteIndex(
        host.sheetNoteRows[closestRowIndex].chords, tapX, closestRowIndex);

    // Zoom to the double-tapped note
    host.zoomToNote(closestRowIndex, closestNoteIndex);
  }

  void handleTap(TapDownDetails details) {
    final RenderBox renderBox =
        host.context.findRenderObject() as RenderBox;
    final Offset localOffset = renderBox.globalToLocal(details.globalPosition);

    final Matrix4 transformMatrix = host.transformationController.value;
    final Matrix4 inverseMatrix = Matrix4.inverted(transformMatrix);
    final vector_math.Vector3 transformedPosition = inverseMatrix
        .transform3(vector_math.Vector3(localOffset.dx, localOffset.dy, 0));

    final double tapX = transformedPosition.x;
    final double tapY = transformedPosition.y;

    // Check if we're in Select Rows mode
    final selectRowsModeProvider = host.context.read<SelectRowsModeProvider>();
    if (selectRowsModeProvider.isSelectRowsMode) {
      // In select rows mode, only handle row tapping
      int tappedRow = findClosestRow(host.sheetNoteRows, tapY);
      host.hostSetState(() {
        selectRowsModeProvider.toggleRowSelection(tappedRow);
      });
      return;
    }

    // First check if tapping outside a selected dynamic marking to deselect it
    if (editingDynamicIndex != null && editingDynamicRow != null) {
      final note =
          host.sheetNoteRows[editingDynamicRow!].chords[editingDynamicIndex!];
      var endIndex = note.isCrescendoStart
          ? (note.crescendoEndIndex! <
                  host.sheetNoteRows[editingDynamicRow!].chords.length - 1
              ? note.crescendoEndIndex!
              : host.sheetNoteRows[editingDynamicRow!].chords.length - 1)
          : note.decrescendoEndIndex! <
                  host.sheetNoteRows[editingDynamicRow!].chords.length - 1
              ? note.decrescendoEndIndex!
              : host.sheetNoteRows[editingDynamicRow!].chords.length - 1;

      final rect = getDynamicMarkingRect(
          editingDynamicIndex!, endIndex, editingDynamicRow!);

      // If tapping outside the current selected marking, deselect it
      if (!rect.contains(Offset(tapX, tapY))) {
        host.hostSetState(() {
          editingDynamicIndex = null;
          editingDynamicRow = null;
          totalDragDelta = Offset.zero;
        });
        // Continue to check if tapping on another marking or note
      } else {
        // Tapping inside the same marking, keep it selected
        return;
      }
    }

    // Handle highlight range interactions
    if (dragStart != null && dragEnd != null && dragRow != null) {
      final Rect highlightRect = calculateHighlightRect();
      final Offset leftHandle =
          Offset(highlightRect.left, highlightRect.center.dx);
      final Offset rightHandle =
          Offset(highlightRect.right, highlightRect.center.dx);

      const double handleRadius =
          50.0; // Slightly larger than visual handle for easier clicking

      // Check if clicking near left handle
      if ((Offset(tapX, tapY) - leftHandle).distance <= handleRadius) {
        host.hostSetState(() {
          isDraggingLeftHandle = true;
          isDraggingRightHandle = false;
          fixedBoundary = dragEnd;
          totalDragDelta = Offset.zero;
        });
        return;
      }

      // Check if clicking near right handle
      if ((Offset(tapX, tapY) - rightHandle).distance <= handleRadius) {
        host.hostSetState(() {
          isDraggingLeftHandle = false;
          isDraggingRightHandle = true;
          fixedBoundary = dragStart;
          totalDragDelta = Offset.zero;
        });
        return;
      }

      if (!highlightRect.inflate(20).contains(Offset(tapX, tapY))) {
        host.hostSetState(() {
          dragStart = null;
          dragEnd = null;
          dragRow = null;
          isDraggingLeftHandle = false;
          isDraggingRightHandle = false;
          fixedBoundary = null;
          host.onHighlightDismissed();
        });
        return;
      }
      return; // Do nothing if tap is inside highlight
    }

    // IMPORTANT: Check ALL rows for dynamic markings BEFORE determining closest row
    // This prevents the issue where tapping on a marking selects the row below
    // because the marking is drawn below the staff
    for (int rowIndex = 0; rowIndex < host.sheetNoteRows.length; rowIndex++) {
      for (int i = 0; i < host.sheetNoteRows[rowIndex].chords.length; i++) {
        final note = host.sheetNoteRows[rowIndex].chords[i];
        if (note.isCrescendoStart || note.isDecrescendoStart) {
          var endIndex = note.isCrescendoStart
              ? (note.crescendoEndIndex! <
                      host.sheetNoteRows[rowIndex].chords.length - 1
                  ? note.crescendoEndIndex!
                  : host.sheetNoteRows[rowIndex].chords.length - 1)
              : note.decrescendoEndIndex! <
                      host.sheetNoteRows[rowIndex].chords.length - 1
                  ? note.decrescendoEndIndex!
                  : host.sheetNoteRows[rowIndex].chords.length - 1;

          final rect = getDynamicMarkingRect(i, endIndex, rowIndex);
          if (rect.contains(Offset(tapX, tapY))) {
            host.hostSetState(() {
              editingDynamicIndex = i;
              editingDynamicRow = rowIndex;
              totalDragDelta = Offset.zero;
            });
            return;
          }
        }
      }
    }

    // Only determine closest row AFTER checking for dynamic markings
    int closestRowIndex = findClosestRow(host.sheetNoteRows, tapY);

    int closestNoteIndex = findClosestNoteIndex(
        host.sheetNoteRows[closestRowIndex].chords, tapX, closestRowIndex);

    final selectedNoteProvider =
        host.context.read<CurrentSelectedNoteProvider>();

    selectedNoteProvider.updateSelectedIndexAndInsertionPoint(
        closestRowIndex, closestNoteIndex);

    host.hostSetState(() {
      editingDynamicIndex = null;
      editingDynamicRow = null;
    });

    host.onNoteSelected();
  }

  void handleLongPressStart(LongPressStartDetails details) {
    // Disable long press highlighting in read-only mode
    if (host.isReadOnly) {
      return;
    }

    final RenderBox renderBox =
        host.context.findRenderObject() as RenderBox;
    final Offset localOffset = renderBox.globalToLocal(details.globalPosition);

    final Matrix4 transformMatrix = host.transformationController.value;
    final Matrix4 inverseMatrix = Matrix4.inverted(transformMatrix);
    final vector_math.Vector3 transformedPosition = inverseMatrix
        .transform3(vector_math.Vector3(localOffset.dx, localOffset.dy, 0));

    final double tapX = transformedPosition.x;
    final double tapY = transformedPosition.y;

    int closestRowIndex = findClosestRow(host.sheetNoteRows, tapY);
    int noteIndex = findClosestNoteIndex(
        host.sheetNoteRows[closestRowIndex].chords, tapX, closestRowIndex);

    if (noteIndex != -1) {
      host.hostSetState(() {
        dragRow = closestRowIndex;
        dragStart = noteIndex;
        dragEnd = noteIndex;
        isDraggingLeftHandle = false;
        isDraggingRightHandle = false;
        fixedBoundary = null;
        totalDragDelta = Offset.zero;
        host.onHighlightStarted();
      });
    }
  }

  void handlePointerMove(PointerMoveEvent event) {
    // If a drag is already active, just update its position.
    if (isDragging || isEditingDynamic) {
      final RenderBox renderBox =
          host.context.findRenderObject() as RenderBox;
      final Offset localOffset = renderBox.globalToLocal(event.position);
      final Matrix4 transformMatrix = host.transformationController.value;
      final Matrix4 inverseMatrix = Matrix4.inverted(transformMatrix);
      final vector_math.Vector3 transformedPosition = inverseMatrix
          .transform3(vector_math.Vector3(localOffset.dx, localOffset.dy, 0));
      final double tapX = transformedPosition.x;

      if (isEditingDynamic && editingDynamicRow != null) {
        int closestNoteIndex = findClosestNoteIndex(
            host.sheetNoteRows[editingDynamicRow!].chords,
            tapX,
            editingDynamicRow!);
        host.hostSetState(() {
          final note = host
              .sheetNoteRows[editingDynamicRow!].chords[editingDynamicIndex!];
          if (note.isCrescendoStart) {
            note.crescendoEndIndex = closestNoteIndex.clamp(
                editingDynamicIndex!,
                host.sheetNoteRows[editingDynamicRow!].chords.length - 1);
          } else {
            note.decrescendoEndIndex = closestNoteIndex.clamp(
                editingDynamicIndex!,
                host.sheetNoteRows[editingDynamicRow!].chords.length - 1);
          }
        });
      } else if (isDragging && dragRow != null) {
        int closestNoteIndex = findClosestNoteIndex(
            host.sheetNoteRows[dragRow!].chords, tapX, dragRow!);

        host.hostSetState(() {
          // Handle different drag scenarios
          if (isDraggingLeftHandle) {
            // Dragging left handle - update dragStart, keep dragEnd fixed
            dragStart = closestNoteIndex.clamp(
                0, host.sheetNoteRows[dragRow!].chords.length - 1);
          } else if (isDraggingRightHandle) {
            // Dragging right handle - update dragEnd, keep dragStart fixed
            dragEnd = closestNoteIndex.clamp(
                0, host.sheetNoteRows[dragRow!].chords.length - 1);
          } else {
            // Default behavior for new selections
            dragEnd = closestNoteIndex.clamp(
                0, host.sheetNoteRows[dragRow!].chords.length - 1);
          }
        });
      }
      host.updateBeamAddButtonDuringDrag();
      return;
    }

    // If no drag is active, but a selection is primed, accumulate the delta
    // and decide whether to start a drag or allow a scroll.
    if (dragStart != null ||
        editingDynamicIndex != null ||
        isDraggingLeftHandle ||
        isDraggingRightHandle) {
      totalDragDelta += event.delta;

      // Use a threshold to avoid accidental drags from a tap.
      if (totalDragDelta.distance < 10.0) return;

      // If movement is clearly horizontal, start a drag.
      if (totalDragDelta.dx.abs() > totalDragDelta.dy.abs() * 2.0) {
        // Before starting the drag, check if we need to detect which handle is being dragged
        if (dragStart != null &&
            dragEnd != null &&
            dragRow != null &&
            !isDraggingLeftHandle &&
            !isDraggingRightHandle) {
          final RenderBox renderBox =
              host.context.findRenderObject() as RenderBox;
          final Offset localOffset = renderBox.globalToLocal(event.position);
          final Matrix4 transformMatrix = host.transformationController.value;
          final Matrix4 inverseMatrix = Matrix4.inverted(transformMatrix);
          final vector_math.Vector3 transformedPosition =
              inverseMatrix.transform3(
                  vector_math.Vector3(localOffset.dx, localOffset.dy, 0));
          final double currentX = transformedPosition.x;

          final Rect highlightRect = calculateHighlightRect();

          // Determine which handle to drag based on which half of the highlight area the user clicked
          double highlightCenter =
              (highlightRect.left + highlightRect.right) / 2;

          if (currentX < highlightCenter) {
            // Dragging from left half - drag left handle
            isDraggingLeftHandle = true;
            isDraggingRightHandle = false;
            fixedBoundary = dragEnd;
          } else {
            // Dragging from right half - drag right handle
            isDraggingLeftHandle = false;
            isDraggingRightHandle = true;
            fixedBoundary = dragStart;
          }
        }

        host.hostSetState(() {
          if (dragStart != null ||
              isDraggingLeftHandle ||
              isDraggingRightHandle) isDragging = true;
          if (editingDynamicIndex != null) isEditingDynamic = true;
        });
      }
      // Otherwise (if vertical or diagonal), it's a scroll. Cancel the primed selection.
      else {
        host.hostSetState(() {
          dragStart = null;
          dragEnd = null;
          dragRow = null;
          isDraggingLeftHandle = false;
          isDraggingRightHandle = false;
          fixedBoundary = null;
          editingDynamicIndex = null;
          editingDynamicRow = null;
          host.onSelectionCancelled();
        });
      }
    }
  }

  void handlePointerUp(PointerUpEvent event) {
    totalDragDelta = Offset.zero;
    // If we were dragging, stop. The selection itself (dragStart) remains
    // until the user taps a button or taps away.
    if (isDragging || isEditingDynamic) {
      host.hostSetState(() {
        isDragging = false;
        isEditingDynamic = false;
        isDraggingLeftHandle = false;
        isDraggingRightHandle = false;
        fixedBoundary = null;
      });
    }
  }

  /// **Find the closest row based on the Y position**
  int findClosestRow(List<SheetRows> rows, double tapY) {
    final globalRowSpacingProvider =
        Provider.of<RowSpacingProvider>(host.context, listen: false);
    double rowSpacing = globalRowSpacingProvider.rowSpacing;
    double sheetHeight = 40.0;
    double rowTotalHeight = rowSpacing + sheetHeight;
    const double verticalOffset = 250.0;

    // Calculate cumulative margin offsets for all rows (same logic as MusicSheetPainter)
    Map<int, double> cumulativeMarginOffsets = {};
    const double pageHeaderMargin = 50.0;
    const double pageFooterMargin = 50.0;

    final pageBreaks = PdfExporter.calculatePageBreaks(
        rows, rowSpacing, host.sheetFormat);
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

    var rowSpacingList =
        host.context.read<ListOfSpacingForEachRow>().rowSpacingList;
    var currentRowSpacing = rowSpacingList[selectedRow];

    return calculateInsertionIndex(tapX, notes, currentRowSpacing,
        startingX: host.keyboardType.startingNoteX);
  }

  double getStaffTop(int rowIndex) {
    final globalRowSpacingProvider =
        Provider.of<RowSpacingProvider>(host.context, listen: false);
    double rowSpacing = globalRowSpacingProvider.rowSpacing;
    const double sheetHeight = 40.0;
    const double verticalOffset = 150.0;
    return verticalOffset + (rowIndex * (rowSpacing + sheetHeight));
  }

  Rect calculateHighlightRect() {
    final rowNotes = host.sheetNoteRows[dragRow!].chords;
    final rowSpacingList =
        host.context.read<ListOfSpacingForEachRow>().rowSpacingList;
    final currentRowSpacing = rowSpacingList[dragRow!];

    final int start = dragStart! < dragEnd! ? dragStart! : dragEnd!;
    final int end = dragStart! > dragEnd! ? dragStart! : dragEnd!;

    final double startX =
        calculateXPositionForIndex(start, rowNotes, currentRowSpacing, true);
    final double endX =
        calculateXPositionForIndex(end, rowNotes, currentRowSpacing, false);

    double staffTop = getStaffTop(dragRow!);
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
        max_y = staffTop + (_lineSpacing * 4) + 25;
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
          var notesGroup = getBeamedNotesGroup(i, rowNotes);
          var connectedNotesGroup = notesGroup.notesGroup;
          if (connectedNotesGroup.isNotEmpty) {
            var notesGroupYs = getBeamedNotesGroupHighestY(
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
    final rowNotes = host.sheetNoteRows[rowIndex].chords;
    final rowSpacingList =
        host.context.read<ListOfSpacingForEachRow>().rowSpacingList;
    final currentRowSpacing = rowSpacingList[rowIndex];

    final double startX = calculateXPositionForIndex(
        startIndex, rowNotes, currentRowSpacing, true);
    final double endX = calculateXPositionForIndex(
        endIndex, rowNotes, currentRowSpacing, false);

    double lowestY = double.negativeInfinity;
    bool hasUpsideDownNoteOnStaff = false;
    double staffTop = getStaffTop(rowIndex);

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
}
