import 'package:flutter/material.dart';

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
    return AlertDialog(
      title: const Text('Set Row Spacing'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_currentSpacing.round() - 100}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Slider(
            value: _currentSpacing,
            min: 100.0,
            max: 300.0,
            divisions: 40, // 5px increments
            onChanged: (value) {
              setState(() {
                _currentSpacing = value;
              });
            },
            activeColor: Colors.black,
            inactiveColor: Colors.grey[300],
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
            widget.onSave(_currentSpacing);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
