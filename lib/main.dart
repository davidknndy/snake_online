import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lottie/lottie.dart';

import 'screens/main_menu_screen.dart';
import 'screens/local_game_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/about_screen.dart';
import 'screens/multiplayer_lobby_screen.dart';

import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'services/socket_service.dart';
import 'services/leaderboard_service.dart';
import 'services/audio_service.dart';

import 'utils/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RootApp());
}

class RootApp extends StatefulWidget {
  const RootApp({super.key});

  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  bool _isInitialized = false;
  AuthService? _authService;
  SettingsService? _settingsService;
  SocketService? _socketService;
  LeaderboardService? _leaderboardService;

  @override
  void initState() {
    super.initState();
    _initializeEverything();
  }

  Future<void> _initializeEverything() async {
    // 1. Minimum splash time
    final splashTimer = Future.delayed(const Duration(milliseconds: 3500));

    // 2. Initialize Firebase
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
    }

    // 3. Initialize Services
    _settingsService = SettingsService();
    await _settingsService!.initialize();

    _authService = AuthService();
    await _authService!.initialize();

    _leaderboardService = LeaderboardService();
    await _leaderboardService!.initialize();

    AudioService().initialize(_settingsService!);
    _socketService = SocketService();

    // 4. Wait for the splash timer to finish
    await splashTimer;

    // 5. Update state to show the main app
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      // Return a completely isolated MaterialApp with a Key to prevent element reuse
      return MaterialApp(
        key: const ValueKey('splash_app'),
        debugShowCheckedModeBanner: false,
        theme: SnakeTheme.theme,
        home: Scaffold(
          backgroundColor: SnakeTheme.background,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(
                  'assets/loadinglot.json',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Carregando Snake Online...',
                  style: TextStyle(
                    color: SnakeTheme.accentColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      key: const ValueKey('main_app_providers'),
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: _authService!),
        ChangeNotifierProvider<SettingsService>.value(value: _settingsService!),
        ChangeNotifierProvider<SocketService>.value(value: _socketService!),
        ChangeNotifierProvider<LeaderboardService>.value(value: _leaderboardService!),
      ],
      child: const SnakeOnlineApp(),
    );
  }
}

class SnakeOnlineApp extends StatelessWidget {
  const SnakeOnlineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: const ValueKey('main_material_app'),
      title: 'Snake Online',
      debugShowCheckedModeBanner: false,
      theme: SnakeTheme.theme,
      initialRoute: '/',
      routes: {
        '/': (context) => const MainMenuScreen(),
        '/local-game': (context) => const LocalGameScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/leaderboard': (context) => const LeaderboardScreen(),
        '/about': (context) => const AboutScreen(),
        '/multiplayer-lobby': (context) => const MultiplayerLobbyScreen(),
      },
    );
  }
}
