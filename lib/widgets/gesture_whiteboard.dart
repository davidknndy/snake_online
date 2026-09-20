import 'package:flutter/material.dart';
import '../models/snake_model.dart';
import '../utils/theme.dart';

class GestureWhiteboard extends StatefulWidget {
  final Function(Direction) onDirectionChange;
  final bool isEnabled;

  const GestureWhiteboard({
    super.key,
    required this.onDirectionChange,
    this.isEnabled = true,
  });

  @override
  State<GestureWhiteboard> createState() => _GestureWhiteboardState();
}

class _GestureWhiteboardState extends State<GestureWhiteboard> {
  final List<Offset> _touchPoints = [];
  Direction? _lastDetectedDirection;
  double _accumulatedDx = 0.0;
  double _accumulatedDy = 0.0;
  static const double _swipeSensitivity = 12.0;

  void _handlePanStart(DragStartDetails details) {
    if (!widget.isEnabled) return;
    _accumulatedDx = 0;
    _accumulatedDy = 0;
    setState(() {
      _touchPoints.clear();
      _touchPoints.add(details.localPosition);
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!widget.isEnabled) return;

    _accumulatedDx += details.delta.dx;
    _accumulatedDy += details.delta.dy;

    setState(() {
      _touchPoints.add(details.localPosition);
      // Keep only recent points for a snappy trail
      if (_touchPoints.length > 15) {
        _touchPoints.removeAt(0);
      }
    });

    if (_accumulatedDx.abs() > _swipeSensitivity || _accumulatedDy.abs() > _swipeSensitivity) {
      if (_accumulatedDx.abs() > _accumulatedDy.abs()) {
        if (_accumulatedDx > 0) {
          _triggerDirection(Direction.right);
        } else {
          _triggerDirection(Direction.left);
        }
      } else {
        if (_accumulatedDy > 0) {
          _triggerDirection(Direction.down);
        } else {
          _triggerDirection(Direction.up);
        }
      }
      // Reset accumulated values so continuous dragging can make turns
      _accumulatedDx = 0;
      _accumulatedDy = 0;
    }
  }

  void _triggerDirection(Direction direction) {
    _lastDetectedDirection = direction;
    widget.onDirectionChange(direction);
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _touchPoints.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 2, 10, 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB), // Clean whiteboard color
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SnakeTheme.lightGreen,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: SnakeTheme.primaryGreen.withValues(alpha: 0.15),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          onPanCancel: () => setState(() => _touchPoints.clear()),
          child: Stack(
            children: [
              // Subtle whiteboard grid lines
              CustomPaint(
                size: Size.infinite,
                painter: _WhiteboardGridPainter(),
              ),

              // Interactive finger trail painter
              CustomPaint(
                size: Size.infinite,
                painter: _TouchTrailPainter(points: _touchPoints),
              ),

              // Whiteboard instructions & watermark
              Center(
                child: IgnorePointer(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: SnakeTheme.primaryGreen.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.touch_app_outlined,
                              size: 24,
                              color: SnakeTheme.darkGreen,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'LOUSA DE CONTROLE',
                            style: TextStyle(
                              color: Color(0xFF1B5E20),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Arraste o dedo para guiar a cobra',
                            style: TextStyle(
                              color: Color(0xFF556B2F),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Directional arrows in the corners for quick visual reference
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Icon(
                    Icons.arrow_drop_up,
                    color: _lastDetectedDirection == Direction.up
                        ? SnakeTheme.primaryGreen
                        : const Color(0xFFB0BEC5),
                    size: 24,
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Icon(
                    Icons.arrow_drop_down,
                    color: _lastDetectedDirection == Direction.down
                        ? SnakeTheme.primaryGreen
                        : const Color(0xFFB0BEC5),
                    size: 24,
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Icon(
                    Icons.arrow_left,
                    color: _lastDetectedDirection == Direction.left
                        ? SnakeTheme.primaryGreen
                        : const Color(0xFFB0BEC5),
                    size: 24,
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Icon(
                    Icons.arrow_right,
                    color: _lastDetectedDirection == Direction.right
                        ? SnakeTheme.primaryGreen
                        : const Color(0xFFB0BEC5),
                    size: 24,
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

class _WhiteboardGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE0E6ED)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const double spacing = 24.0;
    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TouchTrailPainter extends CustomPainter {
  final List<Offset> points;

  _TouchTrailPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    for (int i = 0; i < points.length - 1; i++) {
      final progress = (i + 1) / points.length;
      final paint = Paint()
        ..color = Color.lerp(
          Colors.teal.withValues(alpha: 0.3),
          const Color(0xFF1B5E20),
          progress,
        )!
        ..strokeWidth = 3.0 + (progress * 3.0)
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TouchTrailPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

