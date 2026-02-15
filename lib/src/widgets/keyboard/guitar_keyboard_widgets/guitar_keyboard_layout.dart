import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GuitarKeyboardLayout extends StatefulWidget {
  final bool showNotesKeyboard;
  final void Function(bool) onToggleKeyboard;
  final void Function(MusicalNote) onKeyPress;
  final List<SheetRows> sheetNoteRows;
  final SheetFormat sheetFormat;

  const GuitarKeyboardLayout({
    super.key,
    required this.showNotesKeyboard,
    required this.onToggleKeyboard,
    required this.onKeyPress,
    required this.sheetNoteRows,
    required this.sheetFormat,
  });

  @override
  State<GuitarKeyboardLayout> createState() => _GuitarKeyboardLayoutState();
}

class _GuitarKeyboardLayoutState extends State<GuitarKeyboardLayout> {
  // Overlay entry for the popup
  OverlayEntry? _overlayEntry;

  // Octave pair state - false = Middle+Top pair, true = Bottom+Middle pair
  bool showLowerPair = false;

  @override
  void dispose() {
    // Make sure to remove any active overlay when disposing
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    super.dispose();
  }

  // Build a technique button (for top two rows)
  Widget _buildTechniqueButton(String label,
      {bool isUnicode = true, String? svgAssetPath}) {
    return SizedBox(
      width: 32,
      height: 32,
      child: ElevatedButton(
        onPressed: () {
          // TODO: Implement technique button functionality
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: const BorderSide(color: Colors.black, width: 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: svgAssetPath != null
            ? SvgPicture.asset(svgAssetPath,
                width: 20,
                height: 20,
                colorFilter: ColorFilter.linearToSrgbGamma())
            : Text(
                label,
                style: TextStyle(
                  fontFamily: isUnicode ? 'Bravura' : null,
                  fontSize: isUnicode ? 30 : 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
      ),
    );
  }

  // Build a string button (E, A, D, G, B, E)
  Widget _buildStringButton(String note) {
    return Container(
      height: 25,
      width: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8), // Match your button's shape
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            blurRadius: 5,
            spreadRadius: 0,
            offset: Offset.zero, // This centers the shadow
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          // TODO: Implement string selection functionality
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: const BorderSide(
                color: Color.fromARGB(255, 218, 218, 218), width: 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          note,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  // Build a fret button (numbers 1-24)
  Widget _buildFretButton(int fretNumber) {
    return Container(
      height: 31,
      width: 31,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      child: ElevatedButton(
        onPressed: () {
          // TODO: Implement fret selection functionality
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: const BorderSide(color: Colors.black, width: 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          fretNumber.toString(),
          style: const TextStyle(
            fontSize: 14,
            //fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildNextLastButton(bool isNextNote) {
    double buttonWidth = MediaQuery.of(context).size.width / 2.8;

    return Container(
      height: 31,
      width: buttonWidth,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      child: ElevatedButton(
        onPressed: () {
          // TODO: Implement
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: isNextNote
              ? [
                  const Text('Next', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 18),
                ]
              : [
                  const Icon(Icons.arrow_back, size: 18),
                  const SizedBox(width: 4),
                  const Text('Back', style: TextStyle(fontSize: 14)),
                ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSelectedNoteProvider =
        Provider.of<CurrentSelectedNoteProvider>(context);
    final selectedNoteIndex = currentSelectedNoteProvider.selectedIndex;
    final selectedRow = currentSelectedNoteProvider.selectedRow;
    final selectedNote = (widget.sheetNoteRows.isNotEmpty &&
            widget.sheetNoteRows[selectedRow].notes.isNotEmpty &&
            widget.sheetNoteRows[selectedRow].notes.length >
                selectedNoteIndex &&
            selectedNoteIndex != -1)
        ? widget.sheetNoteRows[selectedRow].notes[selectedNoteIndex]
        : null;

    return Container(
      height: 270,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 30,
                width: 25,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(8), // Match your button's shape
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey,
                      blurRadius: 5,
                      spreadRadius: 0,
                      offset: Offset.zero, // This centers the shadow
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement string selection functionality
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                      side: const BorderSide(
                          color: Color.fromARGB(255, 218, 218, 218), width: 1),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    '\uF40A',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontFamily: 'Bravura',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _buildNextLastButton(false),
                _buildNextLastButton(true)
              ]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStringButton('E'),
                  const SizedBox(height: 7),
                  _buildStringButton('A'),
                  const SizedBox(height: 7),
                  _buildStringButton('D'),
                  const SizedBox(height: 7),
                  _buildStringButton('G'),
                  const SizedBox(height: 7),
                  _buildStringButton('B'),
                  const SizedBox(height: 7),
                  _buildStringButton('E'),
                ],
              ),
              Column(
                children: [
                  const SizedBox(height: 5),
                  // First technique row with 7 buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTechniqueButton('P.M.', isUnicode: false),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('P.H.', isUnicode: false),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('\uE589'),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('\uE4BA'),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('bend',
                          svgAssetPath: 'assets/svgs/bend.svg'),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('pre-bend',
                          svgAssetPath: 'assets/svgs/pre-bend.svg'),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('\uE610'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Second technique row with 7 buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTechniqueButton('\uE682 '),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('Ham.', isUnicode: false),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('\uEA6D'),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('\uEA6E'),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('bend-release',
                          svgAssetPath: 'assets/svgs/bend-release.svg'),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('pre-bend-release',
                          svgAssetPath: 'assets/svgs/pre-bend-release.svg'),
                      const SizedBox(width: 7),
                      _buildTechniqueButton('\uE612'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      //mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildFretButton(1),
                        _buildFretButton(2),
                        _buildFretButton(3),
                        _buildFretButton(4),
                        _buildFretButton(5),
                        _buildFretButton(6),
                        _buildFretButton(7),
                        _buildFretButton(8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Fret numbers row 2 (9-16)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFretButton(9),
                        _buildFretButton(10),
                        _buildFretButton(11),
                        _buildFretButton(12),
                        _buildFretButton(13),
                        _buildFretButton(14),
                        _buildFretButton(15),
                        _buildFretButton(16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Fret numbers row 3 (17-24)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFretButton(17),
                        _buildFretButton(18),
                        _buildFretButton(19),
                        _buildFretButton(20),
                        _buildFretButton(21),
                        _buildFretButton(22),
                        _buildFretButton(23),
                        _buildFretButton(24),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
