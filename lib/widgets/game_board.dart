import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/snake_model.dart';
import '../utils/theme.dart';

class GameBoard extends StatelessWidget {
  final GameState gameState;
  final double animationProgress;
  final Function(Direction) onDirectionChange;

  const GameBoard({
    super.key,
    required this.gameState,
    this.animationProgress = 1.0,
    required this.onDirectionChange,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) {
        _handleSwipe(details);
      },
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: CustomPaint(
          painter: SnakeGamePainter(gameState, animationProgress),
        ),
      ),
    );
  }

  void _handleSwipe(DragUpdateDetails details) {
    const double sensitivity = 5.0;
    
    if (details.delta.dx > sensitivity) {
      // Swipe right
      onDirectionChange(Direction.right);
    } else if (details.delta.dx < -sensitivity) {
      // Swipe left
      onDirectionChange(Direction.left);
    } else if (details.delta.dy > sensitivity) {
      // Swipe down
      onDirectionChange(Direction.down);
    } else if (details.delta.dy < -sensitivity) {
      // Swipe up
      onDirectionChange(Direction.up);
    }
  }
}

class SnakeGamePainter extends CustomPainter {
  final GameState gameState;
  final double animationProgress;

  SnakeGamePainter(this.gameState, [this.animationProgress = 1.0]);

  @override
  void paint(Canvas canvas, Size size) {
    final double cellWidth = size.width / gameState.gridWidth;
    final double cellHeight = size.height / gameState.gridHeight;

    // Draw background grid
    _drawGrid(canvas, size, cellWidth, cellHeight);

    // Draw snake with continuous smooth interpolation
    _drawSnake(canvas, cellWidth, cellHeight);

    // Draw food
    _drawFood(canvas, cellWidth, cellHeight);

    // Draw game over overlay if needed
    if (gameState.status == GameStatus.gameOver) {
      _drawGameOverOverlay(canvas, size);
    } else if (gameState.status == GameStatus.paused) {
      _drawPausedOverlay(canvas, size);
    }
  }

  void _drawGrid(Canvas canvas, Size size, double cellWidth, double cellHeight) {
    final int gw = gameState.gridWidth;
    final int gh = gameState.gridHeight;

    // 1. Draw Formula 1 Safety Buffer (Kerb / Zebras) around the outer 1-tile perimeter
    final curbRedPaint = Paint()
      ..color = const Color(0xFFD32F2F).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final curbWhitePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    for (int x = 0; x < gw; x++) {
      for (int y = 0; y < gh; y++) {
        final bool isPerimeter = (x == 0 || x == gw - 1 || y == 0 || y == gh - 1);
        if (isPerimeter) {
          final rect = Rect.fromLTWH(x * cellWidth, y * cellHeight, cellWidth, cellHeight);
          // Alternating F1 red and white curb pattern
          final bool isRed = (x + y) % 2 == 0;
          canvas.drawRect(rect, isRed ? curbRedPaint : curbWhitePaint);
        }
      }
    }

    // 2. Draw standard internal grid lines
    final gridPaint = Paint()
      ..color = SnakeTheme.darkGreen.withValues(alpha: 0.25)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw vertical lines
    for (int i = 0; i <= gw; i++) {
      final x = i * cellWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    // Draw horizontal lines
    for (int i = 0; i <= gh; i++) {
      final y = i * cellHeight;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // 3. Demarcation line: High-visibility track boundary separating inner playable arena from F1 buffer
    if (gw > 2 && gh > 2) {
      final innerTrackPaint = Paint()
        ..color = SnakeTheme.lightGreen.withValues(alpha: 0.75)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final innerTrackRect = Rect.fromLTWH(
        cellWidth,
        cellHeight,
        (gw - 2) * cellWidth,
        (gh - 2) * cellHeight,
      );
      canvas.drawRect(innerTrackRect, innerTrackPaint);
    }

    // 4. Outer crash barrier perimeter (the fatal boundary)
    final fatalWallPaint = Paint()
      ..color = const Color(0xFFE53935).withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fatalWallPaint);
  }

  void _drawSnake(Canvas canvas, double cellWidth, double cellHeight) {
    final snake = gameState.playerSnake;
    if (snake.body.isEmpty) return;

    final double p = animationProgress.clamp(0.0, 1.0);
    final prevBody = snake.previousBody.isNotEmpty ? snake.previousBody : snake.body;

    final List<Offset> segmentCenters = [];
    for (int i = 0; i < snake.body.length; i++) {
      final currentPos = snake.body[i];
      final prevPos = (i < prevBody.length) ? prevBody[i] : prevBody.last;

      final double interpX = prevPos.x + (currentPos.x - prevPos.x) * p;
      final double interpY = prevPos.y + (currentPos.y - prevPos.y) * p;

      segmentCenters.add(Offset(
        interpX * cellWidth + cellWidth / 2,
        interpY * cellHeight + cellHeight / 2,
      ));
    }

    // 1. Draw continuous snake body connecting segment centers
    final double strokeThickness = min(cellWidth, cellHeight) - 3.0;
    if (segmentCenters.length > 1) {
      final bodyPaint = Paint()
        ..color = SnakeTheme.snakeColor
        ..strokeWidth = strokeThickness
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(segmentCenters.first.dx, segmentCenters.first.dy);
      for (int i = 1; i < segmentCenters.length; i++) {
        path.lineTo(segmentCenters[i].dx, segmentCenters[i].dy);
      }
      canvas.drawPath(path, bodyPaint);
    }

    // 2. Draw each segment node for smooth rounded joints
    final nodePaint = Paint()
      ..color = SnakeTheme.snakeColor
      ..style = PaintingStyle.fill;
    final nodeRadius = strokeThickness / 2;
    for (int i = 1; i < segmentCenters.length; i++) {
      canvas.drawCircle(segmentCenters[i], nodeRadius, nodePaint);
    }

    // 3. Draw head at segmentCenters[0]
    final headCenter = segmentCenters.first;
    final double headSize = min(cellWidth, cellHeight) - 2;
    final headRect = Rect.fromCenter(
      center: headCenter,
      width: headSize,
      height: headSize,
    );
    final headPaint = Paint()
      ..color = SnakeTheme.lightGreen
      ..style = PaintingStyle.fill;
    final headRRect = RRect.fromRectAndRadius(
      headRect,
      Radius.circular(strokeThickness * 0.35),
    );
    canvas.drawRRect(headRRect, headPaint);

    // Draw head details (eyes)
    _drawSnakeHead(canvas, headRect, snake.direction);
  }

  void _drawSnakeHead(Canvas canvas, Rect headRect, Direction direction) {
    final eyePaint = Paint()
      ..color = SnakeTheme.background
      ..style = PaintingStyle.fill;

    // Use minimum dimension for eye calculations to ensure circular eyes
    final double minDim = min(headRect.width, headRect.height);
    final double eyeSize = minDim * 0.15;
    final double eyeOffsetX = headRect.width * 0.25;
    final double eyeOffsetY = headRect.height * 0.25;

    Offset leftEye, rightEye;

    switch (direction) {
      case Direction.up:
        leftEye = Offset(
          headRect.left + eyeOffsetX,
          headRect.top + eyeOffsetY,
        );
        rightEye = Offset(
          headRect.right - eyeOffsetX,
          headRect.top + eyeOffsetY,
        );
        break;
      case Direction.down:
        leftEye = Offset(
          headRect.left + eyeOffsetX,
          headRect.bottom - eyeOffsetY,
        );
        rightEye = Offset(
          headRect.right - eyeOffsetX,
          headRect.bottom - eyeOffsetY,
        );
        break;
      case Direction.left:
        leftEye = Offset(
          headRect.left + eyeOffsetY,
          headRect.top + eyeOffsetX,
        );
        rightEye = Offset(
          headRect.left + eyeOffsetY,
          headRect.bottom - eyeOffsetX,
        );
        break;
      case Direction.right:
        leftEye = Offset(
          headRect.right - eyeOffsetY,
          headRect.top + eyeOffsetX,
        );
        rightEye = Offset(
          headRect.right - eyeOffsetY,
          headRect.bottom - eyeOffsetX,
        );
        break;
    }

    canvas.drawCircle(leftEye, eyeSize, eyePaint);
    canvas.drawCircle(rightEye, eyeSize, eyePaint);
  }

  void _drawFood(Canvas canvas, double cellWidth, double cellHeight) {
    final bool isGolden = gameState.isGoldenFood;
    final radius = (min(cellWidth, cellHeight) - 4) / 2;
    final foodsList = gameState.foods.isNotEmpty ? gameState.foods : [gameState.food];

    for (final foodPos in foodsList) {
      final center = Offset(
        foodPos.x * cellWidth + cellWidth / 2,
        foodPos.y * cellHeight + cellHeight / 2,
      );

      if (isGolden) {
        // Draw outer radiant glow ring for Golden Apple
        final glowPaint = Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(center, radius + 2, glowPaint);

        final foodPaint = Paint()
          ..color = const Color(0xFFFFD700)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, radius, foodPaint);

        // Golden inner star/center highlight
        final highlightPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(center.dx - radius * 0.25, center.dy - radius * 0.25),
          radius * 0.35,
          highlightPaint,
        );
      } else {
        final paint = Paint()
          ..color = SnakeTheme.foodColor
          ..style = PaintingStyle.fill;

        // Draw normal food as a circle
        canvas.drawCircle(center, radius, paint);

        // Add shine effect
        final shinePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          Offset(center.dx - radius * 0.3, center.dy - radius * 0.3),
          radius * 0.4,
          shinePaint,
        );
      }
    }
  }

  void _drawGameOverOverlay(Canvas canvas, Size size) {
    // Semi-transparent overlay
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.7);
    
    canvas.drawRect(Offset.zero & size, overlayPaint);

    // Game Over text
    final textStyle = TextStyle(
      color: SnakeTheme.textPrimary,
      fontSize: 32,
      fontWeight: FontWeight.bold,
      fontFamily: SnakeTheme.fontFamily,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: 'FIM DE JOGO', style: textStyle),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  void _drawPausedOverlay(Canvas canvas, Size size) {
    // Semi-transparent overlay
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.5);
    
    canvas.drawRect(Offset.zero & size, overlayPaint);

    // Paused text
    final textStyle = TextStyle(
      color: SnakeTheme.accentColor,
      fontSize: 28,
      fontWeight: FontWeight.bold,
      fontFamily: SnakeTheme.fontFamily,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: 'PAUSADO', style: textStyle),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Always repaint for smooth animation
  }
}
