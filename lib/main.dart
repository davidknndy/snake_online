import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (you'll need to add firebase_options.dart)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Continue without Firebase for now
  }

  // Pre-initialize critical services before launching the widget tree
  final settingsService = SettingsService();
  await settingsService.initialize();

  final authService = AuthService();
  await authService.initialize();

  final leaderboardService = LeaderboardService();
  await leaderboardService.initialize();

  // Initialize audio service with loaded settings
  AudioService().initialize(settingsService);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: settingsService),
        ChangeNotifierProvider(create: (_) => SocketService()),
        ChangeNotifierProvider.value(value: leaderboardService),
      ],
      child: const SnakeOnlineApp(),
    ),
  );
}

class SnakeOnlineApp extends StatelessWidget {
  const SnakeOnlineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
