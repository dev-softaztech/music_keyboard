class SheetProperties {
  double rowSpacing;
  List<CurlyBraceGroup> curlyBraceGroups;

  SheetProperties({
    this.rowSpacing = 140.0,
    List<CurlyBraceGroup>? curlyBraceGroups,
  }) : curlyBraceGroups = curlyBraceGroups ?? [];
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
