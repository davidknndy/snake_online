import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart' as app_models;

class AuthService extends ChangeNotifier {
  static const String _prefIsLoggedIn = 'auth_is_logged_in';
  static const String _prefUserId = 'auth_user_id';
  static const String _prefUserName = 'auth_user_name';
  static const String _prefUserEmail = 'auth_user_email';
  static const String _prefUserPhoto = 'auth_user_photo';
  static const String _prefUserTrophies = 'auth_user_trophies';
  static const String _prefUserGamesPlayed = 'auth_user_games_played';
  static const String _prefUserGamesWon = 'auth_user_games_won';

  firebase_auth.FirebaseAuth? get _safeFirebaseAuth {
    try {
      return firebase_auth.FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

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
    
    // 1. First, restore user from local storage immediately if previously logged in
    await _loadUserFromPrefs();

    // 2. Listen to Firebase auth state changes if Firebase is available
    final fb = _safeFirebaseAuth;
    if (fb != null) {
      try {
        fb.authStateChanges().listen((firebase_auth.User? firebaseUser) {
          if (firebaseUser != null) {
            _updateCurrentUser(firebaseUser);
            if (_currentUser != null) {
              _saveUserToPrefs(_currentUser!);
            }
          }
        });

        final firebase_auth.User? firebaseUser = fb.currentUser;
        if (firebaseUser != null) {
          _updateCurrentUser(firebaseUser);
          if (_currentUser != null) {
            _saveUserToPrefs(_currentUser!);
          }
        }
      } catch (e) {
        debugPrint('Firebase auth listener initialization error: $e');
      }
    }

    // 3. If user was previously logged in, ensure GoogleSignIn is kept in sync silently
    if (_currentUser != null) {
      try {
        await _googleSignIn.signInSilently();
      } catch (e) {
        debugPrint('Google silent sign in error: $e');
      }
    }
    
    _setLoading(false);
  }

  // Sign in with Google
  // [forceAccountChooser]: forces Google to display the account picker modal
  Future<bool> signInWithGoogle({bool forceAccountChooser = false}) async {
    try {
      _setLoading(true);
      _clearError();

      if (forceAccountChooser) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled / dismissed the sign-in modal
        _setLoading(false);
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final localTrophies = prefs.getInt('player_trophies') ?? 0;

      // Try Firebase authentication if Firebase is initialized
      final fb = _safeFirebaseAuth;
      if (fb != null) {
        try {
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          final credential = firebase_auth.GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          final firebase_auth.UserCredential userCredential = 
              await fb.signInWithCredential(credential);

          if (userCredential.user != null) {
            _updateCurrentUser(userCredential.user!);
            if (_currentUser != null) {
              await _saveUserToPrefs(_currentUser!);
            }
            _setLoading(false);
            return true;
          }
        } catch (fbError) {
          debugPrint('Firebase auth failed, falling back to Google account directly: $fbError');
        }
      }

      // Fallback directly to GoogleSignInAccount profile
      _currentUser = app_models.User(
        id: googleUser.id,
        name: googleUser.displayName ?? 'Jogador',
        email: googleUser.email,
        photoUrl: googleUser.photoUrl,
        trophies: _currentUser?.trophies ?? localTrophies,
        gamesPlayed: 0,
        gamesWon: 0,
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      await _saveUserToPrefs(_currentUser!);
      notifyListeners();
      _setLoading(false);
      return true;
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

      await _clearUserPrefs();

      try {
        await _safeFirebaseAuth?.signOut();
      } catch (_) {}

      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      _currentUser = null;
      _setLoading(false);
      notifyListeners();
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
        trophies: (_currentUser!.trophies + trophyChange).clamp(0, 999999),
        gamesPlayed: _currentUser!.gamesPlayed + 1,
        gamesWon: gameWon ? _currentUser!.gamesWon + 1 : _currentUser!.gamesWon,
        lastSeen: DateTime.now(),
      );

      _currentUser = updatedUser;
      await _saveUserToPrefs(updatedUser);
      notifyListeners();
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
      await _saveUserToPrefs(_currentUser!);
      notifyListeners();
    } catch (e) {
      _setError('Failed to reset user stats: ${e.toString()}');
    }
  }

  // Convert Firebase user to app user model
  void _updateCurrentUser(firebase_auth.User firebaseUser) {
    final previousTrophies = _currentUser?.trophies ?? 0;
    _currentUser = app_models.User(
      id: firebaseUser.uid,
      name: firebaseUser.displayName ?? 'Jogador',
      email: firebaseUser.email ?? '',
      photoUrl: firebaseUser.photoURL,
      trophies: previousTrophies,
      gamesPlayed: _currentUser?.gamesPlayed ?? 0,
      gamesWon: _currentUser?.gamesWon ?? 0,
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      lastSeen: DateTime.now(),
    );
    notifyListeners();
  }

  // Save user credentials to local SharedPreferences
  Future<void> _saveUserToPrefs(app_models.User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefIsLoggedIn, true);
      await prefs.setString(_prefUserId, user.id);
      await prefs.setString(_prefUserName, user.name);
      await prefs.setString(_prefUserEmail, user.email);
      if (user.photoUrl != null) {
        await prefs.setString(_prefUserPhoto, user.photoUrl!);
      } else {
        await prefs.remove(_prefUserPhoto);
      }
      await prefs.setInt(_prefUserTrophies, user.trophies);
      await prefs.setInt(_prefUserGamesPlayed, user.gamesPlayed);
      await prefs.setInt(_prefUserGamesWon, user.gamesWon);
    } catch (e) {
      debugPrint('Error saving user to SharedPreferences: $e');
    }
  }

  // Load user credentials from local SharedPreferences
  Future<void> _loadUserFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_prefIsLoggedIn) ?? false;
      if (isLoggedIn) {
        final id = prefs.getString(_prefUserId);
        final name = prefs.getString(_prefUserName);
        final email = prefs.getString(_prefUserEmail) ?? '';
        final photo = prefs.getString(_prefUserPhoto);
        final trophies = prefs.getInt(_prefUserTrophies) ?? 
            (prefs.getInt('player_trophies') ?? 0);
        final gamesPlayed = prefs.getInt(_prefUserGamesPlayed) ?? 0;
        final gamesWon = prefs.getInt(_prefUserGamesWon) ?? 0;

        if (id != null && name != null) {
          _currentUser = app_models.User(
            id: id,
            name: name,
            email: email,
            photoUrl: photo,
            trophies: trophies,
            gamesPlayed: gamesPlayed,
            gamesWon: gamesWon,
            createdAt: DateTime.now(),
            lastSeen: DateTime.now(),
          );
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error loading user from SharedPreferences: $e');
    }
  }

  // Clear user credentials on logout
  Future<void> _clearUserPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefIsLoggedIn, false);
      await prefs.remove(_prefUserId);
      await prefs.remove(_prefUserName);
      await prefs.remove(_prefUserEmail);
      await prefs.remove(_prefUserPhoto);
      await prefs.remove(_prefUserTrophies);
      await prefs.remove(_prefUserGamesPlayed);
      await prefs.remove(_prefUserGamesWon);
    } catch (e) {
      debugPrint('Error clearing user from SharedPreferences: $e');
    }
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

      await _clearUserPrefs();
      final user = _safeFirebaseAuth?.currentUser;
      if (user != null) {
        await user.delete();
      }
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      _currentUser = null;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete account: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Check if user needs to re-authenticate
  bool get needsReauth {
    final user = _safeFirebaseAuth?.currentUser;
    if (user?.metadata.lastSignInTime == null) return false;
    
    final lastSignIn = user!.metadata.lastSignInTime!;
    final daysSinceSignIn = DateTime.now().difference(lastSignIn).inDays;
    
    return daysSinceSignIn > 30; // Re-auth if signed in more than 30 days ago
  }
}
