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

  void updateCurlyBracesForRowDeletion(int deletionIndex, int rowsDeleted) {
    final updatedGroups = <CurlyBraceGroup>[];
    for (final group in curlyBraceGroups) {
      if (group.endRow < deletionIndex) {
        updatedGroups.add(group);
      } else if (group.startRow >= deletionIndex + rowsDeleted) {
        updatedGroups.add(CurlyBraceGroup(
          startRow: group.startRow - rowsDeleted,
          endRow: group.endRow - rowsDeleted,
        ));
      } else {
        final newStartRow =
            group.startRow < deletionIndex ? group.startRow : deletionIndex;
        final newEndRow = group.endRow >= deletionIndex + rowsDeleted
            ? group.endRow - rowsDeleted
            : deletionIndex - 1;

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
