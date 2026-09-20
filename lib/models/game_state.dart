import 'snake_model.dart';
import 'user_model.dart';

enum GameMode { local, online }

enum GameResult { win, lose, draw, disconnect }

class GameState {
  final String gameId;
  final GameMode mode;
  final GameStatus status;
  final Snake playerSnake;
  final Snake? opponentSnake;
  final List<Position> foods;
  final int gridWidth;
  final int gridHeight;
  final int playerScore;
  final int opponentScore;
  final int applesEaten;
  final User? currentUser;
  final User? opponent;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int gameSpeed;
  final bool isGoldenFood;
  final int? matchSeed;

  Position get food => foods.isNotEmpty ? foods.first : const Position(10, 10);

  GameState({
    required this.gameId,
    required this.mode,
    required this.status,
    required this.playerSnake,
    this.opponentSnake,
    List<Position>? foods,
    Position? food,
    this.gridWidth = 20,
    this.gridHeight = 20,
    this.playerScore = 0,
    this.opponentScore = 0,
    this.applesEaten = 0,
    this.currentUser,
    this.opponent,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.gameSpeed = 300,
    this.isGoldenFood = false,
    this.matchSeed,
  }) : foods = foods ?? (food != null ? [food] : const [Position(10, 10)]);

  factory GameState.initial({
    String? gameId,
    GameMode mode = GameMode.local,
    User? currentUser,
    int? gridWidth,
    int? gridHeight,
    int? gameSpeed,
    bool isGoldenFood = false,
    int? matchSeed,
  }) {
    final width = gridWidth ?? 20;
    final height = gridHeight ?? 20;
    
    return GameState(
      gameId: gameId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      mode: mode,
      status: mode == GameMode.local ? GameStatus.playing : GameStatus.waiting,
      playerSnake: Snake(
        body: [
          Position(width ~/ 4, height ~/ 2),
          Position(width ~/ 4 - 1, height ~/ 2),
          Position(width ~/ 4 - 2, height ~/ 2),
        ],
        direction: Direction.right,
      ),
      foods: [Position(width ~/ 2, height ~/ 2)],
      gridWidth: width,
      gridHeight: height,
      gameSpeed: gameSpeed ?? 300,
      currentUser: currentUser,
      createdAt: DateTime.now(),
      isGoldenFood: isGoldenFood,
      matchSeed: matchSeed,
    );
  }

  GameState copyWith({
    String? gameId,
    GameMode? mode,
    GameStatus? status,
    Snake? playerSnake,
    Snake? opponentSnake,
    List<Position>? foods,
    Position? food,
    int? gridWidth,
    int? gridHeight,
    int? playerScore,
    int? opponentScore,
    int? applesEaten,
    User? currentUser,
    User? opponent,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    int? gameSpeed,
    bool? isGoldenFood,
    int? matchSeed,
  }) {
    return GameState(
      gameId: gameId ?? this.gameId,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      playerSnake: playerSnake ?? this.playerSnake,
      opponentSnake: opponentSnake ?? this.opponentSnake,
      foods: foods ?? (food != null ? [food] : this.foods),
      gridWidth: gridWidth ?? this.gridWidth,
      gridHeight: gridHeight ?? this.gridHeight,
      playerScore: playerScore ?? this.playerScore,
      opponentScore: opponentScore ?? this.opponentScore,
      applesEaten: applesEaten ?? this.applesEaten,
      currentUser: currentUser ?? this.currentUser,
      opponent: opponent ?? this.opponent,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      gameSpeed: gameSpeed ?? this.gameSpeed,
      isGoldenFood: isGoldenFood ?? this.isGoldenFood,
      matchSeed: matchSeed ?? this.matchSeed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'mode': mode.index,
      'status': status.index,
      'playerSnake': playerSnake.toJson(),
      'opponentSnake': opponentSnake?.toJson(),
      'food': food.toJson(),
      'foods': foods.map((f) => f.toJson()).toList(),
      'gridWidth': gridWidth,
      'gridHeight': gridHeight,
      'playerScore': playerScore,
      'opponentScore': opponentScore,
      'applesEaten': applesEaten,
      'currentUser': currentUser?.toJson(),
      'opponent': opponent?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'gameSpeed': gameSpeed,
      'isGoldenFood': isGoldenFood,
      'matchSeed': matchSeed,
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    List<Position> parsedFoods = [];
    if (json['foods'] != null) {
      parsedFoods = (json['foods'] as List)
          .map((f) => Position.fromJson(f as Map<String, dynamic>))
          .toList();
    } else if (json['food'] != null) {
      parsedFoods = [Position.fromJson(json['food'] as Map<String, dynamic>)];
    } else {
      parsedFoods = const [Position(10, 10)];
    }

    return GameState(
      gameId: json['gameId'] ?? '',
      mode: GameMode.values[json['mode'] ?? 0],
      status: GameStatus.values[json['status'] ?? 0],
      playerSnake: Snake.fromJson(json['playerSnake'] as Map<String, dynamic>),
      opponentSnake: json['opponentSnake'] != null 
          ? Snake.fromJson(json['opponentSnake'] as Map<String, dynamic>) 
          : null,
      foods: parsedFoods,
      gridWidth: json['gridWidth'] ?? 20,
      gridHeight: json['gridHeight'] ?? 20,
      playerScore: json['playerScore'] ?? 0,
      opponentScore: json['opponentScore'] ?? 0,
      applesEaten: json['applesEaten'] ?? 0,
      currentUser: json['currentUser'] != null 
          ? User.fromJson(json['currentUser'] as Map<String, dynamic>) 
          : null,
      opponent: json['opponent'] != null 
          ? User.fromJson(json['opponent'] as Map<String, dynamic>) 
          : null,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      startedAt: json['startedAt'] != null 
          ? DateTime.parse(json['startedAt']) 
          : null,
      endedAt: json['endedAt'] != null 
          ? DateTime.parse(json['endedAt']) 
          : null,
      gameSpeed: json['gameSpeed'] ?? 300,
      isGoldenFood: json['isGoldenFood'] ?? false,
      matchSeed: json['matchSeed'],
    );
  }

  bool get isMultiplayer => mode == GameMode.online;
  bool get isGameActive => status == GameStatus.playing;
  bool get isWaitingForOpponent => status == GameStatus.waiting && mode == GameMode.online;
  
  /// Calculate current game speed based on base speed and apples eaten
  /// Speed increases: 10% after 5 apples, 20% after 10 apples, 30% after 15 apples, etc.
  int get currentGameSpeed {
    final baseSpeed = gameSpeed;
    final speedIncreaseLevel = applesEaten ~/ 5; // Every 5 apples increases speed
    final speedMultiplier = 1.0 - (speedIncreaseLevel * 0.1); // 10% faster each level
    
    // Ensure minimum speed of 50ms to avoid too fast gameplay
    final newSpeed = (baseSpeed * speedMultiplier).round();
    return newSpeed < 50 ? 50 : newSpeed;
  }
}

class GameResult_ {
  final GameResult result;
  final int finalScore;
  final int opponentScore;
  final int trophiesEarned;
  final DateTime completedAt;
  final Duration gameDuration;

  const GameResult_({
    required this.result,
    required this.finalScore,
    required this.opponentScore,
    required this.trophiesEarned,
    required this.completedAt,
    required this.gameDuration,
  });

  factory GameResult_.fromGameState(GameState gameState, GameResult result) {
    final now = DateTime.now();
    final duration = gameState.startedAt != null 
        ? now.difference(gameState.startedAt!) 
        : Duration.zero;
    
    int trophies = 0;
    switch (result) {
      case GameResult.win:
        trophies = 3;
        break;
      case GameResult.lose:
        trophies = -1;
        break;
      case GameResult.draw:
        trophies = 1;
        break;
      case GameResult.disconnect:
        trophies = 0;
        break;
    }

    return GameResult_(
      result: result,
      finalScore: gameState.playerScore,
      opponentScore: gameState.opponentScore,
      trophiesEarned: trophies,
      completedAt: now,
      gameDuration: duration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'result': result.index,
      'finalScore': finalScore,
      'opponentScore': opponentScore,
      'trophiesEarned': trophiesEarned,
      'completedAt': completedAt.toIso8601String(),
      'gameDuration': gameDuration.inSeconds,
    };
  }

  factory GameResult_.fromJson(Map<String, dynamic> json) {
    return GameResult_(
      result: GameResult.values[json['result'] ?? 0],
      finalScore: json['finalScore'] ?? 0,
      opponentScore: json['opponentScore'] ?? 0,
      trophiesEarned: json['trophiesEarned'] ?? 0,
      completedAt: DateTime.parse(json['completedAt'] ?? DateTime.now().toIso8601String()),
      gameDuration: Duration(seconds: json['gameDuration'] ?? 0),
    );
  }
}
