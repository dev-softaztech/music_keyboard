import 'package:flutter/material.dart';

class RowSpacingProvider extends ChangeNotifier {
  double _rowSpacing = 160.0; // Default spacing

  double get rowSpacing => _rowSpacing;

  void updateBetweenRowSpacing(double spacing) {
    _rowSpacing = spacing;
    notifyListeners(); // Notify listeners about the change
  }
}
