import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_keyboard/src/providers/current_selected_note_provider.dart';
import 'package:music_keyboard/src/providers/is_connected_provider.dart';
import 'package:music_keyboard/src/providers/list_of_spacing_for_each_row.dart';
import 'package:music_keyboard/src/providers/row_spacing_provider.dart';
import 'package:music_keyboard/src/providers/select_rows_mode_provider.dart';
import 'package:music_keyboard/src/providers/selected_accidental_provider.dart';
import 'package:music_keyboard/src/providers/selected_number_provider.dart';
import 'package:music_keyboard/src/providers/selected_unicode_provider.dart';
import 'package:music_keyboard/src/providers/undo_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:music_keyboard/firebase_options.dart';
import 'package:music_keyboard/src/providers/auth_provider.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/screens/settings/settings_controller.dart';
import 'src/screens/settings/settings_service.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set preferred orientations to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.white, // Status bar background color
    statusBarIconBrightness: Brightness.dark, // Dark icons for light background
    statusBarBrightness: Brightness.light, // For iOS
  ));

  // Set up the SettingsController, which will glue user settings to multiple
  // Flutter Widgets.
  final settingsController = SettingsController(SettingsService());

  // Load the user's preferred theme while the splash screen is displayed.
  // This prevents a sudden theme change when the app is first displayed.
  await settingsController.loadSettings();

  // Run the app and pass in the SettingsController. The app listens to the
  // SettingsController for changes, then passes it further down to the
  // SettingsView.
  runApp(
    MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => SelectedNumberProvider()),
      ChangeNotifierProvider(create: (_) => SelectedUnicodeProvider()),
      ChangeNotifierProvider(create: (_) => SelectedAccidentalProvider()),
      ChangeNotifierProvider(create: (_) => IsConnectedProvider()),
      ChangeNotifierProvider(create: (_) => CurrentSelectedNoteProvider()),
      ChangeNotifierProvider(create: (_) => ListOfSpacingForEachRow()),
      ChangeNotifierProvider(create: (_) => RowSpacingProvider()),
      ChangeNotifierProvider(create: (_) => SheetUndoManager()),
      ChangeNotifierProvider(create: (_) => SelectRowsModeProvider()),
    ], child: MyApp(settingsController: settingsController)),
  );
}
