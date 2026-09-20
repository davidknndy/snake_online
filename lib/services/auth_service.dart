import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart' as app_models;

class AuthService extends ChangeNotifier {
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  app_models.User? _currentUser;
  bool _isLoading = false;
  String? _error;

  // Getters
  app_models.User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  // Initialize auth state
  Future<void> initialize() async {
    _setLoading(true);
    
    // Listen to auth state changes
    _firebaseAuth.authStateChanges().listen((firebase_auth.User? firebaseUser) {
      if (firebaseUser != null) {
        _updateCurrentUser(firebaseUser);
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });

    // Check if user is already signed in
    final firebase_auth.User? firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser != null) {
      _updateCurrentUser(firebaseUser);
    }
    
    _setLoading(false);
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      _clearError();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        _setLoading(false);
        return false;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final firebase_auth.UserCredential userCredential = 
          await _firebaseAuth.signInWithCredential(credential);

      if (userCredential.user != null) {
        _updateCurrentUser(userCredential.user!);
        _setLoading(false);
        return true;
      }
      
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to sign in with Google: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _setLoading(true);
      _clearError();

      await Future.wait([
        _firebaseAuth.signOut(),
        _googleSignIn.signOut(),
      ]);

      _currentUser = null;
      _setLoading(false);
    } catch (e) {
      _setError('Failed to sign out: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Update user profile (after game results, etc.)
  Future<void> updateUserStats({
    required int trophyChange,
    required bool gameWon,
  }) async {
    if (_currentUser == null) return;

    try {
      final updatedUser = _currentUser!.copyWith(
        trophies: _currentUser!.trophies + trophyChange,
        gamesPlayed: _currentUser!.gamesPlayed + 1,
        gamesWon: gameWon ? _currentUser!.gamesWon + 1 : _currentUser!.gamesWon,
        lastSeen: DateTime.now(),
      );

      _currentUser = updatedUser;
      notifyListeners();

      // TODO: Update user data on backend/Firebase
      // await _updateUserInDatabase(updatedUser);
    } catch (e) {
      _setError('Failed to update user stats: ${e.toString()}');
    }
  }

  // Reset user stats
  Future<void> resetUserStats() async {
    if (_currentUser == null) return;
    try {
      _currentUser = _currentUser!.copyWith(
        trophies: 0,
        gamesPlayed: 0,
        gamesWon: 0,
        lastSeen: DateTime.now(),
      );
      notifyListeners();
    } catch (e) {
      _setError('Failed to reset user stats: ${e.toString()}');
    }
  }

  // Convert Firebase user to app user model
  void _updateCurrentUser(firebase_auth.User firebaseUser) {
    _currentUser = app_models.User(
      id: firebaseUser.uid,
      name: firebaseUser.displayName ?? 'Unknown Player',
      email: firebaseUser.email ?? '',
      photoUrl: firebaseUser.photoURL,
      trophies: 0, // TODO: Load from backend
      gamesPlayed: 0, // TODO: Load from backend  
      gamesWon: 0, // TODO: Load from backend
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      lastSeen: DateTime.now(),
    );
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Delete account (if needed)
  Future<bool> deleteAccount() async {
    try {
      _setLoading(true);
      _clearError();

      final firebase_auth.User? user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.delete();
        await _googleSignIn.signOut();
        _currentUser = null;
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to delete account: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Check if user needs to re-authenticate
  bool get needsReauth {
    final user = _firebaseAuth.currentUser;
    if (user?.metadata.lastSignInTime == null) return false;
    
    final lastSignIn = user!.metadata.lastSignInTime!;
    final daysSinceSignIn = DateTime.now().difference(lastSignIn).inDays;
    
    return daysSinceSignIn > 30; // Re-auth if signed in more than 30 days ago
  }
}
