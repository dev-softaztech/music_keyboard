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
}
