import 'package:flutter/material.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
import 'package:music_keyboard/src/widgets/home/sheet_preview_card.dart';
import 'package:music_keyboard/src/providers/auth_provider.dart' as app;
import 'package:music_keyboard/src/services/firestore_service.dart';
import 'package:music_keyboard/src/services/dynamic_link_service.dart';
import 'package:music_keyboard/src/services/sync_service.dart';
import 'package:music_keyboard/src/widgets/shared/popup_theme.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'configure_sheet_screen.dart';
import 'keyboard_screen.dart';
import 'login_screen.dart';

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
  Set<String> _selectedSheets = {};
  bool _isSyncing = false; // Guard to prevent concurrent syncs
  String? _syncErrorMessage; // Track sync error messages

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
    // Prevent concurrent sync operations
    if (_isSyncing) {
      print('HomeScreen: Sync already in progress, skipping...');
      return;
    }

    try {
      _isSyncing = true;
      setState(() {
        _isLoadingSheets = true;
      });

      final authProvider =
          Provider.of<app.AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      // If user is logged in, sync sheets from Firebase first
      if (userId != null) {
        print('HomeScreen: User logged in, starting sync...');
        final syncService = SyncService();
        await syncService.syncSheets(userId);
        print('HomeScreen: Sync completed, loading sheets from database...');
      }

      final dbHelper = SheetDatabaseHelper(
        userId: userId,
        firestoreService: userId != null ? FirestoreService() : null,
      );
      final sheets = await dbHelper.getAllSheets();
      print('HomeScreen: Loaded ${sheets.length} sheets from database');
      for (var sheet in sheets) {
        print(
            'HomeScreen: Sheet ${sheet.id} has ${sheet.sheetRows.length} rows');
        if (sheet.sheetRows.isNotEmpty) {
          print(
              'HomeScreen: First row has ${sheet.sheetRows[0].chords.length} notes');
        }
      }

      // Force UI refresh with new data
      if (mounted) {
        setState(() {
          _savedSheets = sheets;
          _isLoadingSheets = false;
        });
        print('HomeScreen: UI updated with ${sheets.length} sheets');
      }
    } catch (e) {
      print('HomeScreen: Error loading sheets: $e');
      if (mounted) {
        setState(() {
          _isLoadingSheets = false;
        });
      }
    } finally {
      // Always reset the sync flag
      _isSyncing = false;
    }
  }

  /// Handle pull-to-refresh action
  Future<void> _handleRefresh() async {
    // Clear any previous error messages
    setState(() {
      _syncErrorMessage = null;
    });

    final authProvider = Provider.of<app.AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    // Only sync if user is logged in
    if (userId == null) {
      setState(() {
        _syncErrorMessage = 'Unable to sync';
      });
      return;
    }

    // Prevent concurrent sync operations
    if (_isSyncing) {
      print('HomeScreen: Sync already in progress, skipping...');
      return;
    }

    try {
      _isSyncing = true;
      print('HomeScreen: Manual refresh triggered, starting sync...');

      final syncService = SyncService();
      await syncService.syncSheets(userId);

      final dbHelper = SheetDatabaseHelper(
        userId: userId,
        firestoreService: FirestoreService(),
      );
      final sheets = await dbHelper.getAllSheets();
      print(
          'HomeScreen: Manual refresh completed with ${sheets.length} sheets');

      if (mounted) {
        setState(() {
          _savedSheets = sheets;
          _syncErrorMessage = null; // Clear error on success
        });
      }
    } catch (e) {
      print('HomeScreen: Error during manual refresh: $e');
      if (mounted) {
        setState(() {
          _syncErrorMessage = 'Unable to sync';
        });
      }
    } finally {
      _isSyncing = false;
    }
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
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    border: Border(
                      bottom: BorderSide(color: Colors.orange[300]!, width: 1),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange[900], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Please verify your email',
                            style: TextStyle(
                              color: Colors.orange[900],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              _resendVerificationEmail(authProvider),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orange[900],
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Resend',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                          left: 32.0, top: 27, right: 32.0, bottom: 27.0),
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
                                      onRefresh: _handleRefresh,
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
          // Sign in/sign up button (when not signed in and not in selection mode)
          if (authProvider.user == null && !_isSelectionMode)
            Positioned(
              bottom: 60, // Above the AD BANNER
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

  Future<void> _handleSignOut(
      BuildContext context, app.AuthProvider authProvider) async {
    // Check for unsynced sheets
    final hasUnsynced = await authProvider.hasUnsyncedSheets();

    if (hasUnsynced) {
      // Show warning dialog
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
                    title: 'Unsynced Sheets',
                    onClose: () => Navigator.of(context).pop(false),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(PopupTheme.contentPadding),
                    child: Text(
                      'If you sign out some sheets that have not synced will be deleted. Please sign out when you have an internet connection.',
                      style: PopupTheme.bodyStyle,
                      textAlign: TextAlign.center,
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
                          child: const Text('Confirm'),
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
      final authProvider =
          Provider.of<app.AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;
      final dbHelper = SheetDatabaseHelper(
        userId: userId,
        firestoreService: userId != null ? FirestoreService() : null,
      );
      final firestoreService = FirestoreService();

      for (final sheetId in _selectedSheets) {
        // Delete from local database
        await dbHelper.deleteSheet(sheetId);

        // If user is logged in, delete from Firebase and mark as deleted
        if (userId != null) {
          await firestoreService.deleteSheet(sheetId, userId);
          await firestoreService.markSheetAsDeleted(sheetId, userId);
        }
      }

      await _loadSavedSheets();
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
            final dbHelper = SheetDatabaseHelper(
              userId: userId,
              firestoreService: firestoreService,
            );
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

    // Navigate to keyboard screen with the selected sheet
    await Navigator.pushNamed(
      context,
      KeyboardScreen.routeName,
      arguments: sheetToOpen,
    );

    // Reload sheets when returning from keyboard screen
    _loadSavedSheets();
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
