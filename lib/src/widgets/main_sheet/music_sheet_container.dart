import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/providers/list_of_spacing_for_each_row.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/drawing_helpers.dart';
import 'package:music_keyboard/src/utils/music_sheet_utils/note_width_calculator.dart';
import 'package:music_keyboard/src/widgets/main_sheet/music_sheet_painter.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vector_math;

class MusicSheetContainer extends StatefulWidget {
  final Size screenSize;
  final ScreenshotController screenshotController;
  final List<List<MusicalNote>> sheetNoteRows;
  final double musicSheetWidth;
  final double statusBarHeight;

  const MusicSheetContainer(
      {super.key,
      required this.screenSize,
      required this.screenshotController,
      required this.sheetNoteRows,
      required this.musicSheetWidth,
      required this.statusBarHeight});

  @override
  _MusicSheetContainerState createState() => _MusicSheetContainerState();
}

class _MusicSheetContainerState extends State<MusicSheetContainer> {
  late TransformationController _transformationController;
  late double initialScale;
  bool isZoomed = false;
  bool _showCursor = true;
  late Timer _cursorTimer;
  bool _showSlurAndBeamButtons = false;
  bool _showTieButton = false;
  int? _dragStart;
  int? _dragEnd;
  int? _dragRow;
  bool _isDragging = false;
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

      if (!highlightRect.inflate(20).contains(Offset(tapX, tapY))) {
        setState(() {
          _dragStart = null;
          _dragEnd = null;
          _dragRow = null;
          _showSlurAndBeamButtons = false;
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
    for (int i = 0; i < widget.sheetNoteRows[closestRowIndex].length; i++) {
      final note = widget.sheetNoteRows[closestRowIndex][i];
      if (note.isCrescendoStart || note.isDecrescendoStart) {
        final rect = getDynamicMarkingRect(
            i,
            note.isCrescendoStart
                ? note.crescendoEndIndex!
                : note.decrescendoEndIndex!,
            closestRowIndex);
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
        widget.sheetNoteRows[closestRowIndex], tapX, closestRowIndex);

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
      selectedNoteProvider.updateInsertionPoint(
          closestRowIndex, closestNoteIndex);
    }

    // Reset buttons
    setState(() {
      _showSlurAndBeamButtons = false;
      _showTieButton = false;
      _editingDynamicIndex = null;
      _editingDynamicRow = null;
    });

    // Check for TIE condition
    if (closestNoteIndex > 0 &&
        closestNoteIndex <= widget.sheetNoteRows[closestRowIndex].length) {
      MusicalNote currentNote =
          widget.sheetNoteRows[closestRowIndex][closestNoteIndex - 1];
      if (closestNoteIndex < widget.sheetNoteRows[closestRowIndex].length) {
        MusicalNote nextNote =
            widget.sheetNoteRows[closestRowIndex][closestNoteIndex];
        if (currentNote.pitch == nextNote.pitch) {
          setState(() {
            _showTieButton = true;
          });
        }
      }
    }
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
    int noteIndex = findNoteIndexAtPosition(
        widget.sheetNoteRows[closestRowIndex], tapX, closestRowIndex);

    if (noteIndex != -1) {
      setState(() {
        _dragRow = closestRowIndex;
        _dragStart = noteIndex;
        _dragEnd = noteIndex;
        _showSlurAndBeamButtons = true;
        _showTieButton = false; // Ensure TIE is hidden during range selection
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

      if (_isEditingDynamic) {
        int closestNoteIndex = findClosestNoteIndex(
            widget.sheetNoteRows[_editingDynamicRow!],
            tapX,
            _editingDynamicRow!);
        setState(() {
          final note =
              widget.sheetNoteRows[_editingDynamicRow!][_editingDynamicIndex!];
          if (note.isCrescendoStart) {
            note.crescendoEndIndex = closestNoteIndex.clamp(
                _editingDynamicIndex!,
                widget.sheetNoteRows[_editingDynamicRow!].length - 1);
          } else {
            note.decrescendoEndIndex = closestNoteIndex.clamp(
                _editingDynamicIndex!,
                widget.sheetNoteRows[_editingDynamicRow!].length - 1);
          }
        });
      } else if (_isDragging) {
        int closestNoteIndex = findClosestNoteIndex(
            widget.sheetNoteRows[_dragRow!], tapX, _dragRow!);
        setState(() {
          _dragEnd = closestNoteIndex.clamp(
              0, widget.sheetNoteRows[_dragRow!].length - 1);
        });
      }
      return;
    }

    // If no drag is active, but a selection is primed, accumulate the delta
    // and decide whether to start a drag or allow a scroll.
    if (_dragStart != null || _editingDynamicIndex != null) {
      _totalDragDelta += event.delta;

      // Use a threshold to avoid accidental drags from a tap.
      if (_totalDragDelta.distance < 10.0) return;

      // If movement is clearly horizontal, start a drag.
      if (_totalDragDelta.dx.abs() > _totalDragDelta.dy.abs() * 2.0) {
        setState(() {
          if (_dragStart != null) _isDragging = true;
          if (_editingDynamicIndex != null) _isEditingDynamic = true;
        });
      }
      // Otherwise (if vertical or diagonal), it's a scroll. Cancel the primed selection.
      else {
        setState(() {
          _dragStart = null;
          _dragEnd = null;
          _dragRow = null;
          _showSlurAndBeamButtons = false;
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
      });
    }
  }

  /// **Find the closest row based on the Y position**
  int findClosestRow(List<List<MusicalNote>> rows, double tapY) {
    const double sheetHeight = 40.0;
    const double topGap = 65.0;
    const double bottomGap = 65.0;
    const double rowTotalHeight =
        topGap + sheetHeight + bottomGap; // = 170px per row

    // Determine the closest row index
    int rowIndex =
        (tapY / rowTotalHeight).floor(); // Find which row region was tapped

    // Ensure the row index is within valid bounds
    return rowIndex.clamp(0, rows.length - 1);
  }

  int findClosestNoteIndex(
      List<MusicalNote> notes, double tapX, int selectedRow) {
    if (notes.isEmpty) return 0; // If row is empty, insert at start

    var rowSpacingList = context.read<ListOfSpacingForEachRow>().rowSpacingList;
    var currentRowSpacing = rowSpacingList[selectedRow];

    // Use the new calculateInsertionIndex function to determine the insertion point
    return calculateInsertionIndex(tapX, notes, currentRowSpacing);
  }

  Rect _calculateHighlightRect() {
    final rowNotes = widget.sheetNoteRows[_dragRow!];
    final rowSpacingList =
        context.read<ListOfSpacingForEachRow>().rowSpacingList;
    final currentRowSpacing = rowSpacingList[_dragRow!];

    final int start = _dragStart! < _dragEnd! ? _dragStart! : _dragEnd!;
    final int end = _dragStart! > _dragEnd! ? _dragStart! : _dragEnd!;

    final double startX =
        calculateXPositionForIndex(start, rowNotes, currentRowSpacing);
    final double endX =
        calculateXPositionForIndex(end, rowNotes, currentRowSpacing);

    double staffTop = _dragRow == 0
        ? 130.0 / 2
        : (_dragRow! * 130.0) + (_dragRow! * 40.0) + (130.0 / 2);
    double staffCenter = staffTop + 20;

    double min_y = double.infinity;
    double max_y = double.negativeInfinity;

    for (int i = start; i <= end; i++) {
      final note = rowNotes[i];
      double y = note.noteY;
      min_y = math.min(min_y, y - 15);
      max_y = math.max(max_y, y + 15);

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
            note.isConnected) {
          var notesGroup = getConnectedNotesGroup(i, rowNotes);
          var connectedNotesGroup = notesGroup.notesGroup;
          if (connectedNotesGroup.isNotEmpty) {
            var notesGroupYs = getConnectedNotesGroupHighestY(
                connectedNotesGroup, 10.0, staffCenter);
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

  int findNoteIndexAtPosition(
      List<MusicalNote> notes, double tapX, int selectedRow) {
    if (notes.isEmpty) return -1;

    var rowSpacingList = context.read<ListOfSpacingForEachRow>().rowSpacingList;
    var currentRowSpacing = rowSpacingList[selectedRow];
    double currentX = 60.0;

    for (int i = 0; i < notes.length; i++) {
      double noteWidth = getNoteWidth(notes[i]);
      if (notes[i].type != NoteType.clef) {
        noteWidth = currentRowSpacing.toDouble();
      }

      if (tapX >= currentX && tapX < currentX + noteWidth) {
        return i;
      }
      currentX += noteWidth;
    }

    return -1;
  }

  Rect getDynamicMarkingRect(int startIndex, int endIndex, int rowIndex) {
    final rowNotes = widget.sheetNoteRows[rowIndex];
    final rowSpacingList =
        context.read<ListOfSpacingForEachRow>().rowSpacingList;
    final currentRowSpacing = rowSpacingList[rowIndex];

    final double startX =
        calculateXPositionForIndex(startIndex, rowNotes, currentRowSpacing);
    final double endX =
        calculateXPositionForIndex(endIndex, rowNotes, currentRowSpacing);

    double lowestY = double.negativeInfinity;
    for (int i = startIndex; i <= endIndex; i++) {
      if (rowNotes[i].noteY > lowestY) {
        lowestY = rowNotes[i].noteY;
      }
    }

    double y = lowestY + 50;

    return Rect.fromLTRB(startX, y - 7.5, endX + 35, y + 40);
  }

  @override
  Widget build(BuildContext context) {
    final selectedNoteProvider =
        Provider.of<CurrentSelectedNoteProvider>(context);
    final rowSpacingProvider = Provider.of<ListOfSpacingForEachRow>(context);

    var keyboardHeight = 366;
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
                          const double topGap = 65.0;
                          const double bottomGap = 65.0;
                          const double rowTotalHeight = topGap +
                              sheetHeight +
                              bottomGap; // = 170px per row

                          // Calculate total height based on number of rows
                          final double totalHeight = math.max(
                              rowTotalHeight * widget.sheetNoteRows.length,
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
                                      widget.sheetNoteRows,
                                      -1, // No selected row in screenshot
                                      -1, // No selected index in screenshot
                                      false, // Never show cursor in screenshot
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
                                  widget.sheetNoteRows,
                                  selectedNoteProvider.selectedRow,
                                  selectedNoteProvider.selectedIndex,
                                  _showCursor,
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
          //if (isZoomed)
          //Reset zoom
          Positioned(
              top: 70,
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
                  child: const Icon(
                    Icons.zoom_out_map,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
              )),
          //Undo
          Positioned(
              top: 110,
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
              )),
          if (_showSlurAndBeamButtons)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStyledButton('SLUR', () {
                    if (_dragRow != null &&
                        _dragStart != null &&
                        _dragEnd != null) {
                      context.read<CurrentSelectedNoteProvider>().slurNotes(
                          _dragRow!,
                          _dragStart!,
                          _dragEnd!,
                          widget.sheetNoteRows);
                      setState(() {
                        _dragStart = null;
                        _dragEnd = null;
                        _dragRow = null;
                        _showSlurAndBeamButtons = false;
                      });
                    }
                  }),
                  const SizedBox(width: 5),
                  _buildStyledButton('BEAM', () {
                    if (_dragRow != null &&
                        _dragStart != null &&
                        _dragEnd != null) {
                      context.read<CurrentSelectedNoteProvider>().beamNotes(
                          _dragRow!,
                          _dragStart!,
                          _dragEnd!,
                          widget.sheetNoteRows);
                      setState(() {
                        _dragStart = null;
                        _dragEnd = null;
                        _dragRow = null;
                        _showSlurAndBeamButtons = false;
                      });
                    }
                  }),
                  const SizedBox(width: 10),
                  _buildStyledButton('>', () {
                    if (_dragRow != null &&
                        _dragStart != null &&
                        _dragEnd != null) {
                      context
                          .read<CurrentSelectedNoteProvider>()
                          .decrescendoNotes(_dragRow!, _dragStart!, _dragEnd!,
                              widget.sheetNoteRows);
                      setState(() {
                        _dragStart = null;
                        _dragEnd = null;
                        _dragRow = null;
                        _showSlurAndBeamButtons = false;
                      });
                    }
                  }),
                  const SizedBox(width: 10),
                  _buildStyledButton('<', () {
                    if (_dragRow != null &&
                        _dragStart != null &&
                        _dragEnd != null) {
                      context
                          .read<CurrentSelectedNoteProvider>()
                          .crescendoNotes(_dragRow!, _dragStart!, _dragEnd!,
                              widget.sheetNoteRows);
                      setState(() {
                        _dragStart = null;
                        _dragEnd = null;
                        _dragRow = null;
                        _showSlurAndBeamButtons = false;
                      });
                    }
                  }),
                ],
              ),
            ),
          if (_showTieButton)
            Positioned(
              bottom: 15,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStyledButton('TIE', () {
                    final selectedNoteProvider =
                        context.read<CurrentSelectedNoteProvider>();
                    final row = selectedNoteProvider.selectedRow;
                    final index = selectedNoteProvider.insertionIndex - 1;

                    if (index >= 0 &&
                        index + 1 < widget.sheetNoteRows[row].length) {
                      MusicalNote currentNote =
                          widget.sheetNoteRows[row][index];
                      MusicalNote nextNote =
                          widget.sheetNoteRows[row][index + 1];

                      if (currentNote.pitch == nextNote.pitch) {
                        setState(() {
                          currentNote.isTiedToNext = !currentNote.isTiedToNext;
                          _showTieButton = false;
                        });
                      }
                    }
                  }),
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

  Widget _buildStyledButton(String label, VoidCallback onPressed) {
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
        constraints: const BoxConstraints.tightFor(width: 50, height: 35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
          side: const BorderSide(color: Colors.black, width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
