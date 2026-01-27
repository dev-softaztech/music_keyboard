import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/src/screens/keyboard_screen.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
import 'package:music_keyboard/src/services/firestore_service.dart';
import 'package:music_keyboard/src/utils/toast_utils.dart';
import 'package:music_keyboard/src/app.dart';

class DynamicLinkService {
  static final DynamicLinkService _instance = DynamicLinkService._internal();
  factory DynamicLinkService() => _instance;
  DynamicLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  // Track the last processed link to prevent duplicate processing
  String? _lastProcessedLinkString;
  DateTime? _lastProcessedTime;

  // Prevent checking initial link multiple times during the same app session
  bool _hasCheckedInitialLink = false;

  static const String _baseUrl = 'https://motez-notes.web.app/';

  /// Creates a deep link URL for sharing a sheet
  /// This generates a simple URL that will be handled by the app
  Future<Uri> createDynamicLink(Sheet sheet) async {
    // Create a URL with both sheet ID and owner's user ID
    final Uri deepLink =
        Uri.parse('$_baseUrl/sheet?id=${sheet.id}&userId=${sheet.userId}');
    return deepLink;
  }

  /// Initialize deep link handling
  /// This should be called when the app starts
  Future<void> initDynamicLinks(BuildContext context) async {
    // Handle the initial link if the app was opened via a deep link
    // Only check once per app session to prevent re-processing when navigating back to home
    if (!_hasCheckedInitialLink) {
      try {
        final Uri? initialLink = await _appLinks.getInitialLink();
        if (initialLink != null) {
          _handleDeepLink(context, initialLink);
        }
      } catch (e) {
        debugPrint('Error handling initial link: $e');
      }
      _hasCheckedInitialLink = true;
    }

    // Listen for deep links while the app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) async {
        await _handleDeepLink(context, uri);
      },
      onError: (error) {
        debugPrint('Error listening to deep links: $error');
      },
    );
  }

  /// Handle incoming deep links
  Future<void> _handleDeepLink(BuildContext context, Uri uri) async {
    debugPrint('Received deep link: $uri');

    // Extract the sheet ID and owner's user ID from the query parameters
    final String? sheetId = uri.queryParameters['id'];
    final String? ownerId = uri.queryParameters['userId'];

    if (sheetId == null || sheetId.isEmpty) {
      debugPrint('No sheet ID found in deep link');
      return;
    }

    // Prevent duplicate processing of the same link within 10 seconds
    // (Android system can fire the same deep link multiple times rapidly)
    final now = DateTime.now();
    final currentLinkString = uri.toString();

    if (_lastProcessedLinkString == currentLinkString &&
        _lastProcessedTime != null) {
      final millisecondsSinceLastProcess =
          now.difference(_lastProcessedTime!).inMilliseconds;
      debugPrint(
          'Time since last process: $millisecondsSinceLastProcess milliseconds');

      if (millisecondsSinceLastProcess < 10000) {
        debugPrint(
            'Skipping duplicate deep link - same link processed within 10 seconds');
        return;
      }
    }

    // Update the last processed link and time
    _lastProcessedLinkString = currentLinkString;
    _lastProcessedTime = now;
    debugPrint('Processing deep link - will navigate to sheet');

    try {
      // Get current user to check if this is their own sheet
      final User? currentUser = FirebaseAuth.instance.currentUser;
      final String? currentUserId = currentUser?.uid;

      // If user is not signed in and this is a shared sheet, show sign-in prompt
      if (currentUser == null && ownerId != null && ownerId.isNotEmpty) {
        debugPrint(
            'User not signed in, showing sign-in prompt for shared sheet');
        // Navigate to home and show sign-in popup
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final navigatorContext = MyApp.navigatorKey.currentContext;
          if (navigatorContext != null && navigatorContext.mounted) {
            Navigator.pushNamedAndRemoveUntil(
              navigatorContext,
              '/',
              (route) => false,
            );
            // Show sign-in prompt after navigation
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showSignInPromptForSharedSheet(navigatorContext);
            });
          }
        });
        return;
      }

      // First, try to load the sheet from the local database
      final SheetDatabaseHelper dbHelper = SheetDatabaseHelper();
      Sheet? sheet = await dbHelper.getSheet(sheetId);

      // If sheet not found locally and we have an owner ID, try fetching from Firebase
      if (sheet == null && ownerId != null && ownerId.isNotEmpty) {
        debugPrint(
            'Sheet not found locally, attempting to fetch from Firebase...');

        // Show loading indicator
        final loadingStartTime = DateTime.now();
        final navigatorContext = MyApp.navigatorKey.currentContext;
        if (navigatorContext != null && navigatorContext.mounted) {
          showDialog(
            context: navigatorContext,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              );
            },
          );
        }

        try {
          // Fetch the sheet from Firebase
          final FirestoreService firestoreService = FirestoreService();
          sheet = await firestoreService.getSheet(sheetId, ownerId);

          // Ensure loading dialog shows for at least 500ms to prevent flashing
          final elapsed = DateTime.now().difference(loadingStartTime);
          if (elapsed < const Duration(milliseconds: 500)) {
            await Future.delayed(const Duration(milliseconds: 500) - elapsed);
          }

          // Close loading indicator
          final currentContext = MyApp.navigatorKey.currentContext;
          if (currentContext != null && currentContext.mounted) {
            Navigator.of(currentContext, rootNavigator: true).pop();
          }

          if (sheet != null) {
            debugPrint('Sheet fetched successfully from Firebase');

            // If this is the current user's own sheet, save it to local database
            if (currentUserId != null && ownerId == currentUserId) {
              debugPrint('Saving own sheet to local database');
              await dbHelper.insertSheet(sheet);
            } else {
              debugPrint(
                  'Sheet belongs to another user, loading without saving locally');
            }
          } else {
            debugPrint('Sheet not found in Firebase');
            // Show specific error for not found
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final currentContext = MyApp.navigatorKey.currentContext;
              if (currentContext != null && currentContext.mounted) {
                ToastUtils.showToast('Sheet not found or access denied',
                    isError: true);
              }
            });
          }
        } catch (e) {
          debugPrint('Error fetching sheet from Firebase: $e');
          // Ensure loading dialog shows for at least 500ms
          final elapsed = DateTime.now().difference(loadingStartTime);
          if (elapsed < const Duration(milliseconds: 500)) {
            await Future.delayed(const Duration(milliseconds: 500) - elapsed);
          }
          // Close loading indicator if still open
          final currentContext = MyApp.navigatorKey.currentContext;
          if (currentContext != null && currentContext.mounted) {
            Navigator.of(currentContext, rootNavigator: true).pop();
          }
          // Show specific error
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final currentContext = MyApp.navigatorKey.currentContext;
            if (currentContext != null && currentContext.mounted) {
              ToastUtils.showToast('Failed to load sheet - check connection',
                  isError: true);
            }
          });
        }
      }

      // Ensure navigation happens after the current frame to avoid context issues
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigatorContext = MyApp.navigatorKey.currentContext;
        if (navigatorContext == null || !navigatorContext.mounted) {
          debugPrint(
              'Deep link processing completed (navigator context not available)');
          return;
        }

        if (sheet != null) {
          debugPrint('Navigating to keyboard screen with sheet');
          // Navigate to the keyboard screen with the loaded sheet
          Navigator.pushNamed(
            navigatorContext,
            KeyboardScreen.routeName,
            arguments: sheet,
          );
          debugPrint('Deep link processing completed (navigation successful)');
        } else {
          debugPrint('Sheet could not be loaded');
          // Error messages are already shown above, just navigate to home
          Navigator.pushNamedAndRemoveUntil(
            navigatorContext,
            '/',
            (route) => false,
          );
          debugPrint('Deep link processing completed (navigation to home)');
        }
      });
    } catch (e) {
      debugPrint('Error handling deep link: $e');
      debugPrint('Deep link processing completed (error occurred)');

      // Ensure navigation to home on error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigatorContext = MyApp.navigatorKey.currentContext;
        if (navigatorContext != null && navigatorContext.mounted) {
          ToastUtils.showToast('Cannot open right now', isError: true);
          Navigator.pushNamedAndRemoveUntil(
            navigatorContext,
            '/',
            (route) => false,
          );
        }
      });
    }
  }

  /// Show sign-in prompt for shared sheet access
  void _showSignInPromptForSharedSheet(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Sign in to view a shared sheet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: <Widget>[
            Center(
              child: SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                    Navigator.pushNamed(
                        context, '/login'); // Go to login screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF242038),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Sign In / Sign Up',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Dispose of the link subscription
  void dispose() {
    _linkSubscription?.cancel();
  }
}
