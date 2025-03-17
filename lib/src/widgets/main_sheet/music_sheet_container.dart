import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/widgets/main_sheet/music_sheet_painter.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:async';
import 'package:vector_math/vector_math_64.dart' as vector_math;

class MusicSheetContainer extends StatefulWidget {
  final Size screenSize;
  final ScreenshotController screenshotController;
  final List<List<MusicalNote>> sheetNoteRows;
  final double musicSheetWidth;

  const MusicSheetContainer({
    super.key,
    required this.screenSize,
    required this.screenshotController,
    required this.sheetNoteRows,
    required this.musicSheetWidth,
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

  @override
  void initState() {
    super.initState();

    // Ensure entire music sheet width is visible on load
    initialScale = widget.screenSize.width / widget.musicSheetWidth;

    _transformationController = TransformationController();

    // Apply the initial scale
    _transformationController.value = Matrix4.identity()..scale(initialScale);

    // Listen for zoom changes
    _transformationController.addListener(_onZoomChanged);

    /*
    // Start blinking cursor without triggering full repaint
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _cursorVisible = !_cursorVisible;
        });
      }
    });*/

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
      _transformationController.value = Matrix4.identity()..scale(initialScale);
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
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localOffset = renderBox.globalToLocal(details.globalPosition);

    // 🎯 Get the TransformationController from InteractiveViewer
    final Matrix4 transformMatrix = _transformationController.value;

    // 🎯 Apply inverse transformation to adjust for zoom/pan
    final Matrix4 inverseMatrix = Matrix4.inverted(transformMatrix);
    final vector_math.Vector3 transformedPosition = inverseMatrix
        .transform3(vector_math.Vector3(localOffset.dx, localOffset.dy, 0));

    // ✅ Now, transformedPosition.x and transformedPosition.y are the correct values
    final double tapX = transformedPosition.x;
    final double tapY = transformedPosition.y;

    int closestRowIndex = findClosestRow(widget.sheetNoteRows, tapY);
    int closestNoteIndex =
        findClosestNoteIndex(widget.sheetNoteRows[closestRowIndex], tapX);

    if (context.read<CurrentSelectedNoteProvider>().isBeaming) {
      // ✅ Handle beaming mode
      context.read<CurrentSelectedNoteProvider>().handleBeamSelection(
          closestRowIndex, closestNoteIndex, widget.sheetNoteRows);
    } else if (context.read<CurrentSelectedNoteProvider>().isTying) {
      // ✅ Handle beaming mode
      context.read<CurrentSelectedNoteProvider>().handleTieSelection(
          closestRowIndex, closestNoteIndex, widget.sheetNoteRows);
    } else {
      // 🔹 Update provider with new insertion point
      context
          .read<CurrentSelectedNoteProvider>()
          .updateInsertionPoint(closestRowIndex, closestNoteIndex);
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

  int findClosestNoteIndex(List<MusicalNote> notes, double tapX) {
    if (notes.isEmpty) return 0; // If row is empty, insert at start

    // 🔹 Loop through the notes and calculate x position dynamically
    for (int i = 0; i < notes.length; i++) {
      double noteX = 26.0 * i + 10; // Calculate x position based on index

      if (noteX >= tapX) {
        return i; // Return the first index where noteX is greater
      }
    }

    return notes.length; // If no note is greater, return the last index
  }

  @override
  Widget build(BuildContext context) {
    final selectedNoteProvider =
        Provider.of<CurrentSelectedNoteProvider>(context);

    return Stack(children: [
      GestureDetector(
          onTapDown: _handleTap, // Handle user tap
          child: Container(
            width: widget.screenSize.width,
            height: widget.screenSize.height - 450, // Adjust height as needed
            color: Colors.white, // Background color
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale:
                  initialScale * 0.5, // Allows zooming out further if needed
              maxScale: 3.0, // Allow zooming in up to 3x
              boundaryMargin: EdgeInsets.fromLTRB(
                  20, 0, 20, 9999), // Allow scrolling outside bounds
              constrained: false,
              child: Align(
                // Ensures content is aligned properly
                alignment: Alignment.topLeft,
                child: SizedBox(
                    width: widget.musicSheetWidth, // Force width
                    height: 300, // Adjust height as needed
                    child: Stack(children: [
                      CustomPaint(
                        painter: MusicSheetPainter(
                          widget.sheetNoteRows,
                          selectedNoteProvider.selectedRow, // Pass selected row
                          selectedNoteProvider
                              .selectedIndex, // Pass selected index
                          _showCursor,
                        ),
                        size: Size(widget.musicSheetWidth,
                            300), // Ensure proper rendering
                      ),
                      Positioned.fill(
                        child: Screenshot(
                          controller: widget.screenshotController,
                          child: CustomPaint(
                            painter: MusicSheetPainter(
                              widget.sheetNoteRows,
                              selectedNoteProvider
                                  .selectedRow, // Pass selected row
                              selectedNoteProvider
                                  .selectedIndex, // Pass selected index
                              _showCursor,
                            ),
                            size: Size(widget.musicSheetWidth,
                                300), // Ensure proper rendering
                          ),
                        ),
                      )
                    ])),
              ),
            ),
          )),
      /*if (_cursorVisible)
        Positioned(
          left: 25.0 + (selectedNoteProvider.selectedIndex * 26) - 12,
          top: (selectedNoteProvider.selectedRow * 200) +
              85, // Adjust for staff lines
          child: Container(
            width: 2,
            height: 70,
            color: Colors.blue.withOpacity(0.8),
          ),
        ),*/
      // Floating Reset Button (Only Shows When Zoomed)
      if (isZoomed)
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            onPressed: _resetZoom,
            backgroundColor: const Color.fromARGB(255, 18, 17, 16),
            child: Icon(Icons.zoom_out_map, color: Colors.white),
          ),
        ),
    ]);
  }
}
