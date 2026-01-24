import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:music_keyboard/src/services/auth_service.dart';
import 'package:music_keyboard/src/services/sync_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final SyncService _syncService = SyncService();
  User? _user;

  User? get user => _user;

  AuthProvider() {
    _authService.authStateChanges.listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> signIn(String email, String password) async {
    _user = await _authService.signInWithEmailAndPassword(email, password);
    if (_user != null) {
      // Try to sync, but don't fail login if sync fails
      try {
        await _syncService.syncSheets(_user!.uid);
      } catch (e) {
        print('Sync failed after login, but user can continue: $e');
      }
      notifyListeners();
    } else {
      throw Exception('Invalid email or password');
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    _user =
        await _authService.signUpWithEmailAndPassword(email, password, name);
    if (_user != null) {
      await _syncService.uploadLocalSheetsOnLogin(_user!.uid);
      notifyListeners();
    } else {
      throw Exception('Sign up failed. Email may already be in use.');
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}
