import 'package:flutter/material.dart';
import 'package:music_keyboard/models/row_properties.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/models/sheet_properties.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/models/keyboard_type.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
import 'package:music_keyboard/src/services/firestore_service.dart';
import 'package:music_keyboard/src/providers/auth_provider.dart' as app;
import 'package:provider/provider.dart';
import 'keyboard_screen.dart';

class ConfigureSheetScreen extends StatefulWidget {
  const ConfigureSheetScreen({super.key});

  static const routeName = '/configure';

  @override
  State<ConfigureSheetScreen> createState() => _ConfigureSheetScreenState();
}

class _ConfigureSheetScreenState extends State<ConfigureSheetScreen> {
  SheetFormat _selectedFormat = SheetFormat.single;
  KeyboardType _selectedKeyboardType = KeyboardType.sheet;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _composerController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _composerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Configure Sheet',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF242038),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF242038)),
      ),
      body: Stack(
        children: [
          Container(
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
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title Text Field
                          SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _titleController,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                labelText: 'Title',
                                hintText: 'Enter sheet title',
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF242038), width: 2),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Composer Text Field
                          SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _composerController,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                labelText: 'Composer',
                                hintText: 'Enter composer name',
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF242038), width: 2),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Keyboard Type Selection Section
                          const Text(
                            'Choose Keyboard Type',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF242038),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Keyboard Type Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildKeyboardTypeCard(
                                  KeyboardType.sheet,
                                  Icons.music_note,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildKeyboardTypeCard(
                                  KeyboardType.drumTab,
                                  Icons.audiotrack,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildKeyboardTypeCard(
                                  KeyboardType.guitarTab,
                                  Icons.piano,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Format Selection Section
                          const Text(
                            'Choose Sheet Format',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF242038),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Format Selection Cards - All 5 formats
                          _buildAllFormatCards(),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // Create Button (pinned to bottom)
                  Container(
                    padding: const EdgeInsets.only(
                        left: 32.0, top: 32.0, right: 32.0, bottom: 42.0),
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 245, 245, 245),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed:
                            _isCreating ? null : () => _createSheet(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF242038),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: _isCreating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Create Sheet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // AD BANNER (always visible)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 50,
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.black,
                    width: 1,
                  ),
                ),
                color: Colors.white,
              ),
              alignment: Alignment.center,
              child: const Text(
                'AD BANNER',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllFormatCards() {
    return Column(
      children: [
        // First row: Single and Two Staves
        Row(
          children: [
            Expanded(
              child: _buildFormatCard(SheetFormat.single, isTopRow: true),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFormatCard(SheetFormat.twoRows, isTopRow: true),
            ),
          ],
        ),
        // Second row: Three, Four and Five Staves (filling space)
        Row(
          children: [
            Expanded(
              child: _buildFormatCard(SheetFormat.threeRows, isTopRow: false),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFormatCard(SheetFormat.fourRows, isTopRow: false),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFormatCard(SheetFormat.fiveRows, isTopRow: false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormatCard(SheetFormat format, {required bool isTopRow}) {
    final bool isSelected = _selectedFormat == format;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFormat = format;
        });
      },
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF242038) : Colors.white,
          borderRadius: isTopRow
              ? const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                )
              : const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
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
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                format.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF242038),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                format.description,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected
                      ? Colors.white.withOpacity(0.8)
                      : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardTypeCard(KeyboardType keyboardType, IconData icon) {
    final bool isSelected = _selectedKeyboardType == keyboardType;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedKeyboardType = keyboardType;
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
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected ? Colors.white : const Color(0xFF242038),
              ),
              const SizedBox(height: 6),
              Text(
                keyboardType.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF242038),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                keyboardType.description,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected
                      ? Colors.white.withOpacity(0.8)
                      : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createSheet(BuildContext context) async {
    setState(() {
      _isCreating = true;
    });

    try {
      // Create initial rows based on selected format
      List<SheetRows> initialRows = [];

      for (int i = 0; i < _selectedFormat.rowsPerGroup; i++) {
        final row = SheetRows(
          chords: [],
          rowProperties: RowProperties(tempoNumber: 0),
        );

        // Add appropriate clef for each row
        if (i < _selectedFormat.defaultClefsFor(_selectedKeyboardType).length) {
          row.chords.add(MusicalNote(
            pitch: "G",
            octave: 4,
            type: NoteType.clef,
            isBeamed: false,
            unicodeCharacter:
                _selectedFormat.defaultClefsFor(_selectedKeyboardType)[i],
            clefType: _selectedFormat.defaultClefsFor(_selectedKeyboardType)[i],
          ));
        }

        // For guitar tab sheets, add the default fret chord
        if (_selectedKeyboardType == KeyboardType.guitarTab) {
          row.chords.add(MusicalNote(
            pitch: 'G',
            octave: 4,
            type: NoteType.fret,
            duration: 0.0,
            childNotes: [],
          ));
        }

        initialRows.add(row);
      }

      // Create SheetProperties with title and composer
      final sheetProperties = SheetProperties(
        title: _titleController.text.trim().isEmpty
            ? 'Untitled'
            : _titleController.text.trim(),
        composer: _composerController.text.trim(),
      );

      // Initialize a new Sheet object with the configured properties
      final initialSheet = Sheet(
        sheetRows: initialRows,
        sheetProperties: sheetProperties,
        format: _selectedFormat,
        keyboardType: _selectedKeyboardType,
      );

      // Insert the sheet into the database and get the assigned ID
      final authProvider =
          Provider.of<app.AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;
      final dbHelper = SheetDatabaseHelper(
        userId: userId,
        firestoreService: userId != null ? FirestoreService() : null,
      );
      await dbHelper.insertSheet(initialSheet);

      // Verify the sheet has an ID before proceeding
      if (initialSheet.id == null) {
        throw Exception('Sheet was inserted but no ID was assigned');
      }

      // Navigate to keyboard screen with the initialized Sheet
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          KeyboardScreen.routeName,
          arguments: initialSheet,
        );
      }
    } catch (e) {
      print('Error creating sheet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create sheet. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
}
