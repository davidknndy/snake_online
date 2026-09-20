import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/leaderboard_service.dart';
import '../services/auth_service.dart';
import '../utils/theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load leaderboards when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final leaderboardService = Provider.of<LeaderboardService>(context, listen: false);
      leaderboardService.fetchWorldwideLeaderboard();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnakeTheme.background,
      appBar: AppBar(
        title: const Text(
          'Classificação',
          style: TextStyle(
            color: SnakeTheme.textPrimary,
            fontWeight: FontWeight.bold,

          ),
        ),
        backgroundColor: SnakeTheme.darkGreen,
        iconTheme: const IconThemeData(color: SnakeTheme.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          labelColor: SnakeTheme.accentColor,
          unselectedLabelColor: SnakeTheme.textSecondary,
          indicatorColor: SnakeTheme.accentColor,
          labelStyle: const TextStyle(

            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.home),
              text: 'LOCAL',
            ),
            Tab(
              icon: Icon(Icons.public),
              text: 'MUNDIAL',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final leaderboardService = Provider.of<LeaderboardService>(context, listen: false);
              leaderboardService.fetchWorldwideLeaderboard();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLocalLeaderboard(),
          _buildWorldwideLeaderboard(),
        ],
      ),
    );
  }

  Widget _buildLocalLeaderboard() {
    return Consumer<LeaderboardService>(
      builder: (context, leaderboardService, child) {
        final entries = leaderboardService.localLeaderboard;
        
        if (entries.isEmpty) {
          return _buildEmptyState(
            'Nenhuma Pontuação Local Ainda',
            'Jogue alguns jogos para ver suas pontuações aqui!',
            Icons.sports_esports,
          );
        }

        return Column(
          children: [
            // Top 10 only informative banner
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SnakeTheme.cardBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SnakeTheme.accentColor.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: SnakeTheme.accentColor,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Exibindo apenas o Top 10 das melhores partidas locais. Partidas abaixo do 10º lugar são descartadas.',
                      style: TextStyle(
                        color: SnakeTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Show hint for local entries
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: SnakeTheme.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SnakeTheme.primaryGreen.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: SnakeTheme.primaryGreen,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Clique no ícone de edição (✏️) para renomear qualquer entrada local',
                      style: TextStyle(
                        color: SnakeTheme.primaryGreen,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildLeaderboardList(entries.take(10).toList(), isLocal: true)),
          ],
        );
      },
    );
  }

  Widget _buildWorldwideLeaderboard() {
    return Consumer<LeaderboardService>(
      builder: (context, leaderboardService, child) {
        if (leaderboardService.isLoading) {
          return _buildLoadingState();
        }

        if (leaderboardService.error != null) {
          return _buildErrorState(leaderboardService.error!);
        }

        final entries = leaderboardService.worldwideLeaderboard;
        
        return Column(
          children: [
            _buildWeeklyResetBanner(),
            if (entries.isEmpty)
              Expanded(
                child: _buildEmptyState(
                  'Nenhum Dado Mundial',
                  'Verifique sua conexão e tente atualizar',
                  Icons.public_off,
                ),
              )
            else
              Expanded(
                child: _buildLeaderboardList(entries, isLocal: false),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWeeklyResetBanner() {
    final timeRemaining = LeaderboardService.getFormattedTimeUntilReset();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SnakeTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SnakeTheme.accentColor.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: SnakeTheme.darkGreen.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SnakeTheme.accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.access_time_filled,
                  color: SnakeTheme.accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TEMPORADA SEMANAL',
                      style: TextStyle(
                        color: SnakeTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,

                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Reset: Todo Domingo às 21:00 BRT',
                      style: TextStyle(
                        color: SnakeTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,

                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SnakeTheme.primaryGreen.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SnakeTheme.lightGreen),
                ),
                child: Text(
                  timeRemaining,
                  style: const TextStyle(
                    color: SnakeTheme.lightGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,

                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: SnakeTheme.darkGreen, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Suba no ranking para conquistar skins exclusivas!',
                  style: TextStyle(
                    color: SnakeTheme.textSecondary.withValues(alpha: 0.8),
                    fontSize: 11,

                  ),
                ),
              ),
              InkWell(
                onTap: _showRewardsDialog,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: SnakeTheme.accentColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events, size: 14, color: SnakeTheme.background),
                      SizedBox(width: 4),
                      Text(
                        'VER PRÊMIOS',
                        style: TextStyle(
                          color: SnakeTheme.background,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,

                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRewardsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SnakeTheme.cardBackground,
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: SnakeTheme.accentColor),
            SizedBox(width: 8),
            Text(
              'Prêmios & Skins',
              style: TextStyle(
                color: SnakeTheme.textPrimary,

                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scoring explanation card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SnakeTheme.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SnakeTheme.lightGreen),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.rule, color: SnakeTheme.accentColor, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'SISTEMA DE PONTOS',
                            style: TextStyle(
                              color: SnakeTheme.accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,

                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        '• Vitória online: +3 pontos\n'
                        '• Derrota (< 30 pts): +1 ponto (incentivo)\n'
                        '• Derrota (≥ 30 pts): -1 ponto (penalidade)\n'
                        '• Reset semanal: Todo Domingo às 21:00 BRT',
                        style: TextStyle(
                          color: SnakeTheme.textPrimary,
                          fontSize: 12,

                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'RECOMPENSAS POR CLASSIFICAÇÃO:',
                  style: TextStyle(
                    color: SnakeTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,

                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                ...LeaderboardService.rewardTiers.map((tier) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SnakeTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tier.primaryColor, width: 1.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: tier.primaryColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(tier.icon, color: tier.primaryColor, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    tier.percentile,
                                    style: TextStyle(
                                      color: tier.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,

                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${tier.title})',
                                    style: const TextStyle(
                                      color: SnakeTheme.textSecondary,
                                      fontSize: 11,

                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Skin: ${tier.skinName}',
                                style: TextStyle(
                                  color: tier.accentColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,

                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tier.skinDescription,
                                style: TextStyle(
                                  color: SnakeTheme.textSecondary.withValues(alpha: 0.8),
                                  fontSize: 10,

                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '+${tier.bonusTrophies} Troféus de Bônus',
                                style: const TextStyle(
                                  color: SnakeTheme.lightGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,

                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: SnakeTheme.primaryGreen,
              foregroundColor: SnakeTheme.textPrimary,
            ),
            child: const Text(
              'Fechar',
              style: TextStyle( fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(List<LeaderboardEntry> entries, {required bool isLocal}) {
    return RefreshIndicator(
      onRefresh: () async {
        final leaderboardService = Provider.of<LeaderboardService>(context, listen: false);
        if (!isLocal) {
          await leaderboardService.fetchWorldwideLeaderboard();
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final rank = index + 1;
          
          return _buildLeaderboardCard(entry, rank, isLocal, totalPlayers: entries.length);
        },
      ),
    );
  }

  Widget _buildLeaderboardCard(LeaderboardEntry entry, int rank, bool isLocal, {int totalPlayers = 100}) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isCurrentUser = authService.currentUser?.name == entry.playerName || 
                         entry.playerName.contains('(You)') ||
                         entry.playerName.contains('(Você)');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrentUser ? SnakeTheme.primaryGreen.withValues(alpha: 0.2) : SnakeTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser ? SnakeTheme.accentColor : SnakeTheme.lightGreen,
          width: isCurrentUser ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: SnakeTheme.darkGreen.withOpacity(0.3),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildRankBadge(rank),

        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.playerName,
                style: TextStyle(
                  color: isCurrentUser ? SnakeTheme.accentColor : SnakeTheme.textPrimary,
                  fontWeight: FontWeight.bold,

                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SnakeTheme.accentColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'VOCÊ',
                  style: TextStyle(
                    color: SnakeTheme.background,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,

                  ),
                ),
              ),
            if (isLocal)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: InkWell(
                  onTap: () => _showRenameDialog(entry.id, entry.playerName),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: SnakeTheme.accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: SnakeTheme.accentColor.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.edit,
                      size: 18,
                      color: SnakeTheme.accentColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  size: 16,
                  color: SnakeTheme.accentColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Pontuação: ${entry.score}',
                  style: const TextStyle(
                    color: SnakeTheme.textSecondary,

                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.military_tech,
                  size: 16,
                  color: SnakeTheme.lightGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  '${entry.trophies} 🏆',
                  style: const TextStyle(
                    color: SnakeTheme.textSecondary,

                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              entry.formattedDate,
              style: const TextStyle(
                color: SnakeTheme.textSecondary,

                fontSize: 10,
              ),
            ),
          ],
        ),
        trailing: isLocal 
          ? _buildLocalBadge()
          : _buildWorldwideBadge(rank, totalPlayers),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color badgeColor;
    IconData icon;
    
    switch (rank) {
      case 1:
        badgeColor = const Color(0xFFFFD700); // Gold
        icon = Icons.looks_one;
        break;
      case 2:
        badgeColor = const Color(0xFFC0C0C0); // Silver
        icon = Icons.looks_two;
        break;
      case 3:
        badgeColor = const Color(0xFFCD7F32); // Bronze
        icon = Icons.looks_3;
        break;
      default:
        badgeColor = SnakeTheme.lightGreen;
        icon = Icons.person;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor, width: 2),
      ),
      child: rank <= 3
          ? Icon(icon, color: badgeColor, size: 20)
          : Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,

                  fontSize: 14,
                ),
              ),
            ),
    );
  }

  Widget _buildLocalBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: SnakeTheme.primaryGreen,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: SnakeTheme.primaryGreen.withValues(alpha: 0.3),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: const Text(
        'LOCAL',
        style: TextStyle(
          color: SnakeTheme.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.bold,

        ),
      ),
    );
  }

  Widget _buildWorldwideBadge(int rank, int totalPlayers) {
    final tier = LeaderboardService.getTierForRank(rank, totalPlayers);
    if (tier != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: tier.primaryColor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tier.primaryColor, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              tier.percentile,
              style: TextStyle(
                color: tier.primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,

              ),
            ),
            Text(
              tier.title,
              style: TextStyle(
                color: tier.accentColor,
                fontSize: 8,
                fontWeight: FontWeight.bold,

              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SnakeTheme.accentColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SnakeTheme.accentColor),
      ),
      child: const Text(
        'GLOBAL',
        style: TextStyle(
          color: SnakeTheme.accentColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,

        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: SnakeTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: SnakeTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,

              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: const TextStyle(
                color: SnakeTheme.textSecondary,
                fontSize: 16,

              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/local-game'),
              icon: const Icon(Icons.play_arrow, color: SnakeTheme.textPrimary),
              label: const Text(
                'JOGAR AGORA',
                style: TextStyle(
                  color: SnakeTheme.textPrimary,
                  fontWeight: FontWeight.bold,

                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: SnakeTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: SnakeTheme.accentColor,
            strokeWidth: 3,
          ),
          SizedBox(height: 24),
          Text(
            'Carregando Classificação Mundial...',
            style: TextStyle(
              color: SnakeTheme.textSecondary,
              fontSize: 16,

            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            const Text(
              'Erro de Conexão',
              style: TextStyle(
                color: SnakeTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,

              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: const TextStyle(
                color: SnakeTheme.textSecondary,
                fontSize: 14,

              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                final leaderboardService = Provider.of<LeaderboardService>(context, listen: false);
                leaderboardService.fetchWorldwideLeaderboard();
              },
              icon: const Icon(Icons.refresh, color: SnakeTheme.textPrimary),
              label: const Text(
                'TENTAR NOVAMENTE',
                style: TextStyle(
                  color: SnakeTheme.textPrimary,
                  fontWeight: FontWeight.bold,

                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: SnakeTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(String entryId, String currentName) {
    final TextEditingController controller = TextEditingController(text: currentName);
    controller.selection = TextSelection(baseOffset: 0, extentOffset: currentName.length);
    String? errorMessage;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: SnakeTheme.cardBackground,
              title: const Text(
                'Renomear Jogador',
                style: TextStyle(
                  color: SnakeTheme.textPrimary,

                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Digite um novo nome para "$currentName"',
                    style: const TextStyle(
                      color: SnakeTheme.textSecondary,

                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    style: const TextStyle(
                      color: SnakeTheme.textPrimary,

                    ),
                    decoration: InputDecoration(
                      hintText: 'Digite seu nome',
                      errorText: errorMessage,
                      hintStyle: const TextStyle(color: SnakeTheme.textSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: SnakeTheme.lightGreen),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: SnakeTheme.accentColor, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLength: 20,
                    autofocus: true,
                    onChanged: (_) {
                      if (errorMessage != null) {
                        setDialogState(() {
                          errorMessage = null;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: SnakeTheme.lightGreen),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newName = controller.text.trim();
                    if (newName.isEmpty) {
                      setDialogState(() {
                        errorMessage = 'O nome não pode ficar em branco';
                      });
                      return;
                    }
                    if (newName == currentName) {
                      Navigator.of(context).pop();
                      return;
                    }

                    final leaderboardService = Provider.of<LeaderboardService>(context, listen: false);
                    await leaderboardService.updatePlayerNameById(entryId, newName);
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Esta entrada foi renomeada para "$newName"'),
                          backgroundColor: SnakeTheme.primaryGreen,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SnakeTheme.primaryGreen,
                    foregroundColor: SnakeTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text(
                    'Renomear',
                    style: TextStyle(
                      color: SnakeTheme.textPrimary,
                      fontWeight: FontWeight.bold,

                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
