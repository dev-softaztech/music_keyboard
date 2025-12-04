import 'package:flutter/material.dart';
import 'package:music_keyboard/models/row_properties.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/models/sheet_properties.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'keyboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SheetFormat _selectedFormat = SheetFormat.single;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 255, 253, 253),
              Color.fromARGB(255, 245, 245, 245),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon/Logo placeholder
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(60),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.music_note,
                      size: 60,
                      color: Color(0xFF242038),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // App Title
                  const Text(
                    'Music Keyboard',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF242038),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Subtitle
                  const Text(
                    'Draft home page',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // Format Selection Section
                  const Text(
                    'Choose Format',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF242038),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Format Selection Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormatCard(
                          SheetFormat.single,
                          Icons.queue_music,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildFormatCard(
                          SheetFormat.twoRows,
                          Icons.piano,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Start Composing Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _navigateToKeyboard(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF242038),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Start Composing',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Additional info or features can be added here
                  Text(
                    'Tap the button above to begin creating your musical masterpiece',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatCard(SheetFormat format, IconData icon) {
    final bool isSelected = _selectedFormat == format;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFormat = format;
        });
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF242038) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF242038) : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? Colors.white : const Color(0xFF242038),
            ),
            const SizedBox(height: 8),
            Text(
              format.displayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF242038),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              format.description,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? Colors.white.withOpacity(0.8)
                    : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToKeyboard(BuildContext context) {
    // Create initial rows based on selected format
    List<SheetRows> initialRows = [];

    for (int i = 0; i < _selectedFormat.rowsPerGroup; i++) {
      final row = SheetRows(
        notes: [],
        rowProperties: RowProperties(tempoNumber: 0),
      );

      // Add appropriate clef for each row
      if (i < _selectedFormat.defaultClefs.length) {
        row.notes.add(MusicalNote(
          pitch: "G",
          octave: 4,
          type: NoteType.clef,
          isBeamed: false,
          unicodeCharacter: _selectedFormat.defaultClefs[i],
          clefType: _selectedFormat.defaultClefs[i],
        ));
      }

      initialRows.add(row);
    }

    // Initialize a new Sheet object with the selected format
    final initialSheet = Sheet(
      sheetRows: initialRows,
      sheetProperties: SheetProperties(),
      format: _selectedFormat,
    );

    // Navigate to keyboard screen with the initialized Sheet
    Navigator.pushNamed(
      context,
      KeyboardScreen.routeName,
      arguments: initialSheet,
    );
  }
}
