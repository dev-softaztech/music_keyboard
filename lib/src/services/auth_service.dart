import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  bool get isEmailVerified => _firebaseAuth.currentUser?.emailVerified ?? false;

  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _firebaseAuth.signInWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } catch (e) {
      throw e;
    }
  }

  Future<User?> signUpWithEmailAndPassword(
      String email, String password, String name) async {
    try {
      UserCredential result = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Update the user's display name
      await result.user?.updateProfile(displayName: name);
      // Reload the user to get updated profile
      await result.user?.reload();

      return _firebaseAuth.currentUser;
    } catch (e) {
      throw e;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// Send email verification to the current user
  Future<void> sendEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      throw e;
    }
  }

  /// Send password reset email to the specified email address
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw e;
    }
  }

  /// Reload the current user to get updated information (e.g., email verification status)
  Future<void> reloadUser() async {
    try {
      await _firebaseAuth.currentUser?.reload();
    } catch (e) {
      throw e;
    }
  }

  /// Verify and apply email verification code
  Future<void> applyActionCode(String code) async {
    try {
      await _firebaseAuth.applyActionCode(code);
    } catch (e) {
      throw e;
    }
  }

  /// Check the validity of an action code
  Future<ActionCodeInfo> checkActionCode(String code) async {
    try {
      return await _firebaseAuth.checkActionCode(code);
    } catch (e) {
      throw e;
    }
  }

  /// Confirm password reset with code and new password
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    try {
      await _firebaseAuth.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );
    } catch (e) {
      throw e;
    }
  }
}
