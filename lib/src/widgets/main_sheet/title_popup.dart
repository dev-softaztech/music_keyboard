import 'package:flutter/material.dart';
import 'package:music_keyboard/src/widgets/shared/popup_theme.dart';

class TitlePopup extends StatefulWidget {
  final Function(String, String) onSave;
  final String initialTitle;
  final String initialComposer;

  const TitlePopup({
    super.key,
    required this.onSave,
    required this.initialTitle,
    required this.initialComposer,
  });

  @override
  _TitlePopupState createState() => _TitlePopupState();
}

class _TitlePopupState extends State<TitlePopup> {
  late TextEditingController _titleController;
  late TextEditingController _composerController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _composerController = TextEditingController(text: widget.initialComposer);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _composerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(PopupTheme.dialogMargin),
      child: Container(
        width: 400,
        decoration: PopupTheme.dialogDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            PopupTheme.buildHeader(
              title: 'Set Title and Composer',
              onClose: () => Navigator.of(context).pop(),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(PopupTheme.contentPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: PopupTheme.inputDecoration.copyWith(
                      hintText: 'Title',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _composerController,
                    decoration: PopupTheme.inputDecoration.copyWith(
                      hintText: 'Composer',
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            PopupTheme.buildActions(
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: () {
                widget.onSave(
                  _titleController.text,
                  _composerController.text,
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
