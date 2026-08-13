import 'package:flutter/material.dart';

class KeyboardScreenToolsMenu extends StatelessWidget {
  const KeyboardScreenToolsMenu({
    super.key,
    required this.showButton,
    required this.showToolsMenu,
    required this.statusBarHeight,
    required this.onToggleToolsMenu,
    required this.onDismiss,
    required this.onTitleTap,
    required this.onAddNewLineTap,
    required this.onTempoTap,
    required this.onRehearsalTap,
    required this.onSelectRowsTap,
    required this.onClipboardTap,
  });

  final bool showButton;
  final bool showToolsMenu;
  final double statusBarHeight;
  final VoidCallback onToggleToolsMenu;
  final VoidCallback onDismiss;
  final VoidCallback onTitleTap;
  final VoidCallback onAddNewLineTap;
  final VoidCallback onTempoTap;
  final VoidCallback onRehearsalTap;
  final VoidCallback onSelectRowsTap;
  final VoidCallback onClipboardTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Floating Tools Menu Button - Top Right
        if (showButton)
          Positioned(
            top: 60,
            right: 5,
            child: GestureDetector(
              onTap: onToggleToolsMenu,
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.black,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.build,
                  color: Color.fromARGB(255, 0, 0, 0),
                  size: 24,
                ),
              ),
            ),
          ),

        if (showToolsMenu)
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismiss,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

        if (showToolsMenu)
          Positioned(
            top: statusBarHeight + 65, // Below the menu button
            right: 15,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: onTitleTap,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        child: const Row(
                          children: [
                            Icon(Icons.title, size: 20, color: Colors.black),
                            SizedBox(width: 8),
                            Text('Title', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: 1,
                      color: Colors.grey[300],
                    ),
                    // Add Button
                    InkWell(
                      onTap: onAddNewLineTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        child: const Row(
                          children: [
                            Icon(Icons.add, size: 20, color: Colors.black),
                            SizedBox(width: 8),
                            Text('Add New Line',
                                style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      height: 1,
                      color: Colors.grey[300],
                    ),
                    // Tempo Button
                    InkWell(
                      onTap: onTempoTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        child: const Row(
                          children: [
                            Icon(Icons.speed, size: 20, color: Colors.black),
                            SizedBox(width: 8),
                            Text('Tempo', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: 1,
                      color: Colors.grey[300],
                    ),
                    // Rehearsal Markings Button
                    InkWell(
                      onTap: onRehearsalTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        child: const Row(
                          children: [
                            Icon(Icons.music_note,
                                size: 20, color: Colors.black),
                            SizedBox(width: 8),
                            Text('Rehearsal', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: 1,
                      color: Colors.grey[300],
                    ),
                    // Select Rows Button
                    InkWell(
                      onTap: onSelectRowsTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        child: const Row(
                          children: [
                            Icon(Icons.check_box_outlined,
                                size: 20, color: Colors.black),
                            SizedBox(width: 8),
                            Text('Select Rows', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: 1,
                      color: Colors.grey[300],
                    ),
                    // Clipboard Button
                    InkWell(
                      onTap: onClipboardTap,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        child: const Row(
                          children: [
                            Icon(Icons.content_paste,
                                size: 20, color: Colors.black),
                            SizedBox(width: 8),
                            Text('Clipboard', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
