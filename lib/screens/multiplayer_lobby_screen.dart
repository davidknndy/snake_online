import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/socket_service.dart';
import '../utils/theme.dart';
import 'multiplayer_game_screen.dart';

enum LobbyState {
  searching,
  matched,
  canceled,
}

class MultiplayerLobbyScreen extends StatefulWidget {
  const MultiplayerLobbyScreen({super.key});

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late AnimationController _matchFoundController;

  LobbyState _state = LobbyState.searching;
  Timer? _searchTimer;
  Timer? _countdownTimer;

  int _searchSeconds = 0;
  int _matchCountdown = 3;

  bool _isRealMatch = false;
  String _opponentName = '';
  int _opponentTrophies = 0;
  int _matchSeed = 0;

  static const List<String> _simulatedOpponents = [
    'Lucas_BR',
    'MariGamer',
    'Pedro_Viper',
    'AnaSilva_99',
    'Rafael_Pro',
    'CobraRei',
    'Vitor_SS',
    'Bia_Gamer',
    'Thiago_Sniper',
    'Camila_Snake',
    'Gabriel_Mestre',
    'Julia_Arena',
  ];

  @override
  void initState() {
    super.initState();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _matchFoundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _startMatchmaking();
  }

  void _startMatchmaking() {
    // Search duration timer
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _searchSeconds++;
        });
      }
    });

    final socketService = Provider.of<SocketService>(context, listen: false);
    final settings = Provider.of<SettingsService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    // Setup listener for real match found on socket server
    socketService.onRealMatchFound = (data) {
      if (!mounted || _state != LobbyState.searching) return;
      _onRealMatchFound(data);
    };

    // Connect to server and enter queue for difficulty
    socketService.connect(serverUrl: settings.serverUrl, user: auth.currentUser).then((_) {
      if (mounted && _state == LobbyState.searching) {
        final diff = _getDifficultyLabel(settings);
        socketService.findRealMatch(difficulty: diff, user: auth.currentUser);
      }
    });
  }

  void _onRealMatchFound(Map<String, dynamic> data) {
    _searchTimer?.cancel();
    _radarController.stop();

    final opponent = data['opponent'] as Map<String, dynamic>?;
    final oppName = opponent?['name']?.toString() ?? 'Adversário Online';
    final oppTrophies = int.tryParse(opponent?['trophies']?.toString() ?? '') ?? 0;
    final seed = int.tryParse(data['matchSeed']?.toString() ?? '') ??
        DateTime.now().millisecondsSinceEpoch;

    setState(() {
      _state = LobbyState.matched;
      _isRealMatch = true;
      _opponentName = oppName;
      _opponentTrophies = oppTrophies;
      _matchSeed = seed;
    });

    _matchFoundController.forward();
    _startCountdownTransition();
  }

  void _startBotMatch() {
    if (!mounted || _state != LobbyState.searching) return;
    _searchTimer?.cancel();
    _radarController.stop();

    final socketService = Provider.of<SocketService>(context, listen: false);
    socketService.cancelMatchmaking();

    final settings = Provider.of<SettingsService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final random = math.Random();
    final candidateName =
        _simulatedOpponents[random.nextInt(_simulatedOpponents.length)];
    final playerTrophies = auth.currentUser?.trophies ?? settings.trophies;
    final opponentTrophies =
        (playerTrophies + random.nextInt(15) - 6).clamp(0, 9999);

    setState(() {
      _state = LobbyState.matched;
      _isRealMatch = false;
      _opponentName = '$candidateName (Bot)';
      _opponentTrophies = opponentTrophies;
      _matchSeed = DateTime.now().millisecondsSinceEpoch;
    });

    _matchFoundController.forward();
    _startCountdownTransition();
  }

  void _startCountdownTransition() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_matchCountdown > 1) {
        setState(() {
          _matchCountdown--;
        });
      } else {
        timer.cancel();
        _navigateToGame();
      }
    });
  }

  void _navigateToGame() {
    if (!mounted) return;
    final settings = Provider.of<SettingsService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final playerName = auth.currentUser?.name ?? 'Jogador';
    final initialSpeedIndex = settings.gameSpeed == SettingsService.speedVeryFast
        ? 2
        : (settings.gameSpeed == SettingsService.speedFast ? 1 : 0);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MultiplayerGameScreen(
          playerName: playerName,
          opponentName: _opponentName,
          opponentTrophies: _opponentTrophies,
          initialSpeedIndex: initialSpeedIndex,
          matchSeed: _matchSeed,
          isRealMatch: _isRealMatch,
        ),
      ),
    );
  }

  void _cancelMatchmaking() {
    _searchTimer?.cancel();
    _countdownTimer?.cancel();

    final socketService = Provider.of<SocketService>(context, listen: false);
    socketService.onRealMatchFound = null;
    if (socketService.isConnected) {
      socketService.cancelMatchmaking();
    }

    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _countdownTimer?.cancel();
    _radarController.dispose();
    _pulseController.dispose();
    _matchFoundController.dispose();
    final socketService = Provider.of<SocketService>(context, listen: false);
    socketService.onRealMatchFound = null;
    super.dispose();
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String _getDifficultyLabel(SettingsService settings) {
    if (settings.gameSpeed == SettingsService.speedVeryFast) return 'Muito Difícil';
    if (settings.gameSpeed == SettingsService.speedFast) return 'Difícil';
    return 'Normal';
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    final auth = Provider.of<AuthService>(context);
    final playerName = auth.currentUser?.name ?? 'Jogador';
    final playerTrophies = auth.currentUser?.trophies ?? settings.trophies;
    final difficulty = _getDifficultyLabel(settings);

    return Scaffold(
      backgroundColor: SnakeTheme.background,
      appBar: AppBar(
        backgroundColor: SnakeTheme.darkGreen,
        iconTheme: const IconThemeData(color: SnakeTheme.textPrimary),
        title: Text(
          'Lobby Multiplayer',
          style: GoogleFonts.pressStart2p(
            fontSize: 13,
            color: SnakeTheme.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancelMatchmaking,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // Header: Selected Difficulty badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: SnakeTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SnakeTheme.lightGreen, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.speed, color: SnakeTheme.accentColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Dificuldade:',
                          style: GoogleFonts.pressStart2p(
                            fontSize: 10,
                            color: SnakeTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: SnakeTheme.primaryGreen.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        difficulty,
                        style: GoogleFonts.pressStart2p(
                          fontSize: 10,
                          color: SnakeTheme.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Server Status Indicator
              Consumer<SocketService>(
                builder: (context, socket, _) {
                  final isOnline = socket.isConnected;
                  final isConnecting = socket.isConnecting;
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? SnakeTheme.primaryGreen.withValues(alpha: 0.15)
                          : (isConnecting
                              ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                              : const Color(0xFFD32F2F).withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isOnline
                            ? SnakeTheme.lightGreen
                            : (isConnecting
                                ? const Color(0xFFFFD700)
                                : const Color(0xFFD32F2F)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline
                                ? SnakeTheme.lightGreen
                                : (isConnecting
                                    ? const Color(0xFFFFD700)
                                    : const Color(0xFFEF5350)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOnline
                              ? 'Servidor Conectado • Fila Online Ativa'
                              : (isConnecting
                                  ? 'Conectando ao servidor...'
                                  : 'Servidor Offline (Tentando reconectar...)'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isOnline
                                ? SnakeTheme.lightGreen
                                : (isConnecting
                                    ? const Color(0xFFFFD700)
                                    : const Color(0xFFEF5350)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Spacer(),

              // Center Content: Radar / Search vs Match Found Card
              if (_state == LobbyState.searching) ...[
                _buildRadarAnimation(),
                const SizedBox(height: 24),
                Text(
                  'BUSCANDO OPONENTE...',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 13,
                    color: SnakeTheme.accentColor,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Procurando jogador na dificuldade $difficulty',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: SnakeTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: SnakeTheme.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SnakeTheme.lightGreen.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, color: SnakeTheme.accentColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Tempo na Fila: ${_formatTime(_searchSeconds)}',
                        style: GoogleFonts.pressStart2p(
                          fontSize: 9,
                          color: SnakeTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_searchSeconds >= 10) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: SnakeTheme.cardBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: SnakeTheme.accentColor.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Aguardando outro jogador entrar na fila...',
                          style: TextStyle(color: SnakeTheme.textSecondary, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: _startBotMatch,
                          icon: const Icon(Icons.smart_toy_outlined, color: SnakeTheme.accentColor, size: 16),
                          label: const Text(
                            'Jogar contra Bot de Treino agora',
                            style: TextStyle(
                              color: SnakeTheme.accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else if (_state == LobbyState.matched) ...[
                _buildVsMatchCard(playerName, playerTrophies, difficulty),
              ],

              const Spacer(),

              // Player Info Card
              _buildPlayerInfoCard(playerName, playerTrophies),

              const SizedBox(height: 14),

              // Action buttons (only while searching)
              if (_state == LobbyState.searching) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startBotMatch,
                    icon: const Icon(Icons.smart_toy_rounded, color: Colors.black, size: 20),
                    label: const Text(
                      'JOGAR CONTRA BOT (TREINO)',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SnakeTheme.accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _cancelMatchmaking,
                    icon: const Icon(Icons.cancel_outlined, color: Colors.white, size: 18),
                    label: const Text(
                      'CANCELAR BUSCA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: SnakeTheme.lightGreen, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadarAnimation() {
    return AnimatedBuilder(
      animation: _radarController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse circle 1
            Container(
              width: 190 + (_pulseController.value * 25),
              height: 190 + (_pulseController.value * 25),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: SnakeTheme.accentColor.withValues(alpha: 0.25 - (_pulseController.value * 0.15)),
                  width: 2,
                ),
              ),
            ),
            // Middle circle
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: SnakeTheme.lightGreen.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
            ),
            // Radar sweeping line canvas
            CustomPaint(
              size: const Size(140, 140),
              painter: _RadarPainter(rotation: _radarController.value * 2 * math.pi),
            ),
            // Center glowing icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SnakeTheme.darkGreen,
                border: Border.all(color: SnakeTheme.accentColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: SnakeTheme.accentColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.public,
                color: SnakeTheme.accentColor,
                size: 32,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVsMatchCard(String playerName, int playerTrophies, String difficulty) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _matchFoundController,
        curve: Curves.elasticOut,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: SnakeTheme.accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: SnakeTheme.accentColor, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: SnakeTheme.accentColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'PARTIDA ENCONTRADA!',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 11,
                    color: SnakeTheme.accentColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // VS Banner Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SnakeTheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SnakeTheme.lightGreen, width: 2),
              boxShadow: [
                BoxShadow(
                  color: SnakeTheme.primaryGreen.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Player 1
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SnakeTheme.darkGreen,
                          border: Border.all(color: SnakeTheme.lightGreen, width: 2),
                        ),
                        child: const Icon(Icons.person, color: SnakeTheme.lightGreen, size: 30),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        playerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SnakeTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '🏆 $playerTrophies',
                        style: const TextStyle(
                          color: SnakeTheme.accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // VS Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFD700), width: 2),
                  ),
                  child: Text(
                    'VS',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 16,
                      color: const Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Opponent
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0D47A1),
                          border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                        ),
                        child: const Icon(Icons.person_outline, color: Color(0xFF00E5FF), size: 30),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _opponentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SnakeTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '🏆 $_opponentTrophies',
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Countdown banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: SnakeTheme.darkGreen,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SnakeTheme.lightGreen),
            ),
            child: Text(
              'Iniciando em $_matchCountdown...',
              style: GoogleFonts.pressStart2p(
                fontSize: 11,
                color: SnakeTheme.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerInfoCard(String playerName, int playerTrophies) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SnakeTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SnakeTheme.lightGreen.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: SnakeTheme.primaryGreen,
            ),
            child: const Icon(Icons.person, color: SnakeTheme.textPrimary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playerName,
                  style: const TextStyle(
                    color: SnakeTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '🏆 $playerTrophies Troféus',
                  style: const TextStyle(
                    color: SnakeTheme.accentColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: SnakeTheme.darkGreen,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: SnakeTheme.accentColor,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Online',
                  style: TextStyle(
                    color: SnakeTheme.accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double rotation;

  _RadarPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Crosshairs
    final gridPaint = Paint()
      ..color = SnakeTheme.lightGreen.withValues(alpha: 0.25)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), gridPaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), gridPaint);

    // Rotating sweep
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          SnakeTheme.accentColor.withValues(alpha: 0.5),
          SnakeTheme.accentColor.withValues(alpha: 0.0),
        ],
        transform: GradientRotation(rotation),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);

    // Leading ray
    final rayPaint = Paint()
      ..color = SnakeTheme.accentColor.withValues(alpha: 0.9)
      ..strokeWidth = 2.0;

    final rayEnd = Offset(
      center.dx + radius * math.cos(rotation),
      center.dy + radius * math.sin(rotation),
    );
    canvas.drawLine(center, rayEnd, rayPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}

