import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/providers/list_of_spacing_for_each_row.dart';
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
  bool showMenu = false;

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
      ..setTranslationRaw(translationX, 0, 0);

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
        ..setTranslationRaw(translationX, 0, 0);

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

  List<Widget> _buildCircularMenu() {
    const double radius = 50.0;
    const double startAngle = (math.pi / 2); // Start from the top
    const double angleIncrement = math.pi / 4; // 45 degrees between items

    final selectedNoteProvider =
        Provider.of<CurrentSelectedNoteProvider>(context);
    MusicalNote selectedNote = MusicalNote(
        pitch: "",
        octave: 0,
        type: NoteType.clef,
        isConnected: false,
        unicodeCharacter: "");

    if (widget.sheetNoteRows[selectedNoteProvider.selectedRow].isNotEmpty) {
      selectedNote = widget.sheetNoteRows[selectedNoteProvider.selectedRow]
          [selectedNoteProvider.selectedIndex];
    }

    final List<Map<String, dynamic>> menuItems = [
      {'label': 'ff', 'type': 'dynamics'},
      {'label': '4/4', 'type': '__'},
      {'label': 'BEAM', 'type': 'beam'},
      {'label': 'SLUR', 'type': 'slur'},
      {'label': 'TIE', 'type': 'tie'},
    ];

    return List.generate(menuItems.length, (index) {
      final double angle = startAngle + (index * angleIncrement);
      final double x = radius * math.cos(angle);
      final double y = radius * math.sin(angle);

      return Positioned(
        bottom: 50 + y,
        right: 4 - x,
        child: AnimatedOpacity(
          opacity: showMenu ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Material(
            color: Colors.transparent,
            elevation: 5,
            shadowColor: Colors.black.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            child: RawMaterialButton(
              onPressed: () {
                if (menuItems[index]['type'] == "tie") {
                  setState(() {
                    MusicalNote nextNote =
                        widget.sheetNoteRows[selectedNoteProvider.selectedRow]
                            [selectedNoteProvider.selectedIndex + 1];

                    if (selectedNote.pitch == nextNote.pitch) {
                      selectedNote.isTiedToNext = !selectedNote.isTiedToNext;
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                "Cannot Tie to a note with a different pitch.")),
                      );
                    }
                  });
                } else if (menuItems[index]['type'] == "beam") {
                  setState(() {
                    context.read<CurrentSelectedNoteProvider>().enableBeaming();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Select a second note to beam to.")),
                    );
                  });
                } else if (menuItems[index]['type'] == "slur") {
                  setState(() {
                    context
                        .read<CurrentSelectedNoteProvider>()
                        .enableSlurring();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Select a second note to add slur.")),
                    );
                  });
                }
              },
              fillColor: Colors.white,
              constraints: const BoxConstraints.tightFor(width: 35, height: 35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
                side: const BorderSide(color: Colors.black, width: 1),
              ),
              child: Text(
                menuItems[index]['label'],
                style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedNoteProvider =
        Provider.of<CurrentSelectedNoteProvider>(context);
    final rowSpacingProvider = Provider.of<ListOfSpacingForEachRow>(context);

    MusicalNote selectedNote = MusicalNote(
        pitch: "",
        octave: 0,
        type: NoteType.clef,
        isConnected: false,
        unicodeCharacter: "");

    if (widget.sheetNoteRows[selectedNoteProvider.selectedRow].isNotEmpty) {
      selectedNote = widget.sheetNoteRows[selectedNoteProvider.selectedRow]
          [selectedNoteProvider.selectedIndex];
    }

    var keyboardHeight = 420;
    var canvasHeight = widget.screenSize.height -
        AppBar().preferredSize.height -
        keyboardHeight -
        widget.statusBarHeight;

    return Column(
      children: [
        Stack(children: [
          GestureDetector(
            onTapDown: _handleTap, // Handle user tap
            child: Container(
              width: widget.screenSize.width,
              height: canvasHeight, // Adjust height as needed
              color:
                  const Color.fromARGB(255, 199, 199, 199), // Background color
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale:
                    initialScale * 0.4, // Allows zooming out further if needed
                maxScale: 3.0, // Allow zooming in up to 3x
                boundaryMargin: EdgeInsets.fromLTRB(
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
                      const double rowTotalHeight =
                          topGap + sheetHeight + bottomGap; // = 170px per row

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
                                    rowSpacingProvider.rowSpacingList),
                                size: Size(widget.musicSheetWidth,
                                    totalHeight), // Dynamic height
                              ),
                            ),
                          ),
                          CustomPaint(
                            painter: MusicSheetPainter(
                                widget.sheetNoteRows,
                                selectedNoteProvider
                                    .selectedRow, // Pass selected row
                                selectedNoteProvider
                                    .selectedIndex, // Pass selected index
                                _showCursor,
                                rowSpacingProvider.rowSpacingList),
                            size: Size(widget.musicSheetWidth,
                                totalHeight), // Dynamic height
                          )
                        ]),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
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
          if (showMenu) ..._buildCircularMenu(),
          Positioned(
            bottom: 55,
            right: 11,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  showMenu = !showMenu;
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
                child: Icon(
                  showMenu ? Icons.close : Icons.album_outlined,
                  color: const Color.fromARGB(255, 0, 0, 0),
                  size: 24,
                ),
              ),
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
}
