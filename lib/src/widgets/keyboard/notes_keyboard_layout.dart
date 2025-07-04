import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/providers/selected_accidental_provider.dart';
import 'package:music_keyboard/src/widgets/keyboard/note_head_keyboard/keyboard_by_symbols.dart';
import 'package:music_keyboard/src/providers/selected_unicode_provider.dart';
import 'package:provider/provider.dart';

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

  // Octave pair state - false = Middle+Top pair, true = Bottom+Middle pair
  bool showLowerPair = false;

  void _toggleOctavePair() {
    setState(() {
      showLowerPair = !showLowerPair;
    });
  }

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
  void didUpdateWidget(NotesKeyboardLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the keyType changes (tab switch), remove any active overlay
    if (oldWidget.keyType != widget.keyType) {
      if (_overlayEntry != null) {
        _overlayEntry!.remove();
        _overlayEntry = null;
        _activeShiftButton = null;
      }
    }
  }

  // Show the popup for a specific shift button
  void _showPopup(String buttonType, BuildContext context) {
    // Remove any existing overlay first
    _removeOverlay();

    // Set the active shift button
    setState(() {
      _activeShiftButton = buttonType;
    });

    // Get the screen size
    final Size screenSize = MediaQuery.of(context).size;

    // Calculate the number of items to determine the popup height
    List<String> unicodeOptions = _getUnicodeOptions(buttonType);
    int itemCount = unicodeOptions.length;

    // Calculate the popup size based on content
    // Fixed width for consistency, but height depends on number of items
    double popupWidth = 200.0;
    double buttonSize = 80.0; // Fixed size for each button
    int crossAxisCount = 3; // Always 2 columns
    int rowCount = (itemCount / crossAxisCount).ceil();
    double popupHeight = (buttonSize * rowCount) + 32.0; // Add padding

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
          // The actual popup - centered on screen
          Positioned(
            left: (screenSize.width - popupWidth) / 2,
            top: (screenSize.height - popupHeight) / 2,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white),
                ),
                width: popupWidth,
                height: popupHeight,
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

  // Get unicode options based on button type
  List<String> _getUnicodeOptions(String buttonType) {
    if (buttonType == 'sharp') {
      return [
        '\ue262',
        '\ue268',
        '\ue263',
        '\ue265',
        '\ue269'
      ]; // Sharp variants
    } else if (buttonType == 'flat') {
      return ['\ue260', '\ue264', '\ue266', '\ue267']; // Flat variants
    } else if (buttonType == 'natural') {
      return ['\ue261']; // Natural variants
    } else if (buttonType == 'rest') {
      return [
        '\ue4e5',
        '\ue1b3',
        '\ue4e4',
        '\ue4e6',
        '\ue4e7',
        '\ue4e8',
        '\ue4e9'
      ]; // Rest variants
    }
    return [];
  }

  // Build the content of the popup based on the button type
  Widget _buildPopupContent(String buttonType, BuildContext context) {
    List<String> unicodeOptions = _getUnicodeOptions(buttonType);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(), // Disable scrolling
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.9, // Slightly wider than tall
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
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                unicode,
                style: const TextStyle(
                  fontFamily: 'Bravura',
                  fontSize: 40, // Even smaller
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
          accidental == '\ue268' || // sharp
          accidental == '\ue263' || // sharp
          accidental == '\ue265' ||
          accidental == '\ue269'; // sharp
    } else if (buttonType == 'flat') {
      return accidental == '\ue260' || // flat
          accidental == '\ue264' || // flat
          accidental == '\ue266' || // flat
          accidental == '\ue267'; // flat
    } else if (buttonType == 'rest') {
      return accidental == '\ue4e5' ||
          accidental == '\ue1b3' ||
          accidental == '\ue4e4' ||
          accidental == '\ue4e6' ||
          accidental == '\ue4e7' ||
          accidental == '\ue4e8' ||
          accidental == '\ue4e9';
    } else {
      // natural
      return accidental == '\ue261' || // natural
          accidental == '\ue261'; // natural
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
              selectedAccidental == '\ue268' ||
              selectedAccidental == '\ue263' ||
              selectedAccidental == '\ue265' ||
              selectedAccidental == '\ue269'
          ? selectedAccidental
          : '\ue262';
    } else if (buttonType == 'flat') {
      displayUnicode = selectedAccidental == '\ue260' ||
              selectedAccidental == '\ue264' ||
              selectedAccidental == '\ue266' ||
              selectedAccidental == '\ue267'
          ? selectedAccidental
          : '\ue260';
    } else if (buttonType == 'rest') {
      displayUnicode = selectedAccidental == '\ue4e5' ||
              selectedAccidental == '\ue1b3' ||
              selectedAccidental == '\ue4e4' ||
              selectedAccidental == '\ue4e6' ||
              selectedAccidental == '\ue4e7' ||
              selectedAccidental == '\ue4e8' ||
              selectedAccidental == '\ue4e9'
          ? selectedAccidental
          : '\ue4e5';
    } else {
      // natural
      displayUnicode =
          selectedAccidental == '\ue261' || selectedAccidental == '\ue261'
              ? selectedAccidental
              : '\ue261';
    }

    return SizedBox(
      width: 30,
      height: 40,
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
              ? Colors.grey[500]
              : isSelected
                  ? Colors.grey[300] // Shaded when selected
                  : Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.black, width: 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          displayUnicode,
          style: const TextStyle(
            fontFamily: 'Bravura',
            fontSize: 30,
            color: Color(0xFF242038),
          ),
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
    }

    return Container(
      height: 315, // Increased height to accommodate the arrows
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
                            backgroundColor:
                                isSelected ? Colors.black : Colors.white,
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
                              style: TextStyle(
                                fontFamily: 'Bravura',
                                fontSize: 30,
                                color: isSelected ? Colors.white : Colors.black,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: EdgeInsets.all(5.0),
                padding: EdgeInsets.all(5.0),
                child: Column(
                  children: [
                    //Clef
                    SizedBox(
                      width: 30,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onKeyPress(MusicalNote(
                              pitch: "",
                              octave: 0,
                              type: NoteType.clef,
                              isConnected: false,
                              unicodeCharacter: "\uf472"));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.black, width: 1),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          '\uf472',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            //fontWeight: FontWeight.bold,
                            fontFamily: 'Bravura',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    //Bass cleff
                    SizedBox(
                      width: 30,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onKeyPress(MusicalNote(
                              pitch: "",
                              octave: 0,
                              type: NoteType.clef,
                              isConnected: false,
                              unicodeCharacter: "\uf474"));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.black, width: 1),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          '\uf474',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            //fontWeight: FontWeight.bold,
                            fontFamily: 'Bravura',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    //4/4 time signature
                    SizedBox(
                      width: 30,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onKeyPress(MusicalNote(
                              pitch: "",
                              octave: 0,
                              type: NoteType.clef,
                              isConnected: false,
                              unicodeCharacter: "\uf474"));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.black, width: 1),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          '\uf5fe',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            //fontWeight: FontWeight.bold,
                            fontFamily: 'Bravura',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    _buildShiftButton('rest', 'Rest', context),
                    const SizedBox(height: 5),
                    // Octave cycle button
                    SizedBox(
                      width: 30,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: _toggleOctavePair,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.black, width: 1),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          'OCT',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              KeyboardBySymbols(
                  onKeyPress: widget.onKeyPress,
                  keyType: widget.keyType,
                  showLowerPair: showLowerPair),
              Container(
                margin: EdgeInsets.all(5.0),
                padding: EdgeInsets.all(5.0),
                child: Column(
                  children: [
                    SizedBox(
                      width: 30,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.black, width: 1),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          '\uE883',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 40,
                            //fontWeight: FontWeight.bold,
                            fontFamily: 'Bravura',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 30,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.black, width: 1),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          '\uE110',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Bravura',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Shift buttons
                    _buildShiftButton('sharp', 'Sharp', context),
                    const SizedBox(height: 5),
                    _buildShiftButton('flat', 'Flat', context),
                    const SizedBox(height: 5),
                    _buildShiftButton('natural', 'Natural', context),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}
