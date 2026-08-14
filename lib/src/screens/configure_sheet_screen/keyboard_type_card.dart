import 'package:flutter/material.dart';
import 'package:music_keyboard/models/keyboard_type.dart';

class KeyboardTypeCard extends StatelessWidget {
  const KeyboardTypeCard({
    super.key,
    required this.keyboardType,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.isDisabled = false,
  });

  final KeyboardType keyboardType;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1.0,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF242038) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF242038) : Colors.grey[300]!,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: isSelected ? Colors.white : const Color(0xFF242038),
                ),
                const SizedBox(height: 6),
                Text(
                  keyboardType.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        isSelected ? Colors.white : const Color(0xFF242038),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  keyboardType.description,
                  style: TextStyle(
                    fontSize: 9,
                    color: isSelected
                        ? Colors.white.withOpacity(0.8)
                        : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
