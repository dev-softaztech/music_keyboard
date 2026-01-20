import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/src/screens/keyboard_screen.dart';

class DynamicLinkService {
  static final DynamicLinkService _instance = DynamicLinkService._internal();
  factory DynamicLinkService() => _instance;
  DynamicLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  // TODO: Replace this with your actual Firebase Hosting domain
  // For example: 'https://music-keyboard-app.web.app' or 'https://yourdomain.com'
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
      (Uri uri) {
        _handleDeepLink(context, uri);
      },
      onError: (error) {
        debugPrint('Error listening to deep links: $error');
      },
    );
  }

  /// Handle incoming deep links
  void _handleDeepLink(BuildContext context, Uri uri) {
    debugPrint('Received deep link: $uri');

    // Extract the sheet ID from the query parameters
    final String? sheetId = uri.queryParameters['id'];

    if (sheetId != null) {
      try {
        final int sheetIdInt = int.parse(sheetId);
        // Navigate to the keyboard screen with the sheet ID
        Navigator.pushNamed(
          context,
          KeyboardScreen.routeName,
          arguments: sheetIdInt,
        );
      } catch (e) {
        debugPrint('Error parsing sheet ID: $e');
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
