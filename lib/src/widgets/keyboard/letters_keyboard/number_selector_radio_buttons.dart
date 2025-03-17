import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_keyboard/src/providers/selected_number_provider.dart';

class NumberSelectorRadioButtons extends StatelessWidget {
  const NumberSelectorRadioButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SelectedNumberProvider>(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(8, (index) {
        final number = index + 1;
        final isSelected = provider.selectedNumber == number;

        return GestureDetector(
          onTap: () {
            provider.updateSelectedNumber(number);
          },
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 4),
            width: 30,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? Colors.orange[700] : Colors.orange[300],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.orange[900]! : Colors.orange[500]!,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }),
    );
  }
}
