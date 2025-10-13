import 'package:music_keyboard/models/sheet_properties.dart';
import 'package:music_keyboard/models/sheet_rows.dart';

class Sheet {
  List<SheetRows> sheetRows;
  SheetProperties sheetProperties;

  Sheet({required this.sheetRows, required this.sheetProperties});
}
