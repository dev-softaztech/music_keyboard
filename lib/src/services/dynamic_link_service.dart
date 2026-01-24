import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/src/screens/keyboard_screen.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
import 'package:music_keyboard/src/services/firestore_service.dart';
import 'package:music_keyboard/src/utils/toast_utils.dart';

class DynamicLinkService {
  static final DynamicLinkService _instance = DynamicLinkService._internal();
  factory DynamicLinkService() => _instance;
  DynamicLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  // Flag to prevent multiple automatic navigations from deep links
  bool _hasHandledInitialLink = false;

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
    try {
      final Uri? initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(context, initialLink);
      }
    } catch (e) {
      debugPrint('Error handling initial link: $e');
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

    // Prevent automatic navigation if we've already handled an initial link
    if (_hasHandledInitialLink) {
      debugPrint(
          'Skipping automatic deep link navigation - already handled initial link');
      return;
    }

    // Mark that we've handling an initial link
    _hasHandledInitialLink = true;

    try {
      // Get current user to check if this is their own sheet
      final User? currentUser = FirebaseAuth.instance.currentUser;
      final String? currentUserId = currentUser?.uid;

      // First, try to load the sheet from the local database
      final SheetDatabaseHelper dbHelper = SheetDatabaseHelper();
      Sheet? sheet = await dbHelper.getSheet(sheetId);

      // If sheet not found locally and we have an owner ID, try fetching from Firebase
      if (sheet == null && ownerId != null && ownerId.isNotEmpty) {
        debugPrint(
            'Sheet not found locally, attempting to fetch from Firebase...');

        // Show loading indicator
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            },
          );
        }

        try {
          // Fetch the sheet from Firebase
          final FirestoreService firestoreService = FirestoreService();
          sheet = await firestoreService.getSheet(sheetId, ownerId);

          // Close loading indicator
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
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
          }
        } catch (e) {
          debugPrint('Error fetching sheet from Firebase: $e');
          // Close loading indicator if still open
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }
      }

      // Ensure navigation happens after the current frame to avoid context issues
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;

        if (sheet != null) {
          // Navigate to the keyboard screen with the loaded sheet
          Navigator.pushNamed(
            context,
            KeyboardScreen.routeName,
            arguments: sheet,
          );
        } else {
          debugPrint('Sheet could not be loaded');
          // Show error message to user
          ToastUtils.showToast('Cannot open right now', isError: true);
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/',
            (route) => false,
          );
        }
      });
    } catch (e) {
      debugPrint('Error handling deep link: $e');
      // Ensure navigation to home on error
      if (context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ToastUtils.showToast('Cannot open right now', isError: true);
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/',
            (route) => false,
          );
        });
      }
    }
  }

  /// Dispose of the link subscription
  void dispose() {
    _linkSubscription?.cancel();
  }
}
