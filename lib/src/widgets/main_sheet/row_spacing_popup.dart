import 'package:flutter/material.dart';
import 'package:music_keyboard/src/widgets/shared/popup_theme.dart';

class RowSpacingPopup extends StatefulWidget {
  final Function(double) onSave;
  final double initialSpacing;

  const RowSpacingPopup({
    super.key,
    required this.onSave,
    required this.initialSpacing,
  });

  @override
  _RowSpacingPopupState createState() => _RowSpacingPopupState();
}

class _RowSpacingPopupState extends State<RowSpacingPopup> {
  late double _currentSpacing;

  @override
  void initState() {
    super.initState();
    _currentSpacing = widget.initialSpacing;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(PopupTheme.dialogMargin),
      child: Container(
        width: 350,
        decoration: PopupTheme.dialogDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            PopupTheme.buildHeader(
              title: 'Set Row Spacing',
              onClose: () => Navigator.of(context).pop(),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(PopupTheme.contentPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_currentSpacing.round() - 100}',
                    style: PopupTheme.bodyStyle.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Theme(
                    data: Theme.of(context).copyWith(
                      sliderTheme: PopupTheme.sliderTheme,
                    ),
                    child: Slider(
                      value: _currentSpacing,
                      min: 100.0,
                      max: 300.0,
                      divisions: 40, // 5px increments
                      onChanged: (value) {
                        setState(() {
                          _currentSpacing = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            PopupTheme.buildActions(
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: () {
                widget.onSave(_currentSpacing);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
