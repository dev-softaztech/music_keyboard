import 'package:flutter/material.dart';

class ListOfSpacingForEachRow extends ChangeNotifier {
  List<double> _rowSpacingList = [26];

  List<double> get rowSpacingList => _rowSpacingList;

  void updateRowSpacingList(List<double> rowSpacingList) {
    _rowSpacingList = rowSpacingList;
    notifyListeners(); // Notify listeners about the change
  }
}
