import 'package:music_keyboard/models/sheet.dart';

/// Pure sheet-share link generation — no navigation, no UI.
/// For incoming deep link handling and navigation, see [DeepLinkHandler].
class DynamicLinkService {
  static final DynamicLinkService _instance = DynamicLinkService._internal();
  factory DynamicLinkService() => _instance;
  DynamicLinkService._internal();

  static const String _baseUrl = 'https://motez-notes.web.app/';

  /// Creates a deep link URL for sharing a sheet
  /// This generates a simple URL that will be handled by the app
  Future<Uri> createDynamicLink(Sheet sheet) async {
    // Create a URL with both sheet ID and owner's user ID
    final Uri deepLink =
        Uri.parse('$_baseUrl/sheet?id=${sheet.id}&userId=${sheet.userId}');
    return deepLink;
  }
}
