import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/providers/is_connected_provider.dart';
import 'package:music_keyboard/src/providers/selected_accidental_provider.dart';
import 'package:music_keyboard/src/widgets/keyboard/letters_keyboard/keyboard_by_notes.dart';
import 'package:music_keyboard/src/widgets/keyboard/note_head_keyboard/keyboard_by_symbols.dart';
import 'package:music_keyboard/src/providers/selected_unicode_provider.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

class NotesKeyboardLayout extends StatefulWidget {
  final bool showNotesKeyboard;
  final void Function(bool) onToggleKeyboard;
  final void Function(MusicalNote) onKeyPress;
  final String keyType;

  const NotesKeyboardLayout({
    super.key,
    required this.showNotesKeyboard,
    required this.onToggleKeyboard,
    required this.onKeyPress,
    required this.keyType,
  });

  @override
  State<NotesKeyboardLayout> createState() => _NotesKeyboardLayoutState();
}

class _NotesKeyboardLayoutState extends State<NotesKeyboardLayout> {
  // Track which shift button is currently showing its popup
  String? _activeShiftButton;
  // Overlay entry for the popup
  OverlayEntry? _overlayEntry;
  // Global keys to get the positions of the shift buttons
  final Map<String, GlobalKey> _shiftButtonKeys = {
    'sharp': GlobalKey(),
    'flat': GlobalKey(),
    'natural': GlobalKey(),
  };

  @override
  void dispose() {
    // Make sure to remove any active overlay when disposing
    _removeOverlay();
    super.dispose();
  }

  // Show the popup for a specific shift button
  void _showPopup(String buttonType, BuildContext context) {
    // Remove any existing overlay first
    _removeOverlay();

    // Set the active shift button
    setState(() {
      _activeShiftButton = buttonType;
    });

    // Get the position of the button
    final RenderBox renderBox = _shiftButtonKeys[buttonType]!
        .currentContext!
        .findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // Create the overlay entry
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Invisible full-screen button to detect taps outside
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // The actual popup
          Positioned(
            left: position.dx - 60, // Center the popup above the button
            top: position.dy - 120, // Position above the button
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                width: 150,
                height: 110,
                child: _buildPopupContent(buttonType, context),
              ),
            ),
          ),
        ],
      ),
    );

    // Add the overlay to the overlay
    Overlay.of(context).insert(_overlayEntry!);
  }

  // Remove the overlay
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _activeShiftButton = null;
    });
  }

  // Build the content of the popup based on the button type
  Widget _buildPopupContent(String buttonType, BuildContext context) {
    List<String> unicodeOptions = [];

    // Get the appropriate unicode options based on the button type
    if (buttonType == 'sharp') {
      unicodeOptions = [
        '\ue262',
        '\ue264',
        '\ue266',
        '\ue268'
      ]; // Sharp variants
    } else if (buttonType == 'flat') {
      unicodeOptions = [
        '\ue260',
        '\ue263',
        '\ue265',
        '\ue267'
      ]; // Flat variants
    } else if (buttonType == 'natural') {
      unicodeOptions = ['\ue261', '\ue269']; // Natural variants
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.5,
      ),
      itemCount: unicodeOptions.length,
      itemBuilder: (context, index) {
        final unicode = unicodeOptions[index];
        return InkWell(
          onTap: () {
            // Update the selected accidental in the provider
            context
                .read<SelectedAccidentalProvider>()
                .updateSelectedAccidental(unicode);
            // Remove the overlay
            _removeOverlay();
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                unicode,
                style: const TextStyle(
                  fontFamily: 'Bravura',
                  fontSize: 30,
                  color: Color(0xFF242038),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Check if the accidental belongs to a specific button type
  bool _isAccidentalForButtonType(String accidental, String buttonType) {
    if (buttonType == 'sharp') {
      return accidental == '\ue262' || // sharp
          accidental == '\ue264' || // sharp
          accidental == '\ue266' || // sharp
          accidental == '\ue268'; // sharp
    } else if (buttonType == 'flat') {
      return accidental == '\ue260' || // flat
          accidental == '\ue263' || // flat
          accidental == '\ue265' || // flat
          accidental == '\ue267'; // flat
    } else {
      // natural
      return accidental == '\ue261' || // natural
          accidental == '\ue269'; // natural
    }
  }

  // Build a shift button
  Widget _buildShiftButton(
      String buttonType, String label, BuildContext context) {
    final isActive = _activeShiftButton == buttonType;

    // Get the selected accidental from the provider
    final selectedAccidental =
        context.watch<SelectedAccidentalProvider>().selectedAccidental;

    // Check if this button type is currently selected (has one of its accidentals active)
    final isSelected = selectedAccidental.isNotEmpty &&
        _isAccidentalForButtonType(selectedAccidental, buttonType);

    // Determine which unicode to show based on the button type
    String displayUnicode;
    if (buttonType == 'sharp') {
      displayUnicode = selectedAccidental == '\ue262' ||
              selectedAccidental == '\ue264' ||
              selectedAccidental == '\ue266' ||
              selectedAccidental == '\ue268'
          ? selectedAccidental
          : '\ue262';
    } else if (buttonType == 'flat') {
      displayUnicode = selectedAccidental == '\ue260' ||
              selectedAccidental == '\ue263' ||
              selectedAccidental == '\ue265' ||
              selectedAccidental == '\ue267'
          ? selectedAccidental
          : '\ue260';
    } else {
      // natural
      displayUnicode =
          selectedAccidental == '\ue261' || selectedAccidental == '\ue269'
              ? selectedAccidental
              : '\ue261';
    }

    return SizedBox(
      width: 80,
      height: 50,
      child: ElevatedButton(
        key: _shiftButtonKeys[buttonType],
        onPressed: () {
          if (isActive) {
            // If the popup is active, close it
            _removeOverlay();
          } else if (isSelected) {
            // If this button is already selected (shaded), clear the accidental
            // Use Future.microtask to schedule the update after the build phase
            Future.microtask(() {
              context
                  .read<SelectedAccidentalProvider>()
                  .updateSelectedAccidental('');
            });
          } else {
            // Otherwise show the popup
            _showPopup(buttonType, context);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? Colors.orange[700]
              : isSelected
                  ? Colors.orange[500] // Shaded when selected
                  : Colors.orange[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF242038),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              displayUnicode,
              style: const TextStyle(
                fontFamily: 'Bravura',
                fontSize: 24,
                color: Color(0xFF242038),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> unicodeCharacters = [];

    if (widget.keyType == "meters") {
      unicodeCharacters = [
        '\uf5f9',
        '\uf5fa',
        '\uf5fb',
        '\uf5fc',
        '\uf5fd',
        '\uf5fe',
        '\uf5ff',
        '\uf600',
        '\uf601',
        '\uf602',
        '\uf603',
        '\uf604',
        '\uf605',
        '\uf510',
        '\uf511',
      ];
    } else if (widget.keyType == "rests") {
      unicodeCharacters = [
        '\ue1b3',
        '\ue4e3',
        '\ue4e4',
        '\ue4e5',
        '\ue4e6',
        '\ue4e7',
        '\ue4e8',
        '\ue4e9',
        //'\ue4ea',
        //'\ue4eb',
        //'\ue4ec',
        //'\ue4ed',
      ];
    } else if (widget.keyType == "notes") {
      unicodeCharacters = [
        '\ue1d2',
        '\ue1d3',
        '\ue1d5',
        '\ue1d7',
        '\ue1d9',
        '\ue1db',
        '\ue1dd',
      ];

      // No automatic selection of accidental on load
    }

    return Container(
      height: 280, // Fixed height for the keyboard area
      padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
      child: Column(
        children: [
          // For notes, show the horizontal scroll of unicode characters
          if (unicodeCharacters.isNotEmpty)
            Consumer<SelectedUnicodeProvider>(
              builder: (context, provider, _) => Container(
                height: 50,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: unicodeCharacters.length,
                  itemBuilder: (context, index) {
                    final character = unicodeCharacters[index];
                    final isSelected = provider.selectedCharacter == character;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5.0),
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: ElevatedButton(
                          onPressed: () {
                            provider.updateSelectedCharacter(character);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSelected
                                ? Colors.orange[700]
                                : Colors.orange[300],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Transform.translate(
                            offset: widget.keyType == "notes"
                                ? const Offset(0, 16)
                                : widget.keyType == "accidentals"
                                    ? const Offset(0, 4)
                                    : const Offset(0, 0),
                            child: Text(
                              character,
                              style: const TextStyle(
                                fontFamily: 'Bravura',
                                fontSize: 30,
                                color: Color(0xFF242038),
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // For notes, show the shift key style buttons for accidentals
          if (widget.keyType == "notes")
            Container(
              height: 30,
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShiftButton('sharp', 'Sharp', context),
                  _buildShiftButton('flat', 'Flat', context),
                  _buildShiftButton('natural', 'Natural', context),
                ],
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Padding(padding: EdgeInsets.fromLTRB(5, 0, 0, 0)),
                  const Text("Beam Lock", style: TextStyle(fontSize: 10)),
                  Consumer<IsConnectedProvider>(
                    builder: (context, provider, _) => Transform.scale(
                      scale: 0.7,
                      child: Switch(
                        inactiveThumbColor: const Color(0xFF242038),
                        inactiveTrackColor: Colors.white,
                        activeColor: const Color(0xFF242038),
                        activeTrackColor: Colors.orange,
                        value: provider.isConnected,
                        onChanged: (value) {
                          provider.toggleConnection(value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                child: ToggleButtons(
                  textStyle: const TextStyle(fontSize: 10),
                  isSelected: [
                    !widget.showNotesKeyboard,
                    widget.showNotesKeyboard
                  ],
                  onPressed: (int index) {
                    widget.onToggleKeyboard(index == 1);
                  },
                  borderRadius: BorderRadius.circular(8.0),
                  selectedColor: Colors.white,
                  fillColor: Colors.orange,
                  color: Colors.black,
                  constraints: const BoxConstraints(
                    minHeight: 23.0,
                    minWidth: 60.0,
                  ),
                  children: const [
                    Text("Note heads"),
                    Text("Letters"),
                  ],
                ),
              ),
            ],
          ),

          // Show the appropriate keyboard based on the toggle
          if (widget.showNotesKeyboard)
            KeyboardByNotes(
                onKeyPress: widget.onKeyPress, keyType: widget.keyType)
          else
            KeyboardBySymbols(
                onKeyPress: widget.onKeyPress, keyType: widget.keyType),
        ],
      ),
    );
  }
}
