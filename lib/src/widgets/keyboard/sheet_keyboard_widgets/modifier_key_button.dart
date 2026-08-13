import 'package:flutter/material.dart';

class ModifierKeyButton extends StatelessWidget {
  final bool isActive;
  final bool enabled;
  final VoidCallback onPressed;
  final Offset offset;
  final Widget child;

  const ModifierKeyButton({
    super.key,
    required this.isActive,
    required this.onPressed,
    required this.child,
    this.enabled = true,
    this.offset = const Offset(0, 10),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 40,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? Colors.grey[300] : Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.black, width: 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Transform.translate(
          offset: offset,
          child: child,
        ),
      ),
    );
  }
}
