import 'package:music_keyboard/models/sheet_properties.dart';
import 'package:music_keyboard/models/sheet_rows.dart';
import 'package:music_keyboard/models/sheet_format.dart';

class Sheet {
  List<SheetRows> sheetRows;
  SheetProperties sheetProperties;
  SheetFormat format;

  Sheet({
    required this.sheetRows,
    required this.sheetProperties,
    this.format = SheetFormat.single,
  });
}
