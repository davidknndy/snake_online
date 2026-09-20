import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/leaderboard_service.dart';
import '../services/settings_service.dart';
import '../utils/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnakeTheme.background,
      appBar: AppBar(
        title: const Text(
          'Configurações',
          style: TextStyle(
            color: SnakeTheme.textPrimary,
            fontWeight: FontWeight.bold,

          ),
        ),
        backgroundColor: SnakeTheme.darkGreen,
        iconTheme: const IconThemeData(color: SnakeTheme.textPrimary),
      ),
      body: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Audio Settings
                _buildSectionHeader('Áudio', Icons.volume_up),
                const SizedBox(height: 16),
                _buildSettingCard([
                  _buildSwitchTile(
                    'Efeitos Sonoros',
                    'Sons e efeitos do jogo',
                    Icons.music_note,
                    settings.soundEnabled,
                    (value) => settings.setSoundEnabled(value),
                  ),
                  _buildSwitchTile(
                    'Música de Fundo',
                    'Música do menu e jogo',
                    Icons.library_music,
                    settings.musicEnabled,
                    (value) => settings.setMusicEnabled(value),
                  ),
                  _buildSwitchTile(
                    'Vibração',
                    'Feedback tátil na colisão',
                    Icons.vibration,
                    settings.vibrationEnabled,
                    (value) => settings.setVibrationEnabled(value),
                  ),
                ]),

                const SizedBox(height: 24),

                // Game Settings
                _buildSectionHeader('Jogo', Icons.gamepad),
                const SizedBox(height: 16),
                _buildSettingCard([
                  _buildSliderTile(
                    'Velocidade Inicial',
                    settings.speedLabel,
                    Icons.speed,
                    settings.speedIndex.toDouble(),
                    0.0,
                    2.0,
                    (value) => settings.setSpeedByIndex(value.round()),
                    subtitle: 'A partida dura 2 min e acelera a cada 30 segundos!',
                  ),
                  _buildSliderTile(
                    'Tamanho da Grade',
                    '${settings.gridSize}x${settings.gridSize}',
                    Icons.grid_4x4,
                    settings.gridSize.toDouble(),
                    15.0,
                    25.0,
                    (value) => settings.setGridSize(value.round()),
                  ),
                  _buildDropdownTile(
                    'Controles',
                    settings.controlType.displayName,
                    Icons.control_camera,
                    ControlType.values,
                    settings.controlType,
                    (value) => settings.setControlType(value),
                  ),
                ]),

                const SizedBox(height: 24),

                // Statistics
                _buildSectionHeader('Estatísticas', Icons.analytics),
                const SizedBox(height: 16),
                _buildSettingCard([
                  _buildStatTile(
                    'Pontuação Máxima',
                    settings.highScore.toString(),
                    Icons.emoji_events,
                  ),
                  _buildStatTile(
                    'Jogos Jogados',
                    settings.gamesPlayed.toString(),
                    Icons.sports_esports,
                  ),
                  _buildStatTile(
                    'Dificuldade',
                    settings.difficulty.displayName,
                    Icons.trending_up,
                  ),
                ]),
                const SizedBox(height: 16),
                _buildTop10LocalPlaysCard(context),

                const SizedBox(height: 24),

                // Actions
                _buildSectionHeader('Ações', Icons.settings_backup_restore),
                const SizedBox(height: 16),
                _buildSettingCard([
                  _buildActionTile(
                    'Resetar Configurações',
                    'Restaurar configurações padrão do jogo',
                    Icons.restore,
                    Colors.orange,
                    () => _showResetDialog(context, settings, false),
                  ),
                  _buildActionTile(
                    'Resetar Estatísticas',
                    'Limpar pontuação, jogos e Classificação Local',
                    Icons.delete_forever,
                    Colors.red,
                    () => _showResetDialog(context, settings, true),
                  ),
                ]),

                const SizedBox(height: 24),

                // About section
                _buildSectionHeader('Sobre', Icons.info_outline),
                const SizedBox(height: 16),
                _buildSettingCard([
                  _buildActionTile(
                    'Sobre o Jogo',
                    'DK Studio Apps, versão e créditos',
                    Icons.info,
                    SnakeTheme.accentColor,
                    () => Navigator.pushNamed(context, '/about'),
                  ),
                ]),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: SnakeTheme.accentColor,
          size: 24,
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: SnakeTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,

          ),
        ),
      ],
    );
  }

  Widget _buildSettingCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: SnakeTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SnakeTheme.lightGreen, width: 1),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: SnakeTheme.lightGreen,
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: SnakeTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,

        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: SnakeTheme.textSecondary,
          fontSize: 12,

        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: SnakeTheme.accentColor,
        activeTrackColor: SnakeTheme.primaryGreen,
        inactiveThumbColor: SnakeTheme.buttonDisabled,
        inactiveTrackColor: SnakeTheme.darkGreen,
      ),
    );
  }

  Widget _buildSliderTile(
    String title,
    String value,
    IconData icon,
    double currentValue,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: SnakeTheme.lightGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: SnakeTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,

                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: SnakeTheme.textSecondary,
                          fontSize: 11,

                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SnakeTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  style: const TextStyle(
                    color: SnakeTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,

                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) => SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: SnakeTheme.primaryGreen,
                inactiveTrackColor: SnakeTheme.darkGreen,
                thumbColor: SnakeTheme.accentColor,
                overlayColor: SnakeTheme.accentColor.withOpacity(0.2),
                valueIndicatorColor: SnakeTheme.cardBackground,
                valueIndicatorTextStyle: const TextStyle(
                  color: SnakeTheme.textPrimary,

                ),
              ),
              child: Slider(
                value: currentValue.clamp(min, max),
                min: min,
                max: max,
                divisions: (max - min).round(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String currentValue,
    IconData icon,
    List<ControlType> options,
    ControlType selectedValue,
    ValueChanged<ControlType> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            icon,
            color: SnakeTheme.lightGreen,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: SnakeTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,

                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedValue.description,
                  style: const TextStyle(
                    color: SnakeTheme.textSecondary,
                    fontSize: 12,

                  ),
                ),
              ],
            ),
          ),
          DropdownButton<ControlType>(
            value: selectedValue,
            onChanged: (ControlType? newValue) {
              if (newValue != null) {
                onChanged(newValue);
              }
            },
            dropdownColor: SnakeTheme.cardBackground,
            style: const TextStyle(
              color: SnakeTheme.textPrimary,

            ),
            items: options.map<DropdownMenuItem<ControlType>>((ControlType type) {
              return DropdownMenuItem<ControlType>(
                value: type,
                child: Text(type.displayName),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String title, String value, IconData icon) {
    return ListTile(
      leading: Icon(
        icon,
        color: SnakeTheme.accentColor,
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: SnakeTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,

        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: SnakeTheme.primaryGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: SnakeTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,

          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor,
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: SnakeTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,

        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: SnakeTheme.textSecondary,
          fontSize: 12,

        ),
      ),
      onTap: onTap,
    );
  }

  void _showResetDialog(BuildContext context, SettingsService settings, bool isStats) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: SnakeTheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: SnakeTheme.lightGreen, width: 2),
          ),
          title: Text(
            isStats ? 'Resetar Estatísticas?' : 'Resetar Configurações?',
            style: const TextStyle(
              color: SnakeTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            isStats
                ? 'Isso irá limpar sua pontuação máxima, troféus, contagem de jogos e todo o histórico da Classificação Local. Esta ação não pode ser desfeita.'
                : 'Isso irá restaurar todas as configurações para seus valores padrão. Esta ação não pode ser desfeita.',
            style: const TextStyle(
              color: SnakeTheme.textSecondary,
              fontSize: 15,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
                backgroundColor: isStats ? const Color(0xFFD32F2F) : Colors.orange.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () async {
                final leaderboard = Provider.of<LeaderboardService>(context, listen: false);
                final auth = Provider.of<AuthService>(context, listen: false);
                Navigator.of(context).pop();
                if (isStats) {
                  await settings.resetGameStats();
                  await leaderboard.clearLocalLeaderboard();
                  await auth.resetUserStats();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Estatísticas e Classificação Local limpas com sucesso!'),
                        backgroundColor: SnakeTheme.primaryGreen,
                      ),
                    );
                  }
                } else {
                  await settings.resetSettings();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Configurações resetadas para o padrão!'),
                        backgroundColor: SnakeTheme.primaryGreen,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Resetar',
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
  }

  Widget _buildTop10LocalPlaysCard(BuildContext context) {
    return Consumer<LeaderboardService>(
      builder: (context, leaderboard, child) {
        final entries = leaderboard.localLeaderboard.take(10).toList();
        return Container(
          decoration: BoxDecoration(
            color: SnakeTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SnakeTheme.lightGreen, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.military_tech,
                      color: SnakeTheme.accentColor,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Top 10 Melhores Partidas Locais',
                        style: TextStyle(
                          color: SnakeTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: SnakeTheme.primaryGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: SnakeTheme.primaryGreen.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        '${entries.length}/10',
                        style: const TextStyle(
                          color: SnakeTheme.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Explanatory message indicating only top 10 are kept and displayed
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: SnakeTheme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: SnakeTheme.accentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: SnakeTheme.accentColor,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Exibindo apenas o Top 10 das melhores partidas locais. Partidas abaixo do 10º lugar são descartadas automaticamente.',
                        style: TextStyle(
                          color: SnakeTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Center(
                    child: Text(
                      'Nenhuma partida local registrada ainda.\nJogue uma partida local para figurar no ranking!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: SnakeTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entries.length,
                  separatorBuilder: (context, index) => Divider(
                    color: SnakeTheme.lightGreen.withValues(alpha: 0.2),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final rank = index + 1;
                    Color rankColor = SnakeTheme.textSecondary;
                    if (rank == 1) {
                      rankColor = const Color(0xFFFFD700);
                    } else if (rank == 2) {
                      rankColor = const Color(0xFFC0C0C0);
                    } else if (rank == 3) {
                      rankColor = const Color(0xFFCD7F32);
                    }

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      leading: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: rank <= 3
                              ? rankColor.withValues(alpha: 0.2)
                              : Colors.transparent,
                          border: Border.all(
                            color: rankColor.withValues(alpha: 0.6),
                            width: rank <= 3 ? 1.5 : 1.0,
                          ),
                        ),
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            color: rankColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        entry.playerName,
                        style: const TextStyle(
                          color: SnakeTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        entry.formattedDate,
                        style: const TextStyle(
                          color: SnakeTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${entry.score} pts',
                            style: const TextStyle(
                              color: SnakeTheme.accentColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (entry.trophies > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: SnakeTheme.primaryGreen.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.emoji_events,
                                    size: 12,
                                    color: SnakeTheme.accentColor,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${entry.trophies}',
                                    style: const TextStyle(
                                      color: SnakeTheme.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

