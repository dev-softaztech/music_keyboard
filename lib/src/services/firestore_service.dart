import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:music_keyboard/models/sheet.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addSheet(Sheet sheet, String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('sheets')
        .doc(sheet.id.toString())
        .set(sheet.toJson());
  }

  Future<void> updateSheet(Sheet sheet, String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('sheets')
        .doc(sheet.id.toString())
        .update(sheet.toJson());
  }

  Future<void> deleteSheet(int sheetId, String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('sheets')
        .doc(sheetId.toString())
        .delete();
  }

  Future<Sheet?> getSheet(int sheetId, String userId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('sheets')
          .doc(sheetId.toString())
          .get();

      if (doc.exists) {
        return Sheet.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting sheet from Firebase: $e');
      return null;
    }
  }

  Stream<List<Sheet>> getSheets(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('sheets')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Sheet.fromJson(doc.data())).toList());
  }
}
