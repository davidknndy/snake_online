import 'package:flutter/material.dart';
import '../models/snake_model.dart';
import '../utils/theme.dart';

class GameControls extends StatelessWidget {
  final Function(Direction) onDirectionChange;
  final bool isEnabled;

  const GameControls({
    super.key,
    required this.onDirectionChange,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Up button
        _buildControlButton(
          icon: Icons.keyboard_arrow_up,
          onPressed: () => onDirectionChange(Direction.up),
        ),
        
        const SizedBox(height: 8),
        
        // Left, Center, Right buttons row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: Icons.keyboard_arrow_left,
              onPressed: () => onDirectionChange(Direction.left),
            ),
            
            // Center info/pause button (optional)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: SnakeTheme.cardBackground.withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(color: SnakeTheme.lightGreen, width: 2),
              ),
              child: const Icon(
                Icons.swipe,
                color: SnakeTheme.textSecondary,
                size: 24,
              ),
            ),
            
            _buildControlButton(
              icon: Icons.keyboard_arrow_right,
              onPressed: () => onDirectionChange(Direction.right),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Down button
        _buildControlButton(
          icon: Icons.keyboard_arrow_down,
          onPressed: () => onDirectionChange(Direction.down),
        ),
        
        const SizedBox(height: 16),
        
        // Instructions
        Text(
          'Use os botões direcionais para controlar a cobra',
          style: TextStyle(
            color: SnakeTheme.textSecondary.withOpacity(0.7),
            fontSize: 12,

          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isEnabled 
              ? SnakeTheme.buttonColor 
              : SnakeTheme.buttonDisabled,
          shape: BoxShape.circle,
          border: Border.all(
            color: isEnabled 
                ? SnakeTheme.lightGreen 
                : SnakeTheme.textSecondary,
            width: 2,
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: SnakeTheme.darkGreen.withOpacity(0.3),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ]
              : [],
        ),
        child: Icon(
          icon,
          color: isEnabled 
              ? SnakeTheme.textPrimary 
              : SnakeTheme.textSecondary,
          size: 28,
        ),
      ),
    );
  }
}

// Alternative control widget for different control types
class SwipeOnlyControls extends StatelessWidget {
  const SwipeOnlyControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SnakeTheme.cardBackground.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SnakeTheme.lightGreen.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.swipe,
            color: SnakeTheme.accentColor,
            size: 32,
          ),
          const SizedBox(height: 8),
          const Text(
            'Deslize na lousa para controlar a cobra',
            style: TextStyle(
              color: SnakeTheme.textSecondary,
              fontSize: 14,

            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDirectionIndicator(Icons.arrow_upward, 'Cima'),
              _buildDirectionIndicator(Icons.arrow_back, 'Esquerda'),
              _buildDirectionIndicator(Icons.arrow_forward, 'Direita'),
              _buildDirectionIndicator(Icons.arrow_downward, 'Baixo'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionIndicator(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: SnakeTheme.lightGreen,
          size: 20,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: SnakeTheme.textSecondary,
            fontSize: 10,

          ),
        ),
      ],
    );
  }
}
