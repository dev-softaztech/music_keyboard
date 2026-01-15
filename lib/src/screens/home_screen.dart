import 'package:flutter/material.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
import 'package:music_keyboard/src/widgets/home/sheet_preview_card.dart';
import 'package:music_keyboard/src/widgets/shared/popup_theme.dart';
import 'configure_sheet_screen.dart';
import 'keyboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Sheet> _savedSheets = [];
  bool _isLoadingSheets = true;
  bool _isSelectionMode = false;
  Set<int> _selectedSheets = {};

  @override
  void initState() {
    super.initState();
    _loadSavedSheets();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload sheets whenever the screen becomes active
    _loadSavedSheets();
  }

  Future<void> _loadSavedSheets() async {
    try {
      final dbHelper = SheetDatabaseHelper();
      final sheets = await dbHelper.getAllSheets();
      print('DEBUG: Loaded ${sheets.length} sheets from database');
      for (var sheet in sheets) {
        print('DEBUG: Sheet ${sheet.id} has ${sheet.sheetRows.length} rows');
        if (sheet.sheetRows.isNotEmpty) {
          print(
              'DEBUG: First row has ${sheet.sheetRows[0].notes.length} notes');
        }
      }
      setState(() {
        _savedSheets = sheets;
        _isLoadingSheets = false;
      });
    } catch (e) {
      print('Error loading sheets: $e');
      setState(() {
        _isLoadingSheets = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Container(
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
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 32.0, right: 32.0, bottom: 27.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row with logo and title
                          Row(
                            children: [
                              // App Icon/Logo placeholder
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
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
                                  size: 30,
                                  color: Color(0xFF242038),
                                ),
                              ),

                              const SizedBox(width: 16),

                              // App Title
                              const Text(
                                'Music Keyboard',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF242038),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 80),

                          // Start Composing Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () =>
                                  _navigateToConfigureSheet(context),
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
                                  Icon(Icons.add, size: 24),
                                  SizedBox(width: 8),
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

                          const SizedBox(height: 48),

                          // Sheets Section
                          if (_savedSheets.isNotEmpty) ...[
                            const Text(
                              'Sheets',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF242038),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _isLoadingSheets
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : GridView.builder(
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: 0.8,
                                      ),
                                      itemCount: _savedSheets.length,
                                      itemBuilder: (context, index) {
                                        final sheet = _savedSheets[index];
                                        // Skip sheets without IDs (shouldn't happen with the fix, but defensive)
                                        if (sheet.id == null) {
                                          return const SizedBox.shrink();
                                        }
                                        return SheetPreviewCard(
                                          sheet: sheet,
                                          onTap: _isSelectionMode
                                              ? () => _toggleSheetSelection(
                                                  sheet.id!)
                                              : () =>
                                                  _openSheet(context, sheet),
                                          isSelectionMode: _isSelectionMode,
                                          isSelected: _selectedSheets
                                              .contains(sheet.id),
                                          onLongPress: () =>
                                              _enterSelectionMode(sheet.id!),
                                        );
                                      },
                                    ),
                            ),
                          ] else if (!_isLoadingSheets) ...[
                            Expanded(
                              child: Center(
                                child: Text(
                                  'No saved sheets yet. Tap "Start Composing" to create your first sheet!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Floating selection buttons
          if (_isSelectionMode)
            Positioned(
              bottom: 60, // Above the AD BANNER
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _exitSelectionMode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF242038),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedSheets.isNotEmpty
                          ? _deleteSelectedSheets
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedSheets.isNotEmpty
                            ? Colors.red
                            : Colors.grey,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Delete ${_selectedSheets.length} Sheet${_selectedSheets.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
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

  void _navigateToConfigureSheet(BuildContext context) {
    Navigator.pushNamed(context, ConfigureSheetScreen.routeName);
  }

  void _enterSelectionMode(int sheetId) {
    if (!_isSelectionMode) {
      setState(() {
        _isSelectionMode = true;
        _selectedSheets = {sheetId};
      });
    }
  }

  void _toggleSheetSelection(int sheetId) {
    setState(() {
      if (_selectedSheets.contains(sheetId)) {
        _selectedSheets.remove(sheetId);
        if (_selectedSheets.isEmpty) {
          _exitSelectionMode();
        }
      } else {
        _selectedSheets.add(sheetId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedSheets.clear();
    });
  }

  Future<void> _deleteSelectedSheets() async {
    if (_selectedSheets.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(PopupTheme.dialogMargin),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            decoration: PopupTheme.dialogDecoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                PopupTheme.buildHeader(
                  title: 'Confirm Deletion',
                  onClose: () => Navigator.of(context).pop(false),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(PopupTheme.contentPadding),
                  child: Text(
                    'Are you sure you want to delete ${_selectedSheets.length} sheet${_selectedSheets.length != 1 ? 's' : ''}?',
                    style: PopupTheme.bodyStyle,
                  ),
                ),

                // Actions
                Padding(
                  padding: const EdgeInsets.all(PopupTheme.actionsPadding),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: PopupTheme.secondaryButtonStyle,
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: PopupTheme.secondaryButtonStyle.copyWith(
                          foregroundColor:
                              MaterialStateProperty.all(Colors.red),
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      final dbHelper = SheetDatabaseHelper();
      for (final sheetId in _selectedSheets) {
        await dbHelper.deleteSheet(sheetId);
      }

      await _loadSavedSheets();
      _exitSelectionMode();
    }
  }

  void _openSheet(BuildContext context, Sheet sheet) async {
    // Navigate to keyboard screen with the selected sheet
    await Navigator.pushNamed(
      context,
      KeyboardScreen.routeName,
      arguments: sheet,
    );

    // Reload sheets when returning from keyboard screen
    _loadSavedSheets();
  }
}
