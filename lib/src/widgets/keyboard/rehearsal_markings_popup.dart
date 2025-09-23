import 'package:flutter/material.dart';

class RehearsalMarkingsPopup extends StatelessWidget {
  final void Function(String) onSave;

  const RehearsalMarkingsPopup({
    super.key,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> rehearsalOptions = [
      '\uE047',
      '\uE048',
      'D.C',
      'D.S.',
      'D.C. al Coda',
      'D.S. al Coda',
      'D.C. al Fine',
      'D.S. al Fine',
      'Fine',
      'To Coda',
    ];

    return AlertDialog(
      title: const Text('Rehearsal Markings'),
      content: SizedBox(
        width: 400,
        height: 260,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 3,
          ),
          itemCount: rehearsalOptions.length,
          itemBuilder: (context, index) {
            final option = rehearsalOptions[index];
            final isUnicode = index <= 1; // first two options are unicode

            return InkWell(
              onTap: () {
                onSave(option);
                Navigator.of(context).pop();
              },
              child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Transform.translate(
                      offset: isUnicode ? Offset(0, 10) : Offset(0, 0),
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: isUnicode ? 24 : 16,
                          fontFamily: isUnicode ? 'Bravura' : null,
                          fontStyle:
                              isUnicode ? FontStyle.normal : FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            onSave(''); // Clear rehearsal marking
            Navigator.of(context).pop();
          },
          child: const Text('Clear'),
        ),
      ],
    );
  }
}
