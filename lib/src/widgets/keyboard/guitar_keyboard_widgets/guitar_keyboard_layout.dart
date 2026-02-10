import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:provider/provider.dart';

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
      height: 270, // Increased height to accommodate the arrows
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Column(
        children: [],
      ),
    );
  }
}
