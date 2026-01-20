import 'package:flutter/material.dart';
import 'package:music_keyboard/src/screens/home_screen.dart';
import 'package:music_keyboard/src/services/dynamic_link_service.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  final DynamicLinkService _dynamicLinkService = DynamicLinkService();

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
