class SheetProperties {
  double rowSpacing;
  List<CurlyBraceGroup> curlyBraceGroups;
  String title;
  String composer;

  SheetProperties({
    this.rowSpacing = 140.0,
    List<CurlyBraceGroup>? curlyBraceGroups,
    this.title = '',
    this.composer = '',
  }) : curlyBraceGroups = curlyBraceGroups ?? [];

  /// Updates curly brace groups when rows are inserted at the given index
  void updateCurlyBracesForRowInsertion(int insertionIndex, int rowsAdded) {
    final updatedGroups = <CurlyBraceGroup>[];
    for (final group in curlyBraceGroups) {
      final newStartRow = group.startRow >= insertionIndex
          ? group.startRow + rowsAdded
          : group.startRow;
      final newEndRow = group.endRow >= insertionIndex
          ? group.endRow + rowsAdded
          : group.endRow;
      updatedGroups
          .add(CurlyBraceGroup(startRow: newStartRow, endRow: newEndRow));
    }
    curlyBraceGroups = updatedGroups;
  }

  /// Updates curly brace groups when rows are deleted starting at the given index
  void updateCurlyBracesForRowDeletion(int deletionIndex, int rowsDeleted) {
    final updatedGroups = <CurlyBraceGroup>[];
    for (final group in curlyBraceGroups) {
      // If the group is completely before the deletion point, keep it as is
      if (group.endRow < deletionIndex) {
        updatedGroups.add(group);
      }
      // If the group is completely after the deletion point, shift it left
      else if (group.startRow >= deletionIndex + rowsDeleted) {
        updatedGroups.add(CurlyBraceGroup(
          startRow: group.startRow - rowsDeleted,
          endRow: group.endRow - rowsDeleted,
        ));
      }
      // If the group overlaps with the deleted rows, adjust accordingly
      else {
        final newStartRow =
            group.startRow < deletionIndex ? group.startRow : deletionIndex;
        final newEndRow = group.endRow >= deletionIndex + rowsDeleted
            ? group.endRow - rowsDeleted
            : deletionIndex - 1;

        // Only add the group if it still has valid rows
        if (newStartRow <= newEndRow) {
          updatedGroups.add(CurlyBraceGroup(
            startRow: newStartRow,
            endRow: newEndRow,
          ));
        }
      }
    }
    curlyBraceGroups = updatedGroups;
  }

  Map<String, dynamic> toJson() {
    return {
      'rowSpacing': rowSpacing,
      'curlyBraceGroups':
          curlyBraceGroups.map((group) => group.toJson()).toList(),
      'title': title,
      'composer': composer,
    };
  }

  factory SheetProperties.fromJson(Map<String, dynamic> json) {
    return SheetProperties(
      rowSpacing: json['rowSpacing'] ?? 140.0,
      curlyBraceGroups: (json['curlyBraceGroups'] as List<dynamic>?)
          ?.map((groupJson) => CurlyBraceGroup.fromJson(groupJson))
          .toList(),
      title: json['title'] ?? '',
      composer: json['composer'] ?? '',
    );
  }
}

/// Represents a group of rows that should be connected with a curly brace
class CurlyBraceGroup {
  final int startRow;
  final int endRow;

  CurlyBraceGroup({
    required this.startRow,
    required this.endRow,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CurlyBraceGroup &&
        other.startRow == startRow &&
        other.endRow == endRow;
  }

  @override
  int get hashCode => startRow.hashCode ^ endRow.hashCode;

  Map<String, dynamic> toJson() {
    return {
      'startRow': startRow,
      'endRow': endRow,
    };
  }

  factory CurlyBraceGroup.fromJson(Map<String, dynamic> json) {
    return CurlyBraceGroup(
      startRow: json['startRow'] ?? 0,
      endRow: json['endRow'] ?? 0,
    );
  }
}
