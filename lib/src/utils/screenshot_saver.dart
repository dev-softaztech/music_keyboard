import 'dart:typed_data';
import 'dart:io';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

Future<void> saveImageToGallery(Uint8List imageBytes) async {
  try {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/sheet_music.png');
    await tempFile.writeAsBytes(imageBytes);
    await Gal.putImage(tempFile.path);
  } catch (e) {
    print("Error saving image: $e");
  }
}
