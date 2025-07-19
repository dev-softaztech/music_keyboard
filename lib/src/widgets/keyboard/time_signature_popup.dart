import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';

class TimeSignaturePopup extends StatefulWidget {
  final void Function(MusicalNote) onTimeSignatureSelected;

  const TimeSignaturePopup({super.key, required this.onTimeSignatureSelected});

  @override
  _TimeSignaturePopupState createState() => _TimeSignaturePopupState();
}

class _TimeSignaturePopupState extends State<TimeSignaturePopup> {
  bool _showCustomSelector = false;

  final List<String> _topUnicodes = [
    '\uF5C9', // 0
    '\uF5CB', // 1
    '\uF5CD', // 2
    '\uF5CF', // 3
    '\uF5D1', // 4
    '\uF5D3', // 5
    '\uF5D5', // 6
    '\uF5D7', // 7
    '\uF5D9', // 8
    '\uF5DB', // 9
  ];

  final List<String> _bottomUnicodes = [
    '\uF5C8', // 0
    '\uF5CA', // 1
    '\uF5CC', // 2
    '\uF5CE', // 3
    '\uF5D0', // 4
    '\uF5D2', // 5
    '\uF5D4', // 6
    '\uF5D6', // 7
    '\uF5D8', // 8
    '\uF5DA', // 9
  ];

  late FixedExtentScrollController _topController;
  late FixedExtentScrollController _bottomController;

  @override
  void initState() {
    super.initState();
    _topController = FixedExtentScrollController(initialItem: 4);
    _bottomController = FixedExtentScrollController(initialItem: 4);
  }

  @override
  void dispose() {
    _topController.dispose();
    _bottomController.dispose();
    super.dispose();
  }

  void _selectTimeSignature(String top, String bottom) {
    widget.onTimeSignatureSelected(
      MusicalNote(
        pitch: "",
        octave: 0,
        type: NoteType.timeSignature,
        isConnected: false,
        topTimeSignatureCharacter: top,
        bottomTimeSignatureCharacter: bottom,
      ),
    );
    Navigator.of(context).pop();
  }

  Widget _buildCommonButton(String top, String bottom, String displayText) {
    return ElevatedButton(
      onPressed: () => _selectTimeSignature(top, bottom),
      child: Text(displayText),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Time Signature'),
      content:
          _showCustomSelector ? _buildCustomSelector() : _buildCommonSelector(),
    );
  }

  Widget _buildCommonSelector() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCommonButton('\uF5D1', '\uF5D0', '4/4'),
        _buildCommonButton('\uF5CF', '\uF5D0', '3/4'),
        _buildCommonButton('\uF5CD', '\uF5D0', '2/4'),
        _buildCommonButton('\uF5D5', '\uF5D8', '6/8'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _showCustomSelector = true;
            });
          },
          child: const Text('Custom'),
        ),
      ],
    );
  }

  Widget _buildCustomSelector() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildWheel(_topController, _topUnicodes),
            const Text('/', style: TextStyle(fontSize: 40)),
            _buildWheel(_bottomController, _bottomUnicodes),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final top = _topUnicodes[_topController.selectedItem];
                final bottom = _bottomUnicodes[_bottomController.selectedItem];
                _selectTimeSignature(top, bottom);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWheel(
      FixedExtentScrollController controller, List<String> items) {
    return SizedBox(
      height: 150,
      width: 80,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 50,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {},
        childDelegate: ListWheelChildLoopingListDelegate(
          children: items
              .map((item) => Center(
                    child: Text(
                      item,
                      style:
                          const TextStyle(fontFamily: 'Bravura', fontSize: 40),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
