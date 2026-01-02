import 'package:flutter/material.dart';
import 'package:music_keyboard/models/clipboard_item.dart';
import 'package:music_keyboard/src/database/sheet_database_helper.dart';
import 'package:music_keyboard/src/widgets/shared/popup_theme.dart';
import 'package:intl/intl.dart';

class ClipboardPopup extends StatefulWidget {
  final Function(ClipboardItem)? onPasteItem;

  const ClipboardPopup({
    super.key,
    this.onPasteItem,
  });

  @override
  _ClipboardPopupState createState() => _ClipboardPopupState();
}

class _ClipboardPopupState extends State<ClipboardPopup> {
  List<ClipboardItem> _clipboardItems = [];
  ClipboardItem? _selectedItem;
  bool _isLoading = true;
  final SheetDatabaseHelper _dbHelper = SheetDatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadClipboardItems();
  }

  Future<void> _loadClipboardItems() async {
    try {
      final items = await _dbHelper.getAllClipboardItems();
      setState(() {
        _clipboardItems = items;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading clipboard items: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(ClipboardItem item) {
    setState(() {
      if (_selectedItem == item) {
        _selectedItem = null;
      } else {
        _selectedItem = item;
      }
    });
  }

  Future<void> _deleteItem(ClipboardItem item) async {
    try {
      await _dbHelper.deleteClipboardItem(item.id!);
      setState(() {
        _clipboardItems.remove(item);
        if (_selectedItem == item) {
          _selectedItem = null;
        }
      });
    } catch (e) {
      print('Error deleting clipboard item: $e');
    }
  }

  Future<void> _updateItemName(ClipboardItem item, String newName) async {
    try {
      item.name = newName;
      await _dbHelper.updateClipboardItem(item);
      setState(() {});
    } catch (e) {
      print('Error updating clipboard item name: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(PopupTheme.dialogMargin),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: PopupTheme.dialogDecoration,
        child: Column(
          children: [
            // Header
            PopupTheme.buildHeader(
              title: 'Clipboard',
              onClose: () => Navigator.of(context).pop(),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(PopupTheme.contentPadding),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _clipboardItems.isEmpty
                        ? const Center(
                            child: Text(
                              'No clipboard items',
                              style: TextStyle(color: PopupTheme.textPrimary),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _clipboardItems.length,
                            itemBuilder: (context, index) {
                              final item = _clipboardItems[index];
                              return _buildClipboardItem(item);
                            },
                          ),
              ),
            ),

            // Footer buttons
            Padding(
              padding: const EdgeInsets.all(PopupTheme.actionsPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: PopupTheme.secondaryButtonStyle,
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _selectedItem != null
                        ? () {
                            widget.onPasteItem?.call(_selectedItem!);
                            Navigator.of(context).pop();
                          }
                        : null,
                    style: PopupTheme.primaryButtonStyle.copyWith(
                      backgroundColor: MaterialStateProperty.all(
                        _selectedItem != null ? PopupTheme.accent : Colors.grey,
                      ),
                      foregroundColor: MaterialStateProperty.all(
                        _selectedItem != null
                            ? PopupTheme.primaryBackground
                            : Colors.white,
                      ),
                    ),
                    child: const Text('Paste Row'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClipboardItem(ClipboardItem item) {
    final isSelected = _selectedItem == item;
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? PopupTheme.accent.withOpacity(0.1) : Colors.white,
        border: Border.all(
          color: isSelected ? PopupTheme.accent : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => _toggleSelection(item),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Selection indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? PopupTheme.accent : Colors.grey,
                    width: 2,
                  ),
                  color: isSelected ? PopupTheme.accent : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),

              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name (editable)
                    _buildEditableName(item),
                    const SizedBox(height: 4),
                    // Date
                    Text(
                      dateFormat.format(item.dateCopied),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    // Row count
                    Text(
                      '${item.rows.length} row${item.rows.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Action buttons
              Column(
                children: [
                  // Edit button
                  IconButton(
                    onPressed: () => _startEditingName(item),
                    icon: const Icon(Icons.edit, size: 20),
                    color: Colors.grey.shade600,
                  ),
                  // Delete button
                  IconButton(
                    onPressed: () => _showDeleteConfirmation(item),
                    icon: const Icon(Icons.delete, size: 20),
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableName(ClipboardItem item) {
    return Text(
      item.name,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: PopupTheme.textPrimary,
      ),
    );
  }

  void _startEditingName(ClipboardItem item) {
    final controller = TextEditingController(text: item.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                _updateItemName(item, newName);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(ClipboardItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content:
            const Text('Are you sure you want to delete this clipboard item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteItem(item);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
