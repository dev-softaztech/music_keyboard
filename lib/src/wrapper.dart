import 'package:flutter/material.dart';
import 'package:music_keyboard/src/screens/home_screen.dart';
import 'package:music_keyboard/src/services/deep_link_handler.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  final DeepLinkHandler _dynamicLinkService = DeepLinkHandler();

  @override
  void initState() {
    super.initState();
    // Initialize deep link handling after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dynamicLinkService.initDynamicLinks(context);
    });
  }

  @override
  void dispose() {
    _dynamicLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always show the home screen, regardless of auth state
    return const HomeScreen();
  }
}
