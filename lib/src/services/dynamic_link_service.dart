import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/src/screens/keyboard_screen.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
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
    // Create a simple URL with the sheet ID as a query parameter
    final Uri deepLink = Uri.parse('$_baseUrl/sheet?id=${sheet.id}');
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

    // Extract the sheet ID from the query parameters
    final String? sheetId = uri.queryParameters['id'];

    if (sheetId != null) {
      try {
        final int sheetIdInt = int.parse(sheetId);

        // Load the sheet from the database
        final SheetDatabaseHelper dbHelper = SheetDatabaseHelper();
        final Sheet? sheet = await dbHelper.getSheet(sheetIdInt);

        // Ensure navigation happens after the current frame to avoid context issues
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;

          // Prevent automatic navigation if we've already handled an initial link
          if (_hasHandledInitialLink) {
            debugPrint(
                'Skipping automatic deep link navigation - already handled initial link');
            return;
          }

          if (sheet != null) {
            // Mark that we've handled an initial link to prevent further automatic navigation
            _hasHandledInitialLink = true;

            // Navigate to the keyboard screen with the loaded sheet
            Navigator.pushNamed(
              context,
              KeyboardScreen.routeName,
              arguments: sheet,
            );
          } else {
            debugPrint('Sheet with ID $sheetIdInt not found');
            // Show error message to user and navigate to home screen
            ToastUtils.showToast('Sheet not available', isError: true);
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (route) => false,
            );
          }
        });
      } catch (e) {
        debugPrint('Error parsing sheet ID or loading sheet: $e');
      }
    } else {
      debugPrint('No sheet ID found in deep link');
    }
  }

  /// Dispose of the link subscription
  void dispose() {
    _linkSubscription?.cancel();
  }
}
