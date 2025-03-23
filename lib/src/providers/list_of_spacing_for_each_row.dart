import 'package:flutter/material.dart';

class ListOfSpacingForEachRow extends ChangeNotifier {
  List<int> _rowSpacingList = [26];

  List<int> get rowSpacingList => _rowSpacingList;

  void updateRowSpacingList(List<int> rowSpacingList) {
    _rowSpacingList = rowSpacingList;
    notifyListeners(); // Notify listeners about the change
  }
}
