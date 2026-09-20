import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/theme.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '1.0.0';
  String _buildNumber = '1';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = info.version.isNotEmpty ? info.version : '1.0.0';
          _buildNumber = info.buildNumber.isNotEmpty ? info.buildNumber : '1';
        });
      }
    } catch (e) {
      // Fallback for environments where PackageInfo might not be supported
      debugPrint('Error loading package info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnakeTheme.background,
      appBar: AppBar(
        title: const Text(
          'Sobre',
          style: TextStyle(
            color: SnakeTheme.textPrimary,
            fontWeight: FontWeight.bold,

          ),
        ),
        backgroundColor: SnakeTheme.darkGreen,
        iconTheme: const IconThemeData(color: SnakeTheme.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Retro Logo Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SnakeTheme.cardBackground,
                shape: BoxShape.circle,
                border: Border.all(color: SnakeTheme.accentColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: SnakeTheme.accentColor.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/snakeic.png',
                  width: 76,
                  height: 76,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // App Title
            const Text(
              'SNAKE ONLINE',
              style: TextStyle(
                color: SnakeTheme.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.bold,

                letterSpacing: 3.0,
              ),
            ),
            const SizedBox(height: 6),

            // Version Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: SnakeTheme.primaryGreen.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SnakeTheme.lightGreen),
              ),
              child: Text(
                'Versão $_version (Build $_buildNumber)',
                style: const TextStyle(
                  color: SnakeTheme.lightGreen,
                  fontSize: 13,

                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Developer Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: SnakeTheme.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SnakeTheme.lightGreen, width: 1.5),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.code,
                        color: SnakeTheme.accentColor,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'DESENVOLVIDO POR',
                        style: TextStyle(
                          color: SnakeTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,

                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'DK Studio Apps',
                    style: TextStyle(
                      color: SnakeTheme.accentColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,

                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Game Description Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: SnakeTheme.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SnakeTheme.lightGreen, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.videogame_asset,
                        color: SnakeTheme.accentColor,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'SOBRE O JOGO',
                        style: TextStyle(
                          color: SnakeTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,

                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Inspirado no clássico jogo da cobrinha dos celulares Nokia, '
                    'o Snake Online traz a nostalgia dos anos 90 e 2000 em uma experiência '
                    'moderna, fluida e competitiva.',
                    style: TextStyle(
                      color: SnakeTheme.textSecondary,
                      fontSize: 14,

                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: SnakeTheme.darkGreen, thickness: 1),
                  const SizedBox(height: 12),
                  _buildFeatureRow(
                    Icons.timer,
                    'Arena de 2 Minutos',
                    'Sobreviva aos 120 segundos da partida acumulando o máximo de maçãs!',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureRow(
                    Icons.bolt,
                    'Aceleração Progressiva',
                    'A cada 30 segundos, a velocidade da cobra sobe de nível!',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureRow(
                    Icons.draw,
                    'Lousa Tátil de Gestos',
                    'Controle a cobra arrastando o dedo em uma lousa com rastro tátil dinâmico.',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureRow(
                    Icons.emoji_events,
                    'Placar de Recordes',
                    'Acompanhe seus recordes e dispute os melhores lugares da classificação.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Copyright footer
            Text(
              '© ${DateTime.now().year} DK Studio Apps.\nTodos os direitos reservados.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SnakeTheme.textSecondary,
                fontSize: 12,

                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: SnakeTheme.accentColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: SnakeTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,

                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: SnakeTheme.textSecondary,
                  fontSize: 12,

                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

