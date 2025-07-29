import 'package:flutter/material.dart';

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
    return AlertDialog(
      title: const Text('Set Title and Composer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: 'Title',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _composerController,
            decoration: const InputDecoration(
              hintText: 'Composer',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(
              _titleController.text,
              _composerController.text,
            );
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
