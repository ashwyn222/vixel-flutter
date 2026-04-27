import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Service to handle user authentication with Firebase
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  User? _user;
  bool _isLoading = false;
  String? _error;

  // Getters
  User? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get userId => _user?.uid;
  String? get userEmail => _user?.email;
  String? get displayName => _user?.displayName;
  String? get photoUrl => _user?.photoURL;

  /// Initialize the auth service and listen to auth state changes
  Future<void> init() async {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
    
    // Check current user
    _user = _auth.currentUser;
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Trigger Google sign-in flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled sign-in
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Get Google auth credentials
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      _user = userCredential.user;
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Sign-in failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);

      _user = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Sign-out failed. Please try again.';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Permanently delete the current Firebase user.
  ///
  /// If Firebase requires a fresh login (`requires-recent-login`), the user
  /// is silently re-authenticated through Google before retrying once.
  /// Returns `true` on success, `false` on cancel / failure.
  Future<bool> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          final ok = await _reauthenticateWithGoogle();
          if (!ok) {
            _error = 'Please sign in again to confirm account deletion.';
            _isLoading = false;
            notifyListeners();
            return false;
          }
          await _auth.currentUser!.delete();
        } else {
          rethrow;
        }
      }

      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      _user = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete account. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Re-run Google sign-in and reauthenticate the current Firebase user.
  Future<bool> _reauthenticateWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.currentUser!.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear any error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Convert Firebase error codes to user-friendly messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'operation-not-allowed':
        return 'Google sign-in is not enabled. Please contact support.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found. Please sign up first.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }
}
