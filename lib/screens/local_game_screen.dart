import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/leaderboard_service.dart';
import '../services/auth_service.dart';
import '../services/audio_service.dart';
import '../widgets/game_board.dart';
import '../widgets/game_controls.dart';
import '../widgets/gesture_whiteboard.dart';
import '../models/game_state.dart';
import '../models/snake_model.dart';
import '../utils/theme.dart';

class LocalGameScreen extends StatefulWidget {
  const LocalGameScreen({super.key});

  @override
  State<LocalGameScreen> createState() => _LocalGameScreenState();
}

class _LocalGameScreenState extends State<LocalGameScreen>
    with SingleTickerProviderStateMixin {
  late GameState _gameState;
  late AnimationController _moveController;
  Timer? _matchTimer;
  int _remainingSeconds = 120;
  bool _isOvertime = false;
  int _overtimeSeconds = 0;
  int _initialSpeedIndex = 0;
  int _currentStage = 0;
  bool _isPaused = false;
  String? _speedAnnouncement;
  Timer? _announcementTimer;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _moveController.addListener(() {
      setState(() {});
    });
    _moveController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!_isPaused && _gameState.status == GameStatus.playing) {
          _updateGame();
          if (_gameState.status == GameStatus.playing && !_isPaused) {
            _moveController.forward(from: 0.0);
          }
        }
      }
    });

    _initializeGame();
  }

  @override
  void dispose() {
    _announcementTimer?.cancel();
    _matchTimer?.cancel();
    _moveController.dispose();
    // Resume background music when leaving game
    AudioService().resumeBackgroundMusic();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _initializeGame() {
    _matchTimer?.cancel();
    final settings = Provider.of<SettingsService>(context, listen: false);
    
    // Pause background music during gameplay
    AudioService().pauseBackgroundMusic();
    
    _remainingSeconds = 120;
    _isOvertime = false;
    _overtimeSeconds = 0;
    _initialSpeedIndex = settings.speedIndex;
    _currentStage = 0;

    final initialSpeed = SettingsService.getSpeedForStage(_initialSpeedIndex, 0);

    _gameState = GameState.initial(
      mode: GameMode.local,
      gridWidth: settings.gridSize,
      gridHeight: settings.gridSize,
      gameSpeed: initialSpeed,
    );

    _moveController.duration = Duration(milliseconds: initialSpeed);
    _startMatchTimer();
    _startGameLoop();
  }

  void _startMatchTimer() {
    _matchTimer?.cancel();
    _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isPaused || _gameState.status != GameStatus.playing) {
        return;
      }

      setState(() {
        if (!_isOvertime) {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;

            // Check for 5-second advance warning before speed progression or overtime
            if (_remainingSeconds == 95 || _remainingSeconds == 65 || _remainingSeconds == 35) {
              _showAdvanceWarningNotification('A cobra ficará mais rápida em 5s!');
            } else if (_remainingSeconds == 5) {
              _showAdvanceWarningNotification('Modo Sobrevivência Extrema em 5s!');
            }

            // Check for 30-second speed progression stage
            final elapsed = 120 - _remainingSeconds;
            final newStage = (elapsed ~/ 30).clamp(0, 3);
            if (newStage > _currentStage) {
              _currentStage = newStage;
              final newSpeed = SettingsService.getSpeedForStage(_initialSpeedIndex, _currentStage);
              _moveController.duration = Duration(milliseconds: newSpeed);
              final stageName = SettingsService.getSpeedNameForStage(_initialSpeedIndex, _currentStage);
              _showSpeedStageNotification(stageName);
              AudioService().playDirectionChange();
            }

            // Every 3 seconds, a random apple surges on the board
            if (elapsed > 0 && elapsed % 3 == 0) {
              _surgeNewApple();
            }
          }

          if (_remainingSeconds <= 0) {
            // Trigger Extreme Survival / Overtime mode!
            _isOvertime = true;
            _overtimeSeconds = 0;
            _moveController.duration = const Duration(milliseconds: SettingsService.speedInsane);
            _showSpeedStageNotification('SOBREVIVÊNCIA EXTREMA: VELOCIDADE MÁXIMA & MAÇÃS DOURADAS!');
            AudioService().playVictory();
          }
        } else {
          // Count up in Overtime!
          _overtimeSeconds++;
          // Extra apple surge every 3 seconds in overtime
          if (_overtimeSeconds % 3 == 0) {
            _surgeNewApple();
          }
          // Award +10 bonus survival points every 5 seconds survived in Overtime
          if (_overtimeSeconds % 5 == 0) {
            _gameState = _gameState.copyWith(playerScore: _gameState.playerScore + 10);
          }
        }
      });
    });
  }

  void _startGameLoop() {
    if (!_isPaused && _gameState.status == GameStatus.playing) {
      _moveController.forward(from: 0.0);
    }
  }

  void _updateGame() {
    if (_gameState.status != GameStatus.playing) return;

    // Determine growth amount and score based on game time & golden food
    final bool isGolden = _gameState.isGoldenFood;
    int growthAmount = 1;
    int pointsGained = 10;

    if (_isOvertime) {
      // In Overtime, all apples give +3 growth and +30 points
      growthAmount = 3;
      pointsGained = 30;
    } else if (isGolden) {
      growthAmount = 3;
      pointsGained = 30;
    } else {
      final elapsed = 120 - _remainingSeconds;
      if (elapsed >= 60) {
        // Late normal game: +2 growth, +15 points
        growthAmount = 2;
        pointsGained = 15;
      } else {
        // Early game: +1 growth, +10 points
        growthAmount = 1;
        pointsGained = 10;
      }
    }

    // Move snake with calculated growth amount
    _gameState.playerSnake.move(_gameState.food, growthAmount: growthAmount);

    // Check collisions
    bool gameOver = false;
    
    // Wall collision
    if (_gameState.playerSnake.checkWallCollision(
      _gameState.gridWidth, 
      _gameState.gridHeight
    )) {
      gameOver = true;
    }

    // Self collision
    if (_gameState.playerSnake.checkSelfCollision()) {
      gameOver = true;
    }

    // Check if food eaten
    final int eatenIndex = _gameState.foods.indexWhere((f) => f == _gameState.playerSnake.head);
    final bool foodEaten = eatenIndex != -1;
    int newScore = _gameState.playerScore;
    List<Position> updatedFoods = List<Position>.from(_gameState.foods);

    if (foodEaten) {
      newScore += pointsGained;
      updatedFoods.removeAt(eatenIndex);

      // Ensure at least one apple remains on the board
      if (updatedFoods.isEmpty) {
        updatedFoods.add(_generateFood());
      }

      // Play eat food sound effect
      AudioService().playEatFood();
      
      // Determine if next spawned food is golden
      final bool nextIsGolden = _isOvertime || 
          (DateTime.now().millisecond % ((120 - _remainingSeconds >= 60) ? 3 : 5) == 0);

      // Update game state with incremented apples eaten
      setState(() {
        _gameState = _gameState.copyWith(
          status: gameOver ? GameStatus.gameOver : GameStatus.playing,
          playerScore: newScore,
          foods: updatedFoods,
          isGoldenFood: nextIsGolden,
          applesEaten: _gameState.applesEaten + 1,
        );
      });
      return;
    }

    // Update game state (no food eaten)
    setState(() {
      _gameState = _gameState.copyWith(
        status: gameOver ? GameStatus.gameOver : GameStatus.playing,
        playerScore: newScore,
      );
    });

    if (gameOver) {
      _matchTimer?.cancel();
      _moveController.stop();
      // Play game over sound effect
      AudioService().playGameOver();
      _showGameOverDialog();
    }
  }

  Position _generateFood() {
    // Restrict food spawning strictly to the inner playable arena
    // (Never on the outer 1-tile Formula 1 safety buffer)
    final int innerWidth = (_gameState.gridWidth - 2).clamp(1, _gameState.gridWidth);
    final int innerHeight = (_gameState.gridHeight - 2).clamp(1, _gameState.gridHeight);
    final random = Random();
    Position newFood;
    int attempts = 0;
    do {
      newFood = Position(
        1 + random.nextInt(innerWidth),
        1 + random.nextInt(innerHeight),
      );
      attempts++;
    } while ((_gameState.playerSnake.body.contains(newFood) || _gameState.foods.contains(newFood)) && attempts < 100);
    
    return newFood;
  }

  void _surgeNewApple() {
    if (_gameState.foods.length >= 5) return;
    final newFood = _generateFood();
    if (!_gameState.foods.contains(newFood)) {
      final updated = List<Position>.from(_gameState.foods)..add(newFood);
      setState(() {
        _gameState = _gameState.copyWith(foods: updated);
      });
    }
  }

  void _onDirectionChange(Direction direction) {
    if (_gameState.status == GameStatus.playing) {
      _gameState.playerSnake.nextDirection = direction;
      // Play direction change haptic feedback
      AudioService().playDirectionChange();
    }
  }

  void _pauseGame() {
    if (_isPaused) return;
    AudioService().playPause();
    setState(() {
      _isPaused = true;
      _gameState = _gameState.copyWith(status: GameStatus.paused);
      _moveController.stop();
    });
  }

  void _resumeGame() {
    if (!_isPaused) return;
    AudioService().playPause();
    setState(() {
      _isPaused = false;
      _gameState = _gameState.copyWith(status: GameStatus.playing);
      _moveController.forward();
    });
  }

  Future<bool> _handleBackButton() async {
    if (_gameState.status == GameStatus.gameOver) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return true;
    }

    // 1. Pause game automatically when user presses back
    final bool wasPlaying = !_isPaused && _gameState.status == GameStatus.playing;
    if (wasPlaying) {
      _pauseGame();
    }

    // 2. Show confirmation dialog
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
              Icon(Icons.pause_circle_outline, color: SnakeTheme.accentColor),
              SizedBox(width: 8),
              Text(
                'Jogo Pausado',
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

    if (shouldExit == true) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return true;
    } else {
      // Resume if was playing before
      if (wasPlaying && mounted) {
        _resumeGame();
      }
      return false;
    }
  }

  void _restartGame() {
    _announcementTimer?.cancel();
    _speedAnnouncement = null;
    _matchTimer?.cancel();
    _moveController.stop();
    _moveController.reset();
    _isPaused = false;
    _isOvertime = false;
    _overtimeSeconds = 0;
    _initializeGame();
    setState(() {
      _gameState = _gameState.copyWith(status: GameStatus.playing);
    });
  }

  void _showGameOverDialog() {
    final settings = Provider.of<SettingsService>(context, listen: false);
    final leaderboardService = Provider.of<LeaderboardService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Update high score
    settings.updateHighScore(_gameState.playerScore);
    settings.incrementGamesPlayed();
    
    // Add to local leaderboard without trophy changes (local games don't affect trophies)
    final playerName = authService.currentUser?.name ?? 'Jogador Local';
    leaderboardService.addLocalScore(playerName, _gameState.playerScore, 0);

    final bool reachedOvertime = _isOvertime || (120 - _remainingSeconds >= 120);
    final String survivedText = reachedOvertime
        ? '02:00 (+${_formatTime(_overtimeSeconds)} Extremo)'
        : '${_formatTime(120 - _remainingSeconds)} / 02:00';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: SnakeTheme.cardBackground,
        title: Text(
          reachedOvertime ? '👑 SOBREVIVENTE DA ARENA! 👑' : 'Fim de Jogo',
          style: TextStyle(
            color: reachedOvertime ? const Color(0xFFFFD700) : SnakeTheme.textPrimary,
            fontSize: reachedOvertime ? 20 : 24,
            fontWeight: FontWeight.bold,

          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reachedOvertime) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.whatshot, color: Color(0xFFFFD700), size: 18),
                        SizedBox(width: 4),
                        Text(
                          'MODO EXTREMO SUPERADO',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,

                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Você sobreviveu aos 2 minutos inteiros + ${_overtimeSeconds}s na velocidade máxima!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: SnakeTheme.textPrimary,
                        fontSize: 12,

                      ),
                    ),
                  ],
                ),
              ),
            ],
            Text(
              'Pontuação: ${_gameState.playerScore}',
              style: const TextStyle(
                color: SnakeTheme.accentColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,

              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tamanho: ${_gameState.playerSnake.body.length} (${_gameState.applesEaten} maçãs)',
              style: const TextStyle(
                color: SnakeTheme.textPrimary,
                fontSize: 14,

              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tempo Sobrevivido: $survivedText',
              style: TextStyle(
                color: reachedOvertime ? const Color(0xFFFFD700) : SnakeTheme.lightGreen,
                fontSize: 14,

                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Melhor Pontuação: ${settings.highScore}',
              style: const TextStyle(
                color: SnakeTheme.textSecondary,
                fontSize: 14,

              ),
            ),

            if (_gameState.playerScore == settings.highScore && _gameState.playerScore > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SnakeTheme.accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '🎉 Nova Melhor Pontuação! 🎉',
                  style: TextStyle(
                    color: SnakeTheme.accentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,

                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Menu Button - Improved visibility
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SnakeTheme.darkGreen,
              foregroundColor: SnakeTheme.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              side: const BorderSide(color: SnakeTheme.lightGreen, width: 2),
            ),
            child: const Text(
              'Menu',
              style: TextStyle(
                color: SnakeTheme.textPrimary,

                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Play Again Button
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restartGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SnakeTheme.primaryGreen,
              foregroundColor: SnakeTheme.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Jogar Novamente',
              style: TextStyle(
                color: SnakeTheme.textPrimary,

                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Leaderboard Button - Improved visibility
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.pushNamed(context, '/leaderboard');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SnakeTheme.accentColor,
              foregroundColor: SnakeTheme.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Classificação',
              style: TextStyle(
                color: SnakeTheme.textPrimary,

                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackButton,
          ),
          title: const Text(
            'Snake Local',
            style: TextStyle(
              color: SnakeTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: SnakeTheme.darkGreen,
          iconTheme: const IconThemeData(color: SnakeTheme.textPrimary),
        actions: [
          IconButton(
            onPressed: _pauseGame,
            icon: Icon(
              _isPaused ? Icons.play_arrow : Icons.pause,
              color: SnakeTheme.accentColor,
            ),
          ),
          IconButton(
            onPressed: _restartGame,
            icon: const Icon(
              Icons.restart_alt,
              color: SnakeTheme.accentColor,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Stack(
          children: [
            Column(
              children: [
                // Score & Timer display (~10% header, guaranteed no overflow)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: SnakeTheme.cardBackground,
                    border: Border(
                      bottom: BorderSide(color: SnakeTheme.lightGreen, width: 2),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Timer badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isOvertime
                                ? const Color(0xFFFFD700).withValues(alpha: 0.25)
                                : (_remainingSeconds <= 30
                                    ? const Color(0xFFD32F2F).withValues(alpha: 0.5)
                                    : SnakeTheme.primaryGreen.withValues(alpha: 0.25)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isOvertime
                                  ? const Color(0xFFFFD700)
                                  : (_remainingSeconds <= 30 ? const Color(0xFFEF5350) : SnakeTheme.accentColor),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isOvertime ? Icons.whatshot : Icons.timer,
                                size: 15,
                                color: _isOvertime
                                    ? const Color(0xFFFFD700)
                                    : (_remainingSeconds <= 30 ? Colors.white : SnakeTheme.accentColor),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isOvertime
                                    ? '+${_formatTime(_overtimeSeconds)}'
                                    : _formatTime(_remainingSeconds),
                                style: TextStyle(
                                  color: _isOvertime
                                      ? const Color(0xFFFFD700)
                                      : (_remainingSeconds <= 30 ? Colors.white : SnakeTheme.accentColor),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Score
                        Text(
                          'Pontos: ${_gameState.playerScore}',
                          style: const TextStyle(
                            color: SnakeTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Apples / Size
                        Text(
                          '🍎 ${_gameState.applesEaten}',
                          style: const TextStyle(
                            color: SnakeTheme.lightGreen,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Speed stage badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isOvertime ? Colors.red.shade900 : SnakeTheme.primaryGreen,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isOvertime ? const Color(0xFFFFD700) : SnakeTheme.accentColor,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isOvertime ? Icons.local_fire_department : Icons.bolt,
                                color: _isOvertime ? const Color(0xFFFFD700) : SnakeTheme.accentColor,
                                size: 14,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _isOvertime
                                    ? 'EXTREMO'
                                    : SettingsService.getSpeedNameForStage(_initialSpeedIndex, _currentStage),
                                style: TextStyle(
                                  color: _isOvertime ? const Color(0xFFFFD700) : SnakeTheme.accentColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (_gameState.status == GameStatus.paused
                                    ? Colors.orange
                                    : SnakeTheme.primaryGreen)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _gameState.status == GameStatus.paused ? 'PAUSADO' : 'JOGANDO',
                            style: TextStyle(
                              color: _gameState.status == GameStatus.paused 
                                  ? Colors.orange 
                                  : SnakeTheme.primaryGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
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
                              child: GameBoard(
                                gameState: _gameState,
                                animationProgress: _moveController.value,
                                onDirectionChange: _onDirectionChange,
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
                                              isEnabled: _gameState.status == GameStatus.playing && !_isPaused,
                                            ),
                                          ),
                                        ),
                                      )
                                    : GestureWhiteboard(
                                        onDirectionChange: _onDirectionChange,
                                        isEnabled: _gameState.status == GameStatus.playing && !_isPaused,
                                      ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Portrait: Game board on top (flex 6)
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
                        child: GameBoard(
                          gameState: _gameState,
                          animationProgress: _moveController.value,
                          onDirectionChange: _onDirectionChange,
                        ),
                      ),
                    ),
                  ),
                  
                  // Portrait: Game controls / Whiteboard below (flex 3)
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
                                        isEnabled: _gameState.status == GameStatus.playing && !_isPaused,
                                      ),
                                    ),
                                  ),
                                )
                              : GestureWhiteboard(
                                  onDirectionChange: _onDirectionChange,
                                  isEnabled: _gameState.status == GameStatus.playing && !_isPaused,
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),

            // In-game Speed Announcement HUD Banner (Non-blocking: IgnorePointer allows touches right through)
            if (_speedAnnouncement != null)
              Positioned(
                top: 56, // Just below the top score/timer bar
                left: 20,
                right: 20,
                child: IgnorePointer(
                  ignoring: true,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 250),
                    builder: (context, animValue, child) {
                      return Transform.scale(
                        scale: 0.85 + (0.15 * animValue),
                        child: Opacity(
                          opacity: animValue,
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: SnakeTheme.cardBackground.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SnakeTheme.accentColor, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: SnakeTheme.accentColor.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt,
                            color: SnakeTheme.accentColor,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _speedAnnouncement!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: SnakeTheme.accentColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
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
}
