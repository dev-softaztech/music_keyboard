import 'package:flutter/material.dart';
import 'package:music_keyboard/src/widgets/shared/popup_theme.dart';

class BarPopupContent extends StatelessWidget {
  const BarPopupContent({
    super.key,
    required this.unicodeOptions,
    required this.onOptionSelected,
  });

  final List<String> unicodeOptions;
  final void Function(String unicode) onOptionSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemCount: unicodeOptions.length,
      itemBuilder: (context, index) {
        final unicode = unicodeOptions[index];
        return InkWell(
          onTap: () => onOptionSelected(unicode),
          child: Container(
            decoration: PopupTheme.gridItemDecoration,
            child: Center(
                child: Transform.translate(
              offset: const Offset(0, 20),
              child: Text(
                unicode,
                style: const TextStyle(
                  fontFamily: 'Bravura',
                  fontSize: 40,
                  color: PopupTheme.textPrimary,
                ),
              ),
            )),
          ),
        );
      },
    );
  }
}

class BarPopupOverlay {
  OverlayEntry? _entry;

  static const List<String> unicodeOptions = [
    '',
    '',
    '',
    '',
    '',
    '',
  ];

  void show(BuildContext context, {required void Function(String) onSelected}) {
    remove();

    final screenSize = MediaQuery.of(context).size;
    const double popupWidth = 200.0;
    const double buttonSize = 80.0;
    const int crossAxisCount = 3;
    final int rowCount = (unicodeOptions.length / crossAxisCount).ceil();
    final double popupHeight = (buttonSize * rowCount) + 32.0;

    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: remove,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: (screenSize.width - popupWidth) / 2,
            bottom: 85,
            child: Material(
              elevation: 0,
              borderRadius: BorderRadius.circular(PopupTheme.borderRadius),
              child: Container(
                padding: const EdgeInsets.all(PopupTheme.standardPadding),
                decoration: PopupTheme.dialogDecoration,
                width: popupWidth,
                height: popupHeight,
                child: BarPopupContent(
                  unicodeOptions: unicodeOptions,
                  onOptionSelected: (unicode) {
                    onSelected(unicode);
                    remove();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_entry!);
  }

  void remove() {
    _entry?.remove();
    _entry = null;
  }
}
