import 'package:flutter/material.dart';
import 'package:music_keyboard/src/widgets/shared/popup_theme.dart';

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

    return Dialog(
      insetPadding: const EdgeInsets.all(PopupTheme.dialogMargin),
      child: Container(
        width: 450,
        decoration: PopupTheme.dialogDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            PopupTheme.buildHeader(
              title: 'Rehearsal Markings',
              onClose: () => Navigator.of(context).pop(),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(PopupTheme.contentPadding),
              child: SizedBox(
                height: 260,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3,
                  ),
                  itemCount: rehearsalOptions.length,
                  itemBuilder: (context, index) {
                    final option = rehearsalOptions[index];
                    final isUnicode =
                        index <= 1; // first two options are unicode

                    return InkWell(
                      onTap: () {
                        onSave(option);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                          decoration: PopupTheme.gridItemDecoration,
                          child: Center(
                            child: Transform.translate(
                              offset: isUnicode
                                  ? const Offset(0, 10)
                                  : const Offset(0, 0),
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: isUnicode ? 24 : 16,
                                  fontFamily: isUnicode ? 'Bravura' : null,
                                  fontStyle: isUnicode
                                      ? FontStyle.normal
                                      : FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                  color: PopupTheme.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )),
                    );
                  },
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(PopupTheme.actionsPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: PopupTheme.secondaryButtonStyle,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    style: PopupTheme.secondaryButtonStyle,
                    onPressed: () {
                      onSave(''); // Clear rehearsal marking
                      Navigator.of(context).pop();
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
