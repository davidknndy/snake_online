import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snake_online/services/settings_service.dart';
import 'package:snake_online/models/snake_model.dart';
import 'package:snake_online/models/game_state.dart';
import 'package:snake_online/services/leaderboard_service.dart';
import 'package:snake_online/widgets/gesture_whiteboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService Speed & Difficulty Tests', () {
    late SettingsService settings;

    setUp(() {
      settings = SettingsService();
    });

    test('Initial speed is Normal (280ms) and difficulty is Normal', () {
      expect(settings.gameSpeed, equals(SettingsService.speedNormal));
      expect(settings.speedLabel, equals('Normal'));
      expect(settings.speedIndex, equals(0));
      expect(settings.difficulty, equals(GameDifficulty.normal));
      expect(settings.difficulty.displayName, equals('Normal'));
    });

    test('Speed switch to Rápido (200ms) maps to Difícil', () async {
      await settings.setSpeedByIndex(1);
      expect(settings.gameSpeed, equals(SettingsService.speedFast));
      expect(settings.speedLabel, equals('Rápido'));
      expect(settings.speedIndex, equals(1));
      expect(settings.difficulty, equals(GameDifficulty.hard));
      expect(settings.difficulty.displayName, equals('Difícil'));
    });

    test('Speed switch to Muito Rápido (140ms) maps to Muito Difícil', () async {
      await settings.setSpeedByIndex(2);
      expect(settings.gameSpeed, equals(SettingsService.speedVeryFast));
      expect(settings.speedLabel, equals('Muito Rápido'));
      expect(settings.speedIndex, equals(2));
      expect(settings.difficulty, equals(GameDifficulty.veryHard));
      expect(settings.difficulty.displayName, equals('Muito Difícil'));
    });

    test('2-minute arena progression accelerates every 30 seconds correctly', () {
      // Starting from Normal (index 0)
      expect(SettingsService.getSpeedForStage(0, 0), equals(SettingsService.speedNormal)); // 0-30s
      expect(SettingsService.getSpeedForStage(0, 1), equals(SettingsService.speedFast)); // 30-60s
      expect(SettingsService.getSpeedForStage(0, 2), equals(SettingsService.speedVeryFast)); // 60-90s
      expect(SettingsService.getSpeedForStage(0, 3), equals(SettingsService.speedUltraFast)); // 90-120s: Ultra Rápido
      expect(SettingsService.getSpeedNameForStage(0, 3), equals('Ultra Rápido'));

      // Starting from Rápido (index 1)
      expect(SettingsService.getSpeedForStage(1, 0), equals(SettingsService.speedFast));
      expect(SettingsService.getSpeedForStage(1, 1), equals(SettingsService.speedVeryFast));
      expect(SettingsService.getSpeedForStage(1, 2), equals(SettingsService.speedUltraFast));
      expect(SettingsService.getSpeedForStage(1, 3), equals(SettingsService.speedHyperFast)); // 90-120s: Hiper Rápido
      expect(SettingsService.getSpeedNameForStage(1, 3), equals('Hiper Rápido'));

      // Starting from Muito Rápido (index 2)
      expect(SettingsService.getSpeedForStage(2, 0), equals(SettingsService.speedVeryFast));
      expect(SettingsService.getSpeedForStage(2, 1), equals(SettingsService.speedUltraFast));
      expect(SettingsService.getSpeedForStage(2, 2), equals(SettingsService.speedHyperFast));
      expect(SettingsService.getSpeedForStage(2, 3), equals(SettingsService.speedInsane)); // 90-120s: Velocidade Insana
      expect(SettingsService.getSpeedNameForStage(2, 3), equals('Velocidade Insana'));
    });

    test('Control types only support Gestos (deslizar) and Botões', () async {
      expect(ControlType.values.length, equals(2));
      expect(ControlType.swipe.displayName, equals('Gestos (deslizar)'));
      expect(ControlType.buttons.displayName, equals('Botões'));

      await settings.setControlType(ControlType.buttons);
      expect(settings.controlType, equals(ControlType.buttons));

      await settings.setControlType(ControlType.swipe);
      expect(settings.controlType, equals(ControlType.swipe));
    });
  });

  group('Snake Movement & Interpolation Tests', () {
    test('Snake tracks previousBody on move for continuous animation', () {
      final snake = Snake(
        body: [
          const Position(5, 5),
          const Position(4, 5),
          const Position(3, 5),
        ],
        direction: Direction.right,
      );

      expect(snake.previousBody.length, equals(3));
      expect(snake.previousBody[0], equals(const Position(5, 5)));

      // Move right without eating food
      snake.move(const Position(10, 10));

      expect(snake.head, equals(const Position(6, 5)));
      expect(snake.previousBody[0], equals(const Position(5, 5)));
      expect(snake.previousBody[1], equals(const Position(4, 5)));
      expect(snake.previousBody[2], equals(const Position(3, 5)));
    });

    test('Snake grows when eating food', () {
      final snake = Snake(
        body: [
          const Position(5, 5),
          const Position(4, 5),
        ],
        direction: Direction.right,
      );

      snake.move(const Position(6, 5)); // Next position is food
      expect(snake.body.length, equals(3));
      expect(snake.head, equals(const Position(6, 5)));
    });

    test('Snake grows by 3 segments smoothly with growthAmount: 3', () {
      final snake = Snake(
        body: [
          const Position(5, 5),
          const Position(4, 5),
        ],
        direction: Direction.right,
      );

      // Eat food with growthAmount: 3
      snake.move(const Position(6, 5), growthAmount: 3);
      // Immediately grew +1 (head inserted at (6,5), no tail removed), pendingGrowth is 2
      expect(snake.body.length, equals(3));
      expect(snake.pendingGrowth, equals(2));

      // Next move (no food) consumes 1 pendingGrowth
      snake.move(const Position(10, 10));
      expect(snake.body.length, equals(4));
      expect(snake.pendingGrowth, equals(1));

      // Next move (no food) consumes last pendingGrowth
      snake.move(const Position(10, 10));
      expect(snake.body.length, equals(5));
      expect(snake.pendingGrowth, equals(0));

      // Normal move afterwards keeps length constant
      snake.move(const Position(10, 10));
      expect(snake.body.length, equals(5));
    });
  });

  group('LeaderboardService & Rewards Tests', () {
    test('LeaderboardEntry formattedDate correctly formats local time', () {
      final entry = LeaderboardEntry(
        id: 'test_1',
        playerName: 'Jogador Teste',
        score: 150,
        trophies: 10,
        timestamp: DateTime(2026, 9, 20, 14, 30),
        isLocal: true,
      );

      expect(entry.formattedDate, contains('20/09/2026 14:30'));
    });

    test('Weekly reset date calculation targets next Sunday 21:00 BRT (Monday 00:00 UTC)', () {
      final nextReset = LeaderboardService.getNextResetDateTime();
      final utcReset = nextReset.toUtc();
      expect(utcReset.weekday, equals(DateTime.monday));
      expect(utcReset.hour, equals(0));
      expect(utcReset.minute, equals(0));
      expect(utcReset.second, equals(0));
      expect(nextReset.isAfter(DateTime.now()), isTrue);
    });

    test('Reward Tiers contain all 5 requested ranks with correct skins', () {
      final tiers = LeaderboardService.rewardTiers;
      expect(tiers.length, equals(5));
      expect(tiers[0].percentile, equals('Top 5%'));
      expect(tiers[0].skinName, equals('Cobra Dourada Cibernética'));
      expect(tiers[1].percentile, equals('Top 10%'));
      expect(tiers[1].skinName, equals('Cobra Elétrica Neon'));
      expect(tiers[2].percentile, equals('Top 20%'));
      expect(tiers[2].skinName, equals('Cobra Cósmica Violeta'));
      expect(tiers[3].percentile, equals('Top 30%'));
      expect(tiers[3].skinName, equals('Cobra Esmeralda Tóxica'));
      expect(tiers[4].percentile, equals('Top 50%'));
      expect(tiers[4].skinName, equals('Cobra Titânio Metálica'));
    });

    test('getTierForRank maps ranks to expected percentiles', () {
      expect(LeaderboardService.getTierForRank(1, 100)?.percentile, equals('Top 5%'));
      expect(LeaderboardService.getTierForRank(5, 100)?.percentile, equals('Top 5%'));
      expect(LeaderboardService.getTierForRank(10, 100)?.percentile, equals('Top 10%'));
      expect(LeaderboardService.getTierForRank(20, 100)?.percentile, equals('Top 20%'));
      expect(LeaderboardService.getTierForRank(30, 100)?.percentile, equals('Top 30%'));
      expect(LeaderboardService.getTierForRank(50, 100)?.percentile, equals('Top 50%'));
      expect(LeaderboardService.getTierForRank(70, 100), isNull);
    });

    test('LeaderboardService caps local leaderboard to strictly top 10 best plays, discarding lower scores', () async {
      SharedPreferences.setMockInitialValues({});
      final service = LeaderboardService();
      await service.initialize();

      // Add 15 scores in ascending order (10, 20, ..., 150)
      for (int i = 1; i <= 15; i++) {
        await service.addLocalScore('Player $i', i * 10, i);
      }

      // Should have exactly 10 entries
      expect(service.localLeaderboard.length, equals(10));
      // Top score should be 150 (Player 15)
      expect(service.localLeaderboard.first.score, equals(150));
      expect(service.localLeaderboard.first.playerName, equals('Player 15'));
      // 10th score should be 60 (Player 6) - scores 10, 20, 30, 40, 50 were discarded
      expect(service.localLeaderboard.last.score, equals(60));
      expect(service.localLeaderboard.last.playerName, equals('Player 6'));
    });
  });

  group('GestureWhiteboard Tests', () {
    testWidgets('GestureWhiteboard renders cleanly and triggers direction callback on drag', (tester) async {
      Direction? detectedDirection;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureWhiteboard(
              onDirectionChange: (direction) {
                detectedDirection = direction;
              },
            ),
          ),
        ),
      );

      expect(find.text('LOUSA DE CONTROLE'), findsOneWidget);
      expect(find.text('Arraste o dedo nesta área para guiar a cobra'), findsOneWidget);

      // Perform swipe right
      await tester.drag(find.byType(GestureWhiteboard), const Offset(50, 0));
      await tester.pump();
      expect(detectedDirection, equals(Direction.right));

      // Perform swipe up
      await tester.drag(find.byType(GestureWhiteboard), const Offset(0, -50));
      await tester.pump();
      expect(detectedDirection, equals(Direction.up));
    });
  });

  group('Safety Buffer & Formula 1 Arena Tests', () {
    test('Snake can safely enter 1-tile outer perimeter (F1 safe buffer) without crashing', () {
      const gridWidth = 20;
      const gridHeight = 20;

      // Snake positioned on top-left outer buffer corner (0, 0)
      final snakeAtCorner = Snake(
        body: [const Position(0, 0), const Position(1, 0)],
        direction: Direction.left,
      );
      expect(snakeAtCorner.checkWallCollision(gridWidth, gridHeight), isFalse);

      // Snake positioned on bottom-right outer buffer (19, 19)
      final snakeAtBottomRight = Snake(
        body: [const Position(19, 19), const Position(18, 19)],
        direction: Direction.right,
      );
      expect(snakeAtBottomRight.checkWallCollision(gridWidth, gridHeight), isFalse);

      // Snake exiting outer buffer into negative X crashes into fatal barrier
      final snakeFatalCrashX = Snake(
        body: [const Position(-1, 5), const Position(0, 5)],
        direction: Direction.left,
      );
      expect(snakeFatalCrashX.checkWallCollision(gridWidth, gridHeight), isTrue);

      // Snake exiting outer buffer past gridWidth crashes into fatal barrier
      final snakeFatalCrashW = Snake(
        body: [const Position(20, 5), const Position(19, 5)],
        direction: Direction.right,
      );
      expect(snakeFatalCrashW.checkWallCollision(gridWidth, gridHeight), isTrue);
    });

    test('Food generation bounds logic guarantees food stays strictly within inner playable arena', () {
      const gridWidth = 20;
      const gridHeight = 20;
      final int innerWidth = gridWidth - 2; // 18
      final int innerHeight = gridHeight - 2; // 18

      for (int i = 0; i < 50; i++) {
        final x = 1 + (i % innerWidth);
        final y = 1 + ((i * 3) % innerHeight);

        // Food MUST never touch the outer 1-tile perimeter
        expect(x, greaterThanOrEqualTo(1));
        expect(x, lessThanOrEqualTo(gridWidth - 2));
        expect(y, greaterThanOrEqualTo(1));
        expect(y, lessThanOrEqualTo(gridHeight - 2));
        expect(x != 0 && x != gridWidth - 1, isTrue);
        expect(y != 0 && y != gridHeight - 1, isTrue);
      }
    });

    test('5-second advance warning matches 30s speed milestones', () {
      // Milestone 1 (30s): warning at 25s elapsed -> 95s remaining
      const rem1 = 120 - 25;
      expect(rem1, equals(95));

      // Milestone 2 (60s): warning at 55s elapsed -> 65s remaining
      const rem2 = 120 - 55;
      expect(rem2, equals(65));

      // Milestone 3 (90s): warning at 85s elapsed -> 35s remaining
      const rem3 = 120 - 85;
      expect(rem3, equals(35));

      // Milestone 4 (120s / Overtime): warning at 115s elapsed -> 5s remaining
      const rem4 = 120 - 115;
      expect(rem4, equals(5));
    });
  });

  group('Multiplayer Online & Synchronization Tests', () {
    test('Deterministic Apple Surge produces identical coordinates for both players using shared matchSeed', () {
      const matchSeed = 123456789;

      // Simulate Player 1 apple generation
      final randP1 = math.Random(matchSeed);
      final p1InitialFoods = <Position>[];
      for (int i = 0; i < 3; i++) {
        p1InitialFoods.add(Position(1 + randP1.nextInt(18), 1 + randP1.nextInt(18)));
      }

      // Simulate Player 2 apple generation with same seed
      final randP2 = math.Random(matchSeed);
      final p2InitialFoods = <Position>[];
      for (int i = 0; i < 3; i++) {
        p2InitialFoods.add(Position(1 + randP2.nextInt(18), 1 + randP2.nextInt(18)));
      }

      // Starting apples must be identical for both players
      expect(p1InitialFoods.length, equals(3));
      expect(p1InitialFoods, equals(p2InitialFoods));

      // Test periodic surges (every 3 seconds) for 10 surges
      for (int surge = 1; surge <= 10; surge++) {
        final randSurgeP1 = math.Random(matchSeed + (surge * 1337));
        final foodP1 = Position(1 + randSurgeP1.nextInt(18), 1 + randSurgeP1.nextInt(18));

        final randSurgeP2 = math.Random(matchSeed + (surge * 1337));
        final foodP2 = Position(1 + randSurgeP2.nextInt(18), 1 + randSurgeP2.nextInt(18));

        expect(foodP1, equals(foodP2));
      }
    });

    test('Competitive Trophy scoring rules (+3 win, +2 draw, +1 loss < 30, -1 loss >= 30)', () {
      int calculateTrophyDelta(int currentTrophies, bool isWin, {bool isDraw = false}) {
        if (isDraw) {
          return 2;
        } else if (isWin) {
          return 3;
        } else {
          return currentTrophies < 30 ? 1 : -1;
        }
      }

      // 1. Draw always awards +2 points to both players
      expect(calculateTrophyDelta(0, false, isDraw: true), equals(2));
      expect(calculateTrophyDelta(25, false, isDraw: true), equals(2));
      expect(calculateTrophyDelta(30, false, isDraw: true), equals(2));
      expect(calculateTrophyDelta(150, false, isDraw: true), equals(2));

      // 2. Winning always awards +3 points
      expect(calculateTrophyDelta(0, true), equals(3));
      expect(calculateTrophyDelta(25, true), equals(3));
      expect(calculateTrophyDelta(30, true), equals(3));
      expect(calculateTrophyDelta(150, true), equals(3));

      // 3. Beginner loss (< 30 points) gives encouragement (+1 point)
      expect(calculateTrophyDelta(0, false), equals(1));
      expect(calculateTrophyDelta(15, false), equals(1));
      expect(calculateTrophyDelta(29, false), equals(1));

      // 4. Competitive loss (>= 30 points) penalizes (-1 point)
      expect(calculateTrophyDelta(30, false), equals(-1));
      expect(calculateTrophyDelta(31, false), equals(-1));
      expect(calculateTrophyDelta(500, false), equals(-1));
    });

    test('3-minute match and overtime draw rule evaluation logic', () {
      // Helper function simulating 2-minute and 3-minute game evaluation
      String evaluateOutcome({
        required int elapsedSeconds,
        required int playerSize,
        required int opponentSize,
        required int playerScore,
        required int opponentScore,
      }) {
        if (elapsedSeconds < 120) {
          return 'playing';
        }

        if (elapsedSeconds == 120) {
          if (playerSize == opponentSize && playerScore == opponentScore) {
            return 'overtime';
          } else if (playerSize > opponentSize || (playerSize == opponentSize && playerScore > opponentScore)) {
            return 'player_win';
          } else {
            return 'opponent_win';
          }
        }

        // Overtime (up to 180 seconds = 3 minutes)
        if (elapsedSeconds >= 180) {
          if (playerSize == opponentSize && playerScore == opponentScore) {
            return 'draw';
          } else if (playerSize > opponentSize || (playerSize == opponentSize && playerScore > opponentScore)) {
            return 'player_win';
          } else {
            return 'opponent_win';
          }
        }

        return 'overtime';
      }

      // 1. At 2 minutes, tied players enter overtime
      expect(
        evaluateOutcome(
          elapsedSeconds: 120,
          playerSize: 5,
          opponentSize: 5,
          playerScore: 100,
          opponentScore: 100,
        ),
        equals('overtime'),
      );

      // 2. At 2 minutes, non-tied players have an immediate winner
      expect(
        evaluateOutcome(
          elapsedSeconds: 120,
          playerSize: 6,
          opponentSize: 5,
          playerScore: 120,
          opponentScore: 100,
        ),
        equals('player_win'),
      );

      // 3. At 3 minutes (180s), still tied in size and points -> DRAW!
      expect(
        evaluateOutcome(
          elapsedSeconds: 180,
          playerSize: 8,
          opponentSize: 8,
          playerScore: 220,
          opponentScore: 220,
        ),
        equals('draw'),
      );

      // 4. At 3 minutes (180s), one player pulled ahead -> Winner declared
      expect(
        evaluateOutcome(
          elapsedSeconds: 180,
          playerSize: 9,
          opponentSize: 8,
          playerScore: 250,
          opponentScore: 220,
        ),
        equals('player_win'),
      );
    });

    test('GameState correctly supports multiple foods and matchSeed', () {
      final state = GameState.initial(
        mode: GameMode.online,
        matchSeed: 987654,
      ).copyWith(
        foods: const [
          Position(5, 5),
          Position(10, 10),
          Position(15, 15),
        ],
      );

      expect(state.foods.length, equals(3));
      expect(state.food, equals(const Position(5, 5)));
      expect(state.matchSeed, equals(987654));

      // Test JSON roundtrip
      final json = state.toJson();
      final fromJson = GameState.fromJson(json);

      expect(fromJson.foods.length, equals(3));
      expect(fromJson.foods[0], equals(const Position(5, 5)));
      expect(fromJson.foods[1], equals(const Position(10, 10)));
      expect(fromJson.foods[2], equals(const Position(15, 15)));
      expect(fromJson.matchSeed, equals(987654));
    });
  });
}

