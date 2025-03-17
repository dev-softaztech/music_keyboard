import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';

class ToastUtils {
  /// Displays a toast with the given message.
  static void showToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? Colors.red : Colors.black,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }
}
