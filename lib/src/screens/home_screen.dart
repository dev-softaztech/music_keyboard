import 'package:flutter/material.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
import 'package:music_keyboard/src/widgets/home/sheet_preview_card.dart';
import 'package:music_keyboard/src/providers/auth_provider.dart' as app;
import 'package:music_keyboard/src/services/firestore_service.dart';
import 'package:music_keyboard/src/services/dynamic_link_service.dart';
import 'package:music_keyboard/src/widgets/shared/banner_ad_widget.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'configure_sheet_screen.dart';
import 'keyboard_screen.dart';
import 'login_screen.dart';
import 'home_screen/email_verification_banner.dart';
import 'home_screen/home_screen_controller.dart';
import 'home_screen/home_screen_dialogs.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> implements HomeScreenHost {
  List<Sheet> _savedSheets = [];
  bool _isLoadingSheets = true;
  bool _isSelectionMode = false;
  Set<String> _selectedSheets = {};
  String? _syncErrorMessage;

  late final HomeScreenController _controller =
      HomeScreenController(host: this);

  @override
  String? get userId =>
      Provider.of<app.AuthProvider>(context, listen: false).user?.uid;

  @override
  void onSheetsLoaded(List<Sheet> sheets) {
    setState(() {
      _savedSheets = sheets;
    });
  }

  @override
  void onLoadingChanged(bool isLoading) {
    setState(() {
      _isLoadingSheets = isLoading;
    });
  }

  @override
  void onSyncErrorChanged(String? message) {
    setState(() {
      _syncErrorMessage = message;
    });
  }

  @override
  void initState() {
    super.initState();
    _controller.loadSavedSheets();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload sheets whenever the screen becomes active
    _controller.loadSavedSheets();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<app.AuthProvider>(context);
    final showVerificationBanner =
        authProvider.user != null && !authProvider.isEmailVerified;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Email verification banner
              if (showVerificationBanner)
                EmailVerificationBanner(
                  onResend: () => _resendVerificationEmail(authProvider),
                ),
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
                          left: 32.0, top: 77, right: 32.0, bottom: 27.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with logo banner
                          Center(
                            child: Image.asset(
                              'assets/images/temp-logo-banner.png',
                              fit: BoxFit.contain,
                            ),
                          ),

                          const SizedBox(height: 40),

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

                          const SizedBox(height: 30),

                          // Sheets Section
                          if (_savedSheets.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Sheets',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF242038),
                                  ),
                                ),
                                if (_syncErrorMessage != null)
                                  Text(
                                    _syncErrorMessage!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _isLoadingSheets
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : RefreshIndicator(
                                      onRefresh: _controller.handleRefresh,
                                      color: const Color(0xFF242038),
                                      backgroundColor: Colors.white,
                                      child: GridView.builder(
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
          // Sign in/sign up button
          if (authProvider.user == null && !_isSelectionMode)
            Positioned(
              bottom: 60,
              left: 16,
              right: 16,
              child: Center(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, LoginScreen.routeName);
                    },
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
                        Icon(Icons.login, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Sign In / Sign Up',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Floating selection buttons
          if (_isSelectionMode)
            Positioned(
              bottom: 60,
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

          // Logout button (when signed in and not in selection mode)
          if (authProvider.user != null && !_isSelectionMode)
            Positioned(
              bottom:
                  70, // Above the AD BANNER, slightly higher than sign in button
              right: 16,
              child: FloatingActionButton(
                onPressed: () => _handleSignOut(context, authProvider),
                backgroundColor: const Color(0xFF242038),
                foregroundColor: Colors.white,
                elevation: 4,
                child: const Icon(Icons.logout),
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

  void _navigateToConfigureSheet(BuildContext context) {
    Navigator.pushNamed(context, ConfigureSheetScreen.routeName);
  }

  Future<void> _handleSignOut(
      BuildContext context, app.AuthProvider authProvider) async {
    // Check for unsynced sheets
    final hasUnsynced = await authProvider.hasUnsyncedSheets();

    if (hasUnsynced) {
      // Show warning dialog
      final confirmed = await showUnsyncedSheetsDialog(context);

      if (confirmed == true) {
        await authProvider.signOut();
      }
    } else {
      // No unsynced sheets, sign out directly
      await authProvider.signOut();
    }
  }

  Future<void> _shareSheet(Sheet sheet) async {
    try {
      final dynamicLinkService = DynamicLinkService();
      final Uri shareLink = await dynamicLinkService.createDynamicLink(sheet);
      final shareText =
          "Check out this sheet written on Mote'z Notes $shareLink";
      await Share.share(shareText);
    } catch (e) {
      print('Error sharing sheet: $e');
    }
  }

  void _enterSelectionMode(String sheetId) {
    if (!_isSelectionMode) {
      setState(() {
        _isSelectionMode = true;
        _selectedSheets = {sheetId};
      });
    }
  }

  void _toggleSheetSelection(String sheetId) {
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

    final confirmed =
        await showDeleteConfirmationDialog(context, _selectedSheets.length);

    if (confirmed == true) {
      await _controller.deleteSheets(_selectedSheets);
      _exitSelectionMode();
    }
  }

  void _openSheet(BuildContext context, Sheet sheet) async {
    final authProvider = Provider.of<app.AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    Sheet sheetToOpen = sheet;

    // If user is logged in, check for latest version from Firebase
    if (userId != null) {
      try {
        final firestoreService = FirestoreService();
        final firebaseSheet =
            await firestoreService.getSheet(sheet.id!, userId);

        if (firebaseSheet != null) {
          // Compare lastUpdated timestamps
          if (firebaseSheet.lastUpdated.isAfter(sheet.lastUpdated)) {
            // Firebase version is newer, update local
            final dbHelper = SheetDatabaseHelper(userId: userId);
            await dbHelper.updateSheet(firebaseSheet);
            sheetToOpen = firebaseSheet;
            print('Updated local sheet with newer Firebase version');
          } else if (sheet.lastUpdated.isAfter(firebaseSheet.lastUpdated)) {
            // Local version is newer, update Firebase
            await firestoreService.updateSheet(sheet, userId);
            print('Updated Firebase with newer local version');
          }
          // If timestamps are equal, no sync needed
        }
      } catch (e) {
        print('Error syncing sheet on open: $e');
        // Continue with local version if sync fails
      }
    }

    await Navigator.pushNamed(
      context,
      KeyboardScreen.routeName,
      arguments: sheetToOpen,
    );

    // Reload sheets when returning from keyboard screen
    _controller.loadSavedSheets();
  }

  Future<void> _resendVerificationEmail(app.AuthProvider authProvider) async {
    try {
      await authProvider.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent! Please check your inbox.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send email: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
