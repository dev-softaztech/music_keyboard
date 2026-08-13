import 'package:flutter/material.dart';
import 'package:music_keyboard/src/widgets/shared/pdf_export_loading_overlay.dart';

class LoadingOverlayController {
  OverlayEntry? _entry;

  void show(BuildContext context) {
    remove();

    _entry = OverlayEntry(
      builder: (context) => const PdfExportLoadingOverlay(),
    );

    Overlay.of(context).insert(_entry!);
  }

  void remove() {
    _entry?.remove();
    _entry = null;
  }
}
