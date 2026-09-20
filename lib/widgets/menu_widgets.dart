import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/audio_service.dart';

class MenuButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isPrimary;
  final bool isEnabled;

  const MenuButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isPrimary = false,
    this.isEnabled = true,
  });

  @override
  State<MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: SnakeTheme.fastAnimation,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.isEnabled) return;
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (!widget.isEnabled) return;
    setState(() => _isPressed = false);
    _animationController.reverse();
    // Play button click sound
    AudioService().playButtonClick();
    widget.onPressed();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: widget.isEnabled
                    ? (widget.isPrimary
                        ? const LinearGradient(
                            colors: [SnakeTheme.buttonColor, SnakeTheme.primaryGreen],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null)
                    : null,
                color: widget.isEnabled
                    ? (widget.isPrimary ? null : Colors.transparent)
                    : SnakeTheme.buttonDisabled,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isEnabled 
                      ? SnakeTheme.lightGreen 
                      : SnakeTheme.buttonDisabled,
                  width: 2,
                ),
                boxShadow: widget.isEnabled && _isPressed
                    ? []
                    : [
                        BoxShadow(
                          color: SnakeTheme.darkGreen.withOpacity(0.3),
                          offset: const Offset(0, 4),
                          blurRadius: 8,
                        ),
                      ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        color: widget.isEnabled 
                            ? SnakeTheme.textPrimary 
                            : SnakeTheme.textSecondary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      widget.text,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: widget.isEnabled 
                            ? SnakeTheme.textPrimary 
                            : SnakeTheme.textSecondary,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class RetroTitle extends StatefulWidget {
  final String title;

  const RetroTitle({super.key, required this.title});

  @override
  State<RetroTitle> createState() => _RetroTitleState();
}

class _RetroTitleState extends State<RetroTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Text(
          widget.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: SnakeTheme.textPrimary,
            letterSpacing: 2.0,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: SnakeTheme.accentColor.withOpacity(_glowAnimation.value),
                offset: const Offset(0, 0),
                blurRadius: 20,
              ),
              Shadow(
                color: SnakeTheme.primaryGreen.withOpacity(_glowAnimation.value * 0.5),
                offset: const Offset(0, 0),
                blurRadius: 40,
              ),
            ],
          ),
        );
      },
    );
  }
}
