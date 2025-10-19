import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/widgets/shared/popup_theme.dart';

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
    '\uF5CB\uF5C9', // 10
    '\uF5CB\uF5CB', // 11
    '\uF5CB\uF5CD', // 12
    '\uF5CB\uF5CF', // 13
    '\uF5CB\uF5D1', // 14
    '\uF5CB\uF5D3', // 15
    '\uF5CB\uF5D5', // 16
    '\uF5CB\uF5D7', // 17
    '\uF5CB\uF5D9', // 18
    '\uF5CB\uF5DB', // 19
    '\uF5CD\uF5C9', // 20
  ];

  //Using bottom unicodes with the index to reference _topUnicodes as top unicodes get cut off in horizontal wheel.
  final List<String> _topUnicodesForHorizontalWheel = [
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
    '\uF5CA\uF5C8', // 10
    '\uF5CA\uF5CA', // 11
    '\uF5CA\uF5CC', // 12
    '\uF5CA\uF5CE', // 13
    '\uF5CA\uF5D0', // 14
    '\uF5CA\uF5D2', // 15
    '\uF5CA\uF5D4', // 16
    '\uF5CA\uF5D6', // 17
    '\uF5CA\uF5D8', // 18
    '\uF5CA\uF5DA', // 19
    '\uF5CC\uF5C8', // 20
  ];

  final List<String> _bottomUnicodes = [
    '\uF5CA', // 1
    '\uF5CC', // 2
    '\uF5D0', // 4
    '\uF5D8', // 8
    '\uF5CA\uF5D4', // 16
    '\uF5CE\uF5CC', // 32
  ];

  late PageController _topController;
  late PageController _bottomController;
  int _selectedTopIndex = 4;
  int _selectedBottomIndex = 4;

  @override
  void initState() {
    super.initState();
    _topController = PageController(initialPage: 4, viewportFraction: 0.3);
    _bottomController = PageController(initialPage: 4, viewportFraction: 0.3);
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
        pitch: "D",
        octave: 5,
        type: NoteType.timeSignature,
        isBeamed: false,
        topTimeSignatureCharacter: top,
        bottomTimeSignatureCharacter: bottom,
      ),
    );
    Navigator.of(context).pop();
  }

  Widget _buildCommonButton(String top, String bottom, String displayText) {
    return SizedBox(
      width: 80,
      height: 70,
      child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: PopupTheme.primaryBackground,
            foregroundColor: PopupTheme.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: PopupTheme.borderColor),
            ),
            padding: EdgeInsets.zero,
          ),
          onPressed: () => _selectTimeSignature(top, bottom),
          child: top == '\uE08A'
              ? Transform.translate(
                  offset: const Offset(0, 0),
                  child: Text(
                    top,
                    style: const TextStyle(
                      color: PopupTheme.textPrimary,
                      fontSize: 50,
                      fontFamily: 'Bravura',
                    ),
                  ),
                )
              : Column(
                  children: [
                    Transform.translate(
                      offset: const Offset(0, 25),
                      child: Text(
                        top,
                        style: const TextStyle(
                          color: PopupTheme.textPrimary,
                          fontSize: 40,
                          fontFamily: 'Bravura',
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -32),
                      child: Text(
                        bottom,
                        style: const TextStyle(
                          color: PopupTheme.textPrimary,
                          fontSize: 40,
                          fontFamily: 'Bravura',
                        ),
                      ),
                    ),
                  ],
                )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(PopupTheme.dialogMargin),
      child: Container(
        decoration: PopupTheme.dialogDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            PopupTheme.buildHeader(
              title: 'Select Time Signature',
              onClose: () => Navigator.of(context).pop(),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(PopupTheme.contentPadding),
              child: _showCustomSelector
                  ? _buildCustomSelector()
                  : _buildCommonSelector(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommonSelector() {
    return SizedBox(
      height: 220,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCommonButton('\uE08A', '', 'c'),
              const SizedBox(width: 5),
              _buildCommonButton('\uF5D1', '\uF5D0', '4/4'),
              const SizedBox(width: 5),
              _buildCommonButton('\uF5CF', '\uF5D0', '3/4'),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 5),
              _buildCommonButton('\uF5CD', '\uF5D0', '2/4'),
              const SizedBox(width: 5),
              _buildCommonButton('\uF5D5', '\uF5D8', '6/8'),
              const SizedBox(width: 5),
              _buildCommonButton('\uF5CB\uF5CD', '\uF5D8', '12/8'),
            ],
          ),
          const SizedBox(height: 15),
          ElevatedButton(
              style: PopupTheme.primaryButtonStyle,
              onPressed: () {
                setState(() {
                  _showCustomSelector = true;
                });
              },
              child: const Text('CUSTOM')),
        ],
      ),
    );
  }

  Widget _buildCustomSelector() {
    return SizedBox(
      width: 200, // Constrain the width of the dialog content
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 60,
                child: Column(
                  children: [
                    _buildHorizontalWheel(
                        _topController, _topUnicodesForHorizontalWheel,
                        (index) {
                      setState(() {
                        _selectedTopIndex = index;
                      });
                    }),
                    _buildHorizontalWheel(_bottomController, _bottomUnicodes,
                        (index) {
                      setState(() {
                        _selectedBottomIndex = index;
                      });
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    style: PopupTheme.secondaryButtonStyle,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: PopupTheme.primaryButtonStyle,
                    onPressed: () {
                      final top = _topUnicodes[_selectedTopIndex];
                      final bottom = _bottomUnicodes[_selectedBottomIndex];
                      _selectTimeSignature(top, bottom);
                    },
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ],
          ),
/*
          // 🔷 Line overlay
          Positioned(
            left: 95, // adjust: slightly left of center (200 / 2 = 100)
            top: 0,
            bottom: null,
            child: Container(
              width: 1,
              height: 70, // only cover top half of 60
              color: Colors.black,
            ),
          ),
          Positioned(
            right: 95, // adjust: slightly left of center (200 / 2 = 100)
            top: 0,
            bottom: null,
            child: Container(
              width: 1,
              height: 70, // only cover top half of 60
              color: Colors.black,
            ),
          ),*/
          Positioned(
              left: 1, // adjust: slightly left of center (200 / 2 = 100)
              top: 0,
              bottom: null,
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  width: 95,
                  height: 70, // only cover top half of 60
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(112, 200, 200, 200),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
              )),
          Positioned(
            right: 1, // adjust: slightly left of center (200 / 2 = 100)
            top: 0,
            bottom: null,
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                width: 95,
                height: 70, // only cover top half of 60
                decoration: BoxDecoration(
                  color: const Color.fromARGB(112, 200, 200, 200),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHorizontalWheel(PageController controller, List<String> items,
      void Function(int) onPageChanged) {
    return SizedBox(
      height: 30,
      child: PageView.builder(
        controller: controller,
        scrollDirection: Axis.horizontal,
        onPageChanged: onPageChanged,
        itemCount: items.length,
        itemBuilder: (context, index) {
          return Center(
            child: Text(
              items[index],
              style: const TextStyle(fontFamily: 'Bravura', fontSize: 40),
            ),
          );
        },
      ),
    );
  }
}
