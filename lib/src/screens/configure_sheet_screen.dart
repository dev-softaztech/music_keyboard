import 'package:flutter/material.dart';
import 'package:music_keyboard/models/sheet_format.dart';
import 'package:music_keyboard/models/keyboard_type.dart';
import 'package:music_keyboard/src/providers/auth_provider.dart' as app;
import 'package:provider/provider.dart';
import 'package:music_keyboard/src/widgets/shared/banner_ad_widget.dart';
import 'keyboard_screen.dart';
import 'configure_sheet_screen/keyboard_type_card.dart';
import 'configure_sheet_screen/sheet_creation_service.dart';
import 'configure_sheet_screen/sheet_format_cards.dart';

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
                      padding: const EdgeInsets.fromLTRB(32, 82, 32, 32),
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
                                child: KeyboardTypeCard(
                                  keyboardType: KeyboardType.sheet,
                                  icon: Icons.music_note,
                                  isSelected: _selectedKeyboardType ==
                                      KeyboardType.sheet,
                                  onTap: () =>
                                      _selectKeyboardType(KeyboardType.sheet),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: KeyboardTypeCard(
                                  keyboardType: KeyboardType.drumTab,
                                  icon: Icons.audiotrack,
                                  isSelected: _selectedKeyboardType ==
                                      KeyboardType.drumTab,
                                  onTap: () => _selectKeyboardType(
                                      KeyboardType.drumTab),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: KeyboardTypeCard(
                                  keyboardType: KeyboardType.guitarTab,
                                  icon: Icons.piano,
                                  isSelected: _selectedKeyboardType ==
                                      KeyboardType.guitarTab,
                                  onTap: () => _selectKeyboardType(
                                      KeyboardType.guitarTab),
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

                          _selectedKeyboardType == KeyboardType.guitarTab
                              ? SingleSheetFormatCard(
                                  isSelected:
                                      _selectedFormat == SheetFormat.single,
                                )
                              : _buildAllFormatCards(),

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
          const Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              bottom: false,
              child: BannerAdWidget(),
            ),
          ),
        ],
      ),
    );
  }

  void _selectKeyboardType(KeyboardType keyboardType) {
    setState(() {
      _selectedKeyboardType = keyboardType;
      // Auto-select Single Stave when Guitar Tab is chosen
      if (keyboardType == KeyboardType.guitarTab) {
        _selectedFormat = SheetFormat.single;
      }
    });
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
    return SheetFormatCard(
      format: format,
      isSelected: _selectedFormat == format,
      isTopRow: isTopRow,
      onTap: () {
        setState(() {
          _selectedFormat = format;
        });
      },
    );
  }

  void _createSheet(BuildContext context) async {
    setState(() {
      _isCreating = true;
    });

    try {
      final authProvider =
          Provider.of<app.AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      final initialSheet = await SheetCreationService.createSheet(
        format: _selectedFormat,
        keyboardType: _selectedKeyboardType,
        title: _titleController.text,
        composer: _composerController.text,
        userId: userId,
      );

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
