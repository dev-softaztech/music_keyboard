import 'package:flutter/material.dart';
import 'package:music_keyboard/models/sheet.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/models/keyboard_type.dart';
import 'package:music_keyboard/src/widgets/home/sheet_preview_painter.dart';
import 'package:intl/intl.dart';

class SheetPreviewCard extends StatelessWidget {
  final Sheet sheet;
  final VoidCallback onTap;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onShare;

  const SheetPreviewCard({
    super.key,
    required this.sheet,
    required this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    // Extract first 5 notes (excluding clefs and other non-note elements)
    final List<MusicalNote> previewNotes = _extractPreviewNotes();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue[50] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Music preview section
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: CustomPaint(
                      painter: SheetPreviewPainter(
                        notes: previewNotes,
                        backgroundColor:
                            isSelected ? Colors.blue[50]! : Colors.white,
                        lineColor: Colors.black,
                      ),
                    ),
                  ),
                ),
                // Sheet info section
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue[100] : Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (sheet.sheetProperties.title ?? '').trim().isNotEmpty
                            ? sheet.sheetProperties.title!.trim()
                            : 'Untitled',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF242038),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(sheet.lastUpdated),
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        sheet.keyboardType.displayName,
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isSelectionMode)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          if (!isSelectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.share),
                onPressed: onShare,
              ),
            ),
        ],
      ),
    );
  }

  List<MusicalNote> _extractPreviewNotes() {
    final List<MusicalNote> notes = [];

    // Get notes from the first row
    if (sheet.sheetRows.isEmpty) {
      return notes;
    }

    final firstRow = sheet.sheetRows[0];

    // Extract up to 5 actual notes (excluding clefs, bars, etc.)
    for (final note in firstRow.notes) {
      // Skip clefs, bars, time signatures, key signatures
      if (note.type == NoteType.clef ||
          note.type == NoteType.bar ||
          note.type == NoteType.timeSignature ||
          note.type == NoteType.keySignature ||
          note.type == NoteType.space) {
        continue;
      }

      notes.add(note);

      // Stop after collecting 5 notes
      if (notes.length >= 5) {
        break;
      }
    }

    return notes;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
