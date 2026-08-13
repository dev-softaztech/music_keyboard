import 'package:flutter/material.dart';

/// The string-selector column (E,B,G,D,A,E) plus the 3 rows of fret number
/// buttons (1-24). Stateless — selection/press results are reported via
/// callbacks and all "is this fret/string current" data comes from the
/// parent as constructor params.
class GuitarFretStringButtons extends StatelessWidget {
  final int selectedStringIndex;
  final String? Function(int stringIndex) fretForString;
  final bool isChordsActive;
  final void Function(int stringIndex) onStringSelected;
  final void Function(int fretNumber) onFretPressed;
  final double techniqueSpacing;

  const GuitarFretStringButtons({
    super.key,
    required this.selectedStringIndex,
    required this.fretForString,
    required this.isChordsActive,
    required this.onStringSelected,
    required this.onFretPressed,
    required this.techniqueSpacing,
  });

  static const List<String> _stringNotes = ['E', 'B', 'G', 'D', 'A', 'E'];

  Widget _buildStringButton(
      BuildContext context, String note, int stringIndex) {
    bool isSelected = selectedStringIndex == stringIndex;
    double buttonWidth = MediaQuery.of(context).size.width * 0.14;

    return Container(
      height: 20,
      width: buttonWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            blurRadius: 5,
            spreadRadius: 0,
            offset: Offset.zero,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => onStringSelected(stringIndex),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue[100] : Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: BorderSide(
                color: isSelected
                    ? Colors.blue
                    : const Color.fromARGB(255, 218, 218, 218),
                width: isSelected ? 2 : 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          note,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFretButton(BuildContext context, int fretNumber) {
    final currentFret = fretForString(selectedStringIndex);
    bool isAssignedToCurrentString = currentFret == fretNumber.toString();
    double buttonWidth = MediaQuery.of(context).size.width * 0.08;
    double marginWidth = MediaQuery.of(context).size.width * 0.01;

    return Container(
      height: 45,
      width: buttonWidth,
      margin: EdgeInsets.symmetric(horizontal: marginWidth),
      child: ElevatedButton(
        onPressed: () => onFretPressed(fretNumber),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isAssignedToCurrentString ? Colors.green[200] : Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: BorderSide(
                color: isAssignedToCurrentString ? Colors.green : Colors.black,
                width: isAssignedToCurrentString ? 2 : 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          fretNumber.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight:
                isAssignedToCurrentString ? FontWeight.bold : FontWeight.normal,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < _stringNotes.length; i++) ...[
              _buildStringButton(context, _stringNotes[i], i),
              if (i != _stringNotes.length - 1) const SizedBox(height: 7),
            ],
          ],
        ),
        SizedBox(width: techniqueSpacing),
        Column(
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                for (int f = 1; f <= 8; f++) _buildFretButton(context, f),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int f = 9; f <= 16; f++) _buildFretButton(context, f),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int f = 17; f <= 24; f++) _buildFretButton(context, f),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
