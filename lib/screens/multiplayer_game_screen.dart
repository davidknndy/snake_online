import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/snake_model.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/leaderboard_service.dart';
import '../services/settings_service.dart';
import '../utils/theme.dart';
import '../widgets/game_board.dart';
import '../widgets/game_controls.dart';
import '../widgets/gesture_whiteboard.dart';

import '../services/socket_service.dart';

class MultiplayerGameScreen extends StatefulWidget {
  final String playerName;
  final String opponentName;
  final int opponentTrophies;
  final int initialSpeedIndex;
  final int matchSeed;
  final bool isRealMatch;

  const MultiplayerGameScreen({
    super.key,
    required this.playerName,
    required this.opponentName,
    required this.opponentTrophies,
    required this.initialSpeedIndex,
    required this.matchSeed,
    this.isRealMatch = false,
  });

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _moveController;
  late AnimationController _countdownAnimController;

  late GameState _gameState;
  Timer? _matchTimer;
  Timer? _announcementTimer;
  Timer? _introCountdownTimer;
  Timer? _opponentSimTimer;

  int _introCountdown = 3; // 3, 2, 1, 0 (Go!)
  bool _isIntroActive = true;
  DateTime? _introStartTime;
  DateTime _lastStepTime = DateTime.now();

  int _remainingSeconds = 120; // 2 minutes
  int _currentStage = 0;
  bool _isOvertime = false;
  int _overtimeSeconds = 0;
  int _surgeCount = 0;
  String? _speedAnnouncement;

  // Opponent live state
  int _opponentLength = 3;
  int _opponentApples = 0;
  bool _opponentCrashed = false;
  int _opponentCrashTimeSeconds = 999;

  bool _isExitDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final initialDuration = SettingsService.getSpeedForStage(
      widget.initialSpeedIndex,
      0,
    );

    _moveController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: initialDuration),
    );

    _countdownAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _moveController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!_isIntroActive && _gameState.status == GameStatus.playing) {
          _updateGame();
          _lastStepTime = DateTime.now();
          if (_gameState.status == GameStatus.playing) {
            _moveController.forward(from: 0.0);
          }
        }
      }
    });

    if (widget.isRealMatch) {
      final socketService = Provider.of<SocketService>(context, listen: false);
      if (socketService.gameId != null) {
        socketService.reconnectGame(socketService.gameId!);
      }
      socketService.onOpponentAppleEaten = (data) {
        if (!mounted || _gameState.status != GameStatus.playing) return;
        setState(() {
          _opponentApples = (data['apples'] as num?)?.toInt() ?? (_opponentApples + 1);
          _opponentLength = (data['length'] as num?)?.toInt() ?? (_opponentLength + 1);
        });
      };
      socketService.onOpponentCrashed = (data) {
        if (!mounted || _gameState.status != GameStatus.playing) return;
        _handleOpponentCrashed();
      };
      socketService.onOpponentLeft = () {
        if (!mounted || _gameState.status != GameStatus.playing) return;
        _handleOpponentCrashed();
      };
    } else {
      // Seed opponent survival lifetime based on difficulty for bot practice
      final rand = Random(widget.matchSeed);
      final baseMin = widget.initialSpeedIndex == 2
          ? 75
          : (widget.initialSpeedIndex == 1 ? 65 : 50);
      _opponentCrashTimeSeconds = baseMin + rand.nextInt(70);
    }

    _initializeGame();
    _startIntroCountdown();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  void _handleAppResumed() {
    if (!mounted) return;

    if (widget.isRealMatch) {
      final socketService = Provider.of<SocketService>(context, listen: false);
      if (socketService.gameId != null) {
        socketService.reconnectGame(socketService.gameId!);
      }
    }

    if (_gameState.status != GameStatus.playing && !_isIntroActive) {
      return;
    }

    final now = DateTime.now();

    // If app was minimized during intro countdown
    if (_isIntroActive && _introStartTime != null) {
      final introElapsedMs = now.difference(_introStartTime!).inMilliseconds;
      if (introElapsedMs >= 3000) {
        _introCountdownTimer?.cancel();
        _introCountdown = 0;
        _isIntroActive = false;
        _gameState = _gameState.copyWith(status: GameStatus.playing);
        _startMatchTimer();
        if (!widget.isRealMatch) {
          _startOpponentSimulation();
        }
        final gamePlayElapsedMs = introElapsedMs - 3000;
        _lastStepTime = now.subtract(Duration(milliseconds: gamePlayElapsedMs));
      } else {
        return;
      }
    }

    // Catch up snake movement for the time spent in background
    final elapsedMs = now.difference(_lastStepTime).inMilliseconds;
    final stepMs = _moveController.duration?.inMilliseconds ?? 280;

    if (stepMs > 0 && elapsedMs >= stepMs) {
      final missedSteps = elapsedMs ~/ stepMs;

      for (int i = 0; i < missedSteps; i++) {
        _updateGame();
        _lastStepTime = DateTime.now();
        if (_gameState.status != GameStatus.playing) {
          // Snake crashed into wall or itself during background simulation!
          return;
        }
      }

      // Catch up match timer
      final elapsedSec = elapsedMs ~/ 1000;
      if (elapsedSec > 0) {
        if (!_isOvertime) {
          _remainingSeconds = (_remainingSeconds - elapsedSec).clamp(0, 120);
        } else {
          _overtimeSeconds += elapsedSec;
        }
      }

      _lastStepTime = DateTime.now();
      _moveController.forward(from: 0.0);
    }
  }

  void _initializeGame() {
    final settings = Provider.of<SettingsService>(context, listen: false);

    // Pause background music during online match
    AudioService().pauseBackgroundMusic();

    final initialSpeed = SettingsService.getSpeedForStage(
      widget.initialSpeedIndex,
      0,
    );

    _gameState = GameState.initial(
      mode: GameMode.online,
      gridWidth: settings.gridSize,
      gridHeight: settings.gridSize,
      gameSpeed: initialSpeed,
    ).copyWith(
      status: GameStatus.waiting,
      matchSeed: widget.matchSeed,
    );

    // Seed initial synchronized foods
    final initialFoods = _generateInitialFoods(widget.matchSeed);
    _gameState = _gameState.copyWith(foods: initialFoods);
  }

  List<Position> _generateInitialFoods(int seed) {
    final rand = Random(seed);
    final List<Position> foods = [];
    final int innerWidth = (_gameState.gridWidth - 2).clamp(1, _gameState.gridWidth);
    final int innerHeight = (_gameState.gridHeight - 2).clamp(1, _gameState.gridHeight);

    while (foods.length < 3) {
      final pos = Position(
        1 + rand.nextInt(innerWidth),
        1 + rand.nextInt(innerHeight),
      );
      if (!_gameState.playerSnake.body.contains(pos) && !foods.contains(pos)) {
        foods.add(pos);
      }
    }
    return foods;
  }

  Position _generateFoodWithSeed(Random rand) {
    final int innerWidth = (_gameState.gridWidth - 2).clamp(1, _gameState.gridWidth);
    final int innerHeight = (_gameState.gridHeight - 2).clamp(1, _gameState.gridHeight);
    Position newFood;
    int attempts = 0;
    do {
      newFood = Position(
        1 + rand.nextInt(innerWidth),
        1 + rand.nextInt(innerHeight),
      );
      attempts++;
    } while ((_gameState.playerSnake.body.contains(newFood) ||
            _gameState.foods.contains(newFood)) &&
        attempts < 100);
    return newFood;
  }

  void _startIntroCountdown() {
    _introStartTime = DateTime.now();
    _countdownAnimController.forward(from: 0.0);
    AudioService().playDirectionChange();

    _introCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_introCountdown > 1) {
          _introCountdown--;
          _countdownAnimController.forward(from: 0.0);
          AudioService().playDirectionChange();
        } else {
          _introCountdown = 0;
          _isIntroActive = false;
          _gameState = _gameState.copyWith(status: GameStatus.playing);
          timer.cancel();

          AudioService().playVictory();
          _startMatchTimer();
          if (!widget.isRealMatch) {
            _startOpponentSimulation();
          }
          _lastStepTime = DateTime.now();
          _moveController.forward(from: 0.0);
        }
      });
    });
  }

  void _startMatchTimer() {
    _matchTimer?.cancel();
    _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_gameState.status != GameStatus.playing) return;

      setState(() {
        if (!_isOvertime) {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;

            // 5s advance warning
            if (_remainingSeconds == 95 || _remainingSeconds == 65 || _remainingSeconds == 35) {
              _showAdvanceWarningNotification('A cobra ficará mais rápida em 5s!');
            } else if (_remainingSeconds == 5) {
              _showAdvanceWarningNotification('Fim dos 2 minutos em 5s!');
            }

            // 30s stage progression
            final elapsed = 120 - _remainingSeconds;
            final newStage = (elapsed ~/ 30).clamp(0, 3);
            if (newStage > _currentStage) {
              _currentStage = newStage;
              final newSpeed = SettingsService.getSpeedForStage(
                widget.initialSpeedIndex,
                _currentStage,
              );
              _moveController.duration = Duration(milliseconds: newSpeed);
              final stageName = SettingsService.getSpeedNameForStage(
                widget.initialSpeedIndex,
                _currentStage,
              );
              _showSpeedStageNotification(stageName);
              AudioService().playDirectionChange();
            }

            // Every 3 seconds, a synchronized apple surges on the board
            if (elapsed > 0 && elapsed % 3 == 0) {
              _surgeNewApple();
            }

            // Check if opponent crashes by survival time (bot mode only)
            if (!widget.isRealMatch && elapsed >= _opponentCrashTimeSeconds && !_opponentCrashed) {
              _opponentCrashed = true;
              _handleOpponentCrashed();
              return;
            }
          }

          if (_remainingSeconds <= 0) {
            // Match time completed! Check who has the bigger snake or points!
            _evaluateTwoMinuteWinner();
          }
        } else {
          // Overtime counting up (maximum 60 seconds overtime -> 3 minutes total)
          _overtimeSeconds++;

          if (_overtimeSeconds == 55) {
            _showAdvanceWarningNotification('Fim dos 3 minutos em 5s!');
          }

          if (_overtimeSeconds % 3 == 0) {
            _surgeNewApple();
          }

          // Overtime opponent crash chance (bot mode only)
          if (!widget.isRealMatch && _overtimeSeconds >= 20 && !_opponentCrashed) {
            final rand = Random();
            if (rand.nextInt(10) < 3) {
              _opponentCrashed = true;
              _handleOpponentCrashed();
              return;
            }
          }

          // At 3 minutes (120s + 60s overtime = 180s total)
          if (_overtimeSeconds >= 60) {
            _evaluateThreeMinuteLimit();
          }
        }
      });
    });
  }

  void _startOpponentSimulation() {
    _opponentSimTimer?.cancel();
    final rand = Random(widget.matchSeed + 777);
    _opponentSimTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || _gameState.status != GameStatus.playing) return;
      if (rand.nextBool()) {
        setState(() {
          _opponentApples++;
          _opponentLength++;
        });
      }
    });
  }

  void _surgeNewApple() {
    _surgeCount++;
    if (_gameState.foods.length >= 6) return;

    final rand = Random(widget.matchSeed + (_surgeCount * 1337));
    final newFood = _generateFoodWithSeed(rand);

    if (!_gameState.foods.contains(newFood)) {
      final updated = List<Position>.from(_gameState.foods)..add(newFood);
      setState(() {
        _gameState = _gameState.copyWith(foods: updated);
      });
    }
  }

  void _updateGame() {
    if (_gameState.status != GameStatus.playing) return;

    int growthAmount = 1;
    int pointsGained = 10;

    if (_isOvertime) {
      growthAmount = 3;
      pointsGained = 30;
    } else {
      final elapsed = 120 - _remainingSeconds;
      if (elapsed >= 60) {
        growthAmount = 2;
        pointsGained = 15;
      }
    }

    // Move snake
    _gameState.playerSnake.move(_gameState.food, growthAmount: growthAmount);

    bool gameOver = false;

    // Wall collision
    if (_gameState.playerSnake.checkWallCollision(
      _gameState.gridWidth,
      _gameState.gridHeight,
    )) {
      gameOver = true;
    }

    // Self collision
    if (_gameState.playerSnake.checkSelfCollision()) {
      gameOver = true;
    }

    // Check food collision
    final int eatenIndex =
        _gameState.foods.indexWhere((f) => f == _gameState.playerSnake.head);
    final bool foodEaten = eatenIndex != -1;
    int newScore = _gameState.playerScore;
    List<Position> updatedFoods = List<Position>.from(_gameState.foods);

    if (foodEaten) {
      newScore += pointsGained;
      updatedFoods.removeAt(eatenIndex);

      if (updatedFoods.isEmpty) {
        final rand = Random();
        updatedFoods.add(_generateFoodWithSeed(rand));
      }

      AudioService().playEatFood();

      if (widget.isRealMatch) {
        final socketService = Provider.of<SocketService>(context, listen: false);
        socketService.sendAppleEaten(
          apples: _gameState.applesEaten + 1,
          length: _gameState.playerSnake.body.length,
          score: newScore,
        );
      }

      final bool nextIsGolden = _isOvertime ||
          (DateTime.now().millisecond % ((120 - _remainingSeconds >= 60) ? 3 : 5) == 0);

      setState(() {
        _gameState = _gameState.copyWith(
          status: gameOver ? GameStatus.gameOver : GameStatus.playing,
          playerScore: newScore,
          foods: updatedFoods,
          isGoldenFood: nextIsGolden,
          applesEaten: _gameState.applesEaten + 1,
        );
      });
    } else {
      setState(() {
        _gameState = _gameState.copyWith(
          status: gameOver ? GameStatus.gameOver : GameStatus.playing,
        );
      });
    }

    if (gameOver) {
      _handlePlayerCrashed();
    }
  }

  void _onDirectionChange(Direction direction) {
    if (_gameState.status == GameStatus.playing && !_isIntroActive) {
      _gameState.playerSnake.nextDirection = direction;
      AudioService().playDirectionChange();
    }
  }

  // --- End Game Handlers ---

  void _handlePlayerCrashed() {
    _matchTimer?.cancel();
    _opponentSimTimer?.cancel();
    _moveController.stop();

    if (widget.isRealMatch) {
      final socketService = Provider.of<SocketService>(context, listen: false);
      socketService.sendPlayerCrashed();
    }

    setState(() {
      _gameState = _gameState.copyWith(status: GameStatus.gameOver);
    });

    AudioService().playGameOver();
    _applyTrophyResult(isWin: false, isDraw: false);

    _showResultDialog(
      isWin: false,
      isDraw: false,
      title: 'FIM DE JOGO',
      headline: 'Você bateu! Você perdeu a partida.',
    );
  }

  void _handleOpponentCrashed() {
    _matchTimer?.cancel();
    _opponentSimTimer?.cancel();
    _moveController.stop();

    setState(() {
      _gameState = _gameState.copyWith(status: GameStatus.gameOver);
    });

    AudioService().playVictory();
    _applyTrophyResult(isWin: true, isDraw: false);

    _showResultDialog(
      isWin: true,
      isDraw: false,
      title: '🏆 VITÓRIA! 🏆',
      headline: 'O oponente bateu! Você venceu a partida!',
    );
  }

  void _evaluateTwoMinuteWinner() {
    final playerSize = _gameState.playerSnake.body.length;
    final opponentSize = _opponentLength;
    final playerScore = _gameState.playerScore;
    final opponentScore = _opponentApples * 10;

    if (playerSize == opponentSize && playerScore == opponentScore) {
      // Tied in size and score! Enter sudden death overtime up to 3 minutes
      _isOvertime = true;
      _overtimeSeconds = 0;
      _moveController.duration =
          const Duration(milliseconds: SettingsService.speedInsane);
      _showSpeedStageNotification('EMPATE! PRORROGAÇÃO ATÉ 3 MINUTOS: VELOCIDADE MÁXIMA!');
      AudioService().playDirectionChange();
    } else if (playerSize > opponentSize ||
        (playerSize == opponentSize && playerScore > opponentScore)) {
      _matchTimer?.cancel();
      _opponentSimTimer?.cancel();
      _moveController.stop();

      setState(() {
        _gameState = _gameState.copyWith(status: GameStatus.gameOver);
      });

      AudioService().playVictory();
      _applyTrophyResult(isWin: true, isDraw: false);

      _showResultDialog(
        isWin: true,
        isDraw: false,
        title: '🏆 VITÓRIA! 🏆',
        headline: 'Sua cobra foi maior que a do oponente! Você venceu a partida!',
      );
    } else {
      _matchTimer?.cancel();
      _opponentSimTimer?.cancel();
      _moveController.stop();

      setState(() {
        _gameState = _gameState.copyWith(status: GameStatus.gameOver);
      });

      AudioService().playGameOver();
      _applyTrophyResult(isWin: false, isDraw: false);

      _showResultDialog(
        isWin: false,
        isDraw: false,
        title: 'FIM DE JOGO',
        headline: 'A cobra do oponente foi maior! Você perdeu a partida.',
      );
    }
  }

  void _evaluateThreeMinuteLimit() {
    _matchTimer?.cancel();
    _opponentSimTimer?.cancel();
    _moveController.stop();

    final playerSize = _gameState.playerSnake.body.length;
    final opponentSize = _opponentLength;
    final playerScore = _gameState.playerScore;
    final opponentScore = _opponentApples * 10;

    setState(() {
      _gameState = _gameState.copyWith(status: GameStatus.gameOver);
    });

    if (playerSize == opponentSize && playerScore == opponentScore) {
      // Both still alive and with same size and points -> DRAW! Both gain 2 trophies!
      AudioService().playVictory();
      _applyTrophyResult(isWin: false, isDraw: true);

      _showResultDialog(
        isWin: false,
        isDraw: true,
        title: '🤝 EMPATE! 🤝',
        headline:
            'Fim dos 3 minutos! Ambos sobreviveram com o mesmo tamanho e pontuação.',
      );
    } else if (playerSize > opponentSize ||
        (playerSize == opponentSize && playerScore > opponentScore)) {
      AudioService().playVictory();
      _applyTrophyResult(isWin: true, isDraw: false);

      _showResultDialog(
        isWin: true,
        isDraw: false,
        title: '🏆 VITÓRIA! 🏆',
        headline: 'Fim dos 3 minutos! Sua cobra foi maior que a do oponente!',
      );
    } else {
      AudioService().playGameOver();
      _applyTrophyResult(isWin: false, isDraw: false);

      _showResultDialog(
        isWin: false,
        isDraw: false,
        title: 'FIM DE JOGO',
        headline: 'Fim dos 3 minutos! A cobra do oponente foi maior.',
      );
    }
  }

  void _applyTrophyResult({required bool isWin, bool isDraw = false}) {
    final leaderboardService =
        Provider.of<LeaderboardService>(context, listen: false);
    final settingsService =
        Provider.of<SettingsService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    final currentTrophies =
        authService.currentUser?.trophies ?? settingsService.trophies;
    int delta = 0;

    if (isDraw) {
      delta = 2; // +2 trophies on draw for both
    } else if (isWin) {
      delta = 3; // +3 points for winning
    } else {
      if (currentTrophies < 30) {
        delta = 1; // +1 point if points < 30
      } else {
        delta = -1; // -1 point if points >= 30
      }
    }

    settingsService.addTrophies(delta);
    settingsService.incrementGamesPlayed();
    settingsService.updateHighScore(_gameState.playerScore);

    if (authService.currentUser != null) {
      authService.updateUserStats(trophyChange: delta, gameWon: isWin);
      leaderboardService.applyGameResult(
        authService.currentUser!.id,
        isWin,
        _gameState.playerScore,
        isDraw: isDraw,
      );
    } else {
      leaderboardService.addLocalScore(
        widget.playerName,
        _gameState.playerScore,
        settingsService.trophies,
      );
    }
  }

  void _showResultDialog({
    required bool isWin,
    bool isDraw = false,
    required String title,
    required String headline,
  }) {
    if (_isExitDialogOpen && mounted) {
      Navigator.of(context).pop();
      _isExitDialogOpen = false;
    }

    final settings = Provider.of<SettingsService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final currentTrophies = auth.currentUser?.trophies ?? settings.trophies;
    final trophyText = isDraw
        ? '+2 Pontos'
        : (isWin
            ? '+3 Pontos'
            : (currentTrophies < 30 ? '+1 Ponto' : '-1 Ponto'));

    final Color bannerColor = isDraw
        ? const Color(0xFFFFB74D)
        : (isWin ? const Color(0xFFFFD700) : SnakeTheme.lightGreen);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: SnakeTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: bannerColor,
            width: 2,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: bannerColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              headline,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SnakeTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bannerColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: bannerColor,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isDraw ? Icons.handshake : Icons.emoji_events,
                        color: bannerColor,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Recompensa: $trophyText',
                        style: TextStyle(
                          color: bannerColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Seu Tamanho: ${_gameState.playerSnake.body.length} | Oponente: $_opponentLength',
                    style: const TextStyle(
                      color: SnakeTheme.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total de Troféus: ${settings.trophies}',
                    style: const TextStyle(
                      color: SnakeTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SnakeTheme.darkGreen,
              foregroundColor: SnakeTheme.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              side: const BorderSide(color: SnakeTheme.lightGreen),
            ),
            child: const Text('Menu'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.pushNamed(context, '/leaderboard');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SnakeTheme.accentColor,
              foregroundColor: SnakeTheme.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Classificação'),
          ),
        ],
      ),
    );
  }

  // Back button handler: DO NOT PAUSE GAME (user requirement)
  Future<void> _handleBackButton() async {
    if (_isIntroActive) {
      // Never allow leaving when match has just started!
      return;
    }

    if (_gameState.status == GameStatus.gameOver) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (_gameState.status != GameStatus.playing) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    _isExitDialogOpen = true;

    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: SnakeTheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: SnakeTheme.lightGreen, width: 2),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: SnakeTheme.accentColor),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Abandonar Partida?',
                  style: TextStyle(
                    color: SnakeTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Tem certeza que deseja sair? O outro usuário ganhará a partida.',
            style: TextStyle(color: SnakeTheme.textSecondary, fontSize: 15),
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

    _isExitDialogOpen = false;

    if (shouldExit == true && mounted) {
      _matchTimer?.cancel();
      _opponentSimTimer?.cancel();
      _moveController.stop();

      if (widget.isRealMatch) {
        final socketService = Provider.of<SocketService>(context, listen: false);
        socketService.sendPlayerCrashed();
        socketService.leaveGame();
      }

      _applyTrophyResult(isWin: false, isDraw: false);

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _showSpeedStageNotification(String stageName) {
    _announcementTimer?.cancel();
    setState(() {
      _speedAnnouncement = '⚡ ACELERAÇÃO: $stageName!';
    });
    _announcementTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _speedAnnouncement = null;
        });
      }
    });
  }

  void _showAdvanceWarningNotification(String message) {
    _announcementTimer?.cancel();
    setState(() {
      _speedAnnouncement = '⚠️ $message';
    });
    _announcementTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) {
        setState(() {
          _speedAnnouncement = null;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _matchTimer?.cancel();
    _opponentSimTimer?.cancel();
    _announcementTimer?.cancel();
    _introCountdownTimer?.cancel();
    _moveController.dispose();
    _countdownAnimController.dispose();
    if (widget.isRealMatch) {
      final socketService = Provider.of<SocketService>(context, listen: false);
      socketService.onOpponentAppleEaten = null;
      socketService.onOpponentCrashed = null;
      socketService.onOpponentLeft = null;
    }
    AudioService().resumeBackgroundMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackButton();
      },
      child: Scaffold(
        backgroundColor: SnakeTheme.background,
        appBar: AppBar(
          leading: _isIntroActive
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _handleBackButton,
                ),
          title: Text(
            'Online: ${widget.playerName} VS ${widget.opponentName}',
            style: const TextStyle(
              color: SnakeTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          backgroundColor: SnakeTheme.darkGreen,
          iconTheme: const IconThemeData(color: SnakeTheme.textPrimary),
        ),
        body: SafeArea(
          top: false,
          bottom: true,
          child: Stack(
            children: [
              Column(
                children: [
                  // Dual Score & Timer HUD (~10%)
                  _buildDualHeader(),

                  // Main Play Area: Landscape (Row with board left, controls right) vs Portrait (Column)
                  if (MediaQuery.of(context).orientation == Orientation.landscape)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Game board on the left (62% of width)
                          Expanded(
                            flex: 62,
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: SnakeTheme.lightGreen, width: 3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: AnimatedBuilder(
                                  animation: _moveController,
                                  builder: (context, _) {
                                    return GameBoard(
                                      gameState: _gameState,
                                      animationProgress: _moveController.value,
                                      onDirectionChange: _onDirectionChange,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          // Game controls / Whiteboard on the right (38% of width)
                          Consumer<SettingsService>(
                            builder: (context, settings, _) {
                              return Expanded(
                                flex: 38,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                                  child: settings.controlType == ControlType.buttons
                                      ? Center(
                                          child: SingleChildScrollView(
                                            physics: const NeverScrollableScrollPhysics(),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 2),
                                              child: GameControls(
                                                onDirectionChange: _onDirectionChange,
                                                isEnabled: !_isIntroActive &&
                                                    _gameState.status == GameStatus.playing,
                                              ),
                                            ),
                                          ),
                                        )
                                      : GestureWhiteboard(
                                          onDirectionChange: _onDirectionChange,
                                          isEnabled: !_isIntroActive &&
                                              _gameState.status == GameStatus.playing,
                                        ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Portrait: Game board area (~60%)
                    Expanded(
                      flex: 6,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: SnakeTheme.lightGreen, width: 3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: AnimatedBuilder(
                            animation: _moveController,
                            builder: (context, _) {
                              return GameBoard(
                                gameState: _gameState,
                                animationProgress: _moveController.value,
                                onDirectionChange: _onDirectionChange,
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // Control area (~30%)
                    Consumer<SettingsService>(
                      builder: (context, settings, _) {
                        return Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2.0),
                            child: settings.controlType == ControlType.buttons
                                ? Center(
                                    child: SingleChildScrollView(
                                      physics: const NeverScrollableScrollPhysics(),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: GameControls(
                                          onDirectionChange: _onDirectionChange,
                                          isEnabled: !_isIntroActive &&
                                              _gameState.status == GameStatus.playing,
                                        ),
                                      ),
                                    ),
                                  )
                                : GestureWhiteboard(
                                    onDirectionChange: _onDirectionChange,
                                    isEnabled: !_isIntroActive &&
                                        _gameState.status == GameStatus.playing,
                                  ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),

              // 3-second Intro Countdown Overlay with banner
              if (_isIntroActive) _buildIntroCountdownOverlay(),

              // In-game warning announcement banner
              if (_speedAnnouncement != null && !_isIntroActive)
                Positioned(
                  top: 70,
                  left: 20,
                  right: 20,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: SnakeTheme.cardBackground.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SnakeTheme.accentColor, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: SnakeTheme.accentColor.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        _speedAnnouncement!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: SnakeTheme.accentColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDualHeader() {
    final timerText = _isOvertime
        ? 'EXTRA ${_formatTime((60 - _overtimeSeconds).clamp(0, 60))}'
        : _formatTime(_remainingSeconds);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: SnakeTheme.cardBackground,
        border: Border(
          bottom: BorderSide(color: SnakeTheme.lightGreen, width: 2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Player side
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: SnakeTheme.lightGreen,
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.playerName,
                    style: const TextStyle(
                      color: SnakeTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Tam: ${_gameState.playerSnake.body.length} | 🍎 ${_gameState.applesEaten}',
                    style: const TextStyle(
                      color: SnakeTheme.lightGreen,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Center: Match Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isOvertime
                  ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                  : SnakeTheme.darkGreen,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isOvertime ? const Color(0xFFFFD700) : SnakeTheme.lightGreen,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  size: 14,
                  color: _isOvertime ? const Color(0xFFFFD700) : SnakeTheme.accentColor,
                ),
                const SizedBox(width: 4),
                Text(
                  timerText,
                  style: GoogleFonts.pressStart2p(
                    fontSize: 10,
                    color: _isOvertime ? const Color(0xFFFFD700) : SnakeTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Opponent side
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.opponentName,
                    style: const TextStyle(
                      color: SnakeTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Tam: $_opponentLength | 🍎 $_opponentApples',
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF00E5FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCountdownOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Banner: A MAIOR COBRA VENCE!
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: SnakeTheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SnakeTheme.accentColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: SnakeTheme.accentColor.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'A MAIOR COBRA VENCE!',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 13,
                    color: SnakeTheme.accentColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Quem tiver a maior cobra e durar mais tempo na arena vence a partida!',
                  style: TextStyle(
                    color: SnakeTheme.textPrimary,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // Big animated countdown number
          ScaleTransition(
            scale: Tween<double>(begin: 0.5, end: 1.2).animate(
              CurvedAnimation(
                parent: _countdownAnimController,
                curve: Curves.elasticOut,
              ),
            ),
            child: Text(
              _introCountdown > 0 ? '$_introCountdown' : 'VAI!',
              style: GoogleFonts.pressStart2p(
                fontSize: 64,
                color: _introCountdown > 0 ? const Color(0xFFFFD700) : SnakeTheme.lightGreen,
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text(
            'Partida de 2 minutos • Todas as maçãs sincronizadas',
            style: TextStyle(
              color: SnakeTheme.textSecondary.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
