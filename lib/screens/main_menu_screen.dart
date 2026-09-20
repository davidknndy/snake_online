import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/menu_widgets.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../utils/theme.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _fadeController.forward();
    _slideController.forward();
    
    // Start background music only if enabled
    AudioService().startBackgroundMusic();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<bool> _showExitDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: SnakeTheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: SnakeTheme.lightGreen, width: 2),
          ),
          title: const Row(
            children: [
              Icon(Icons.exit_to_app, color: SnakeTheme.accentColor),
              SizedBox(width: 8),
              Text(
                'Sair do Jogo',
                style: TextStyle(
                  color: SnakeTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'Tem certeza que deseja sair?',
            style: TextStyle(color: SnakeTheme.textSecondary, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  color: SnakeTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Sair',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _onPlayOnline() {
    Navigator.pushNamed(context, '/multiplayer-lobby');
  }

  void _onPlayLocal() {
    Navigator.pushNamed(context, '/local-game');
  }

  void _onLeaderboard() {
    Navigator.pushNamed(context, '/leaderboard');
  }

  void _onSettings() {
    Navigator.pushNamed(context, '/settings');
  }

  void _onAbout() {
    Navigator.pushNamed(context, '/about');
  }

  void _onGoogleSignIn() {
    _triggerGoogleSignIn();
  }

  Future<void> _triggerGoogleSignIn() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    if (authService.isAuthenticated) {
      // User is already signed in, show sign out option
      _showSignOutDialog();
      return;
    }

    // Force account chooser so user can choose account
    final success = await authService.signInWithGoogle(forceAccountChooser: true);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bem-vindo, ${authService.currentUser?.name ?? 'Jogador'}!'),
          backgroundColor: SnakeTheme.primaryGreen,
        ),
      );
    } else if (mounted && authService.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.error!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSignOutDialog() {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final authService = Provider.of<AuthService>(context, listen: false);
        return AlertDialog(
          backgroundColor: SnakeTheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: SnakeTheme.lightGreen, width: 2),
          ),
          title: const Text(
            'Desconectar',
            style: TextStyle(
              color: SnakeTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Tem certeza de que deseja se desconectar?',
            style: TextStyle(color: SnakeTheme.textSecondary, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  color: SnakeTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await authService.signOut();
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Desconectado com sucesso'),
                      backgroundColor: SnakeTheme.primaryGreen,
                    ),
                  );
                }
              },
              child: const Text(
                'Desconectar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final shouldExit = await _showExitDialog();
        if (shouldExit && mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                SnakeTheme.background,
                SnakeTheme.darkGreen,
              ],
            ),
          ),
          child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                          child: Column(
                            children: [
                              // Title section
                              const SizedBox(height: 8),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const RetroTitle(title: 'SNAKE'),
                                    const SizedBox(height: 4),
                                    Text(
                                      'ONLINE',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                        color: SnakeTheme.accentColor,
                                        letterSpacing: 4.0,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Retro snake visual element
                                    Container(
                                      height: 4,
                                      width: 180,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        gradient: const LinearGradient(
                                          colors: [
                                            SnakeTheme.primaryGreen,
                                            SnakeTheme.lightGreen,
                                            SnakeTheme.accentColor,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Menu buttons section
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    MenuButton(
                                      text: 'JOGAR ONLINE',
                                      icon: Icons.public,
                                      isPrimary: true,
                                      onPressed: _onPlayOnline,
                                    ),
                                    MenuButton(
                                      text: 'JOGAR LOCAL',
                                      icon: Icons.person,
                                      onPressed: _onPlayLocal,
                                    ),
                                    MenuButton(
                                      text: 'CLASSIFICAÇÃO',
                                      icon: Icons.emoji_events,
                                      onPressed: _onLeaderboard,
                                    ),
                                    MenuButton(
                                      text: 'CONFIGURAÇÕES',
                                      icon: Icons.settings,
                                      onPressed: _onSettings,
                                    ),
                                    MenuButton(
                                      text: 'SOBRE',
                                      icon: Icons.info_outline,
                                      onPressed: _onAbout,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Login section
                              Consumer<AuthService>(
                                builder: (context, authService, child) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Divider(
                                        color: SnakeTheme.lightGreen,
                                        thickness: 1,
                                        indent: 40,
                                        endIndent: 40,
                                      ),
                                      const SizedBox(height: 12),
                                      if (authService.isLoading)
                                        const CircularProgressIndicator(
                                          color: SnakeTheme.accentColor,
                                        )
                                      else
                                        Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.symmetric(horizontal: 20),
                                          child: OutlinedButton.icon(
                                            onPressed: _onGoogleSignIn,
                                            icon: Icon(
                                              authService.isAuthenticated 
                                                  ? Icons.logout 
                                                  : Icons.login,
                                              color: SnakeTheme.textPrimary,
                                            ),
                                            label: Text(
                                              authService.isAuthenticated
                                                  ? 'DESCONECTAR'
                                                  : 'ENTRAR COM GOOGLE',
                                              style: const TextStyle(
                                                color: SnakeTheme.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              side: BorderSide(
                                                color: authService.isAuthenticated 
                                                    ? SnakeTheme.lightGreen 
                                                    : SnakeTheme.accentColor,
                                                width: 2,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 6),
                                      Text(
                                        authService.isAuthenticated
                                            ? 'Bem-vindo, ${authService.currentUser?.name ?? 'Jogador'}!'
                                            : 'Entre para competir online e acompanhar seu progresso',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: SnakeTheme.textSecondary.withValues(alpha: 0.8),
                                          fontSize: 12,
                                        ),
                                      ),
                                      Consumer<SettingsService>(
                                        builder: (context, settings, _) {
                                          final trophies = authService.isAuthenticated
                                              ? (authService.currentUser?.trophies ?? 0)
                                              : settings.trophies;
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              '🏆 $trophies Troféus',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: SnakeTheme.accentColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
