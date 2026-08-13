import 'package:flutter/material.dart';
import 'package:music_keyboard/src/widgets/shared/popup_theme.dart';

Future<bool?> showUnsyncedSheetsDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(PopupTheme.dialogMargin),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          decoration: PopupTheme.dialogDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              PopupTheme.buildHeader(
                title: 'Unsynced Sheets',
                onClose: () => Navigator.of(context).pop(false),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(PopupTheme.contentPadding),
                child: Text(
                  'If you sign out some sheets that have not synced will be deleted. Please sign out when you have an internet connection.',
                  style: PopupTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.all(PopupTheme.actionsPadding),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: PopupTheme.secondaryButtonStyle,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: PopupTheme.secondaryButtonStyle.copyWith(
                        foregroundColor: MaterialStateProperty.all(Colors.red),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool?> showDeleteConfirmationDialog(
    BuildContext context, int sheetCount) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(PopupTheme.dialogMargin),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          decoration: PopupTheme.dialogDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              PopupTheme.buildHeader(
                title: 'Confirm Deletion',
                onClose: () => Navigator.of(context).pop(false),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(PopupTheme.contentPadding),
                child: Text(
                  'Are you sure you want to delete $sheetCount sheet${sheetCount != 1 ? 's' : ''}?',
                  style: PopupTheme.bodyStyle,
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.all(PopupTheme.actionsPadding),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: PopupTheme.secondaryButtonStyle,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: PopupTheme.secondaryButtonStyle.copyWith(
                        foregroundColor: MaterialStateProperty.all(Colors.red),
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
