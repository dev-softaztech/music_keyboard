import 'package:flutter/material.dart';

class IsConnectedProvider extends ChangeNotifier {
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  void toggleConnection(bool value) {
    _isConnected = value;
    notifyListeners();
  }
}
