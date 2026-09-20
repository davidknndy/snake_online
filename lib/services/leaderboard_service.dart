import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

class LeaderboardService extends ChangeNotifier {
  static const String _localLeaderboardKey = 'local_leaderboard';
  static const String _lastResetKey = 'last_leaderboard_reset_epoch';
  
  SharedPreferences? _prefs;
  List<LeaderboardEntry> _localLeaderboard = [];
  List<LeaderboardEntry> _worldwideLeaderboard = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<LeaderboardEntry> get localLeaderboard => List.unmodifiable(_localLeaderboard);
  List<LeaderboardEntry> get worldwideLeaderboard => List.unmodifiable(_worldwideLeaderboard);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize leaderboard service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadLocalLeaderboard();
    await checkWeeklyReset();
    notifyListeners();
  }

  // Calculate next reset date/time (Sundays at 21:00 BRT, which is Mondays at 00:00 UTC)
  static DateTime getNextResetDateTime() {
    final now = DateTime.now().toUtc();
    // Monday is 1, Sunday is 7. Target is next Monday 00:00:00 UTC.
    int daysToAdd = (8 - now.weekday) % 7;
    if (daysToAdd == 0) {
      // It's Monday UTC. Next reset is in 7 days.
      daysToAdd = 7;
    }
    final nextResetUtc = DateTime.utc(now.year, now.month, now.day + daysToAdd, 0, 0, 0);
    return nextResetUtc.toLocal();
  }

  // Get human-readable time remaining until next weekly reset
  static String getFormattedTimeUntilReset() {
    final now = DateTime.now();
    final nextReset = getNextResetDateTime();
    final diff = nextReset.difference(now);
    if (diff.isNegative) {
      return 'Em andamento';
    }
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  // Check if weekly reset has passed and execute reset if needed
  Future<void> checkWeeklyReset() async {
    if (_prefs == null) return;
    final lastReset = _prefs!.getInt(_lastResetKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    // If last reset was more than 7 days ago and we passed a Sunday 21:00 BRT
    if (lastReset > 0 && now - lastReset > 7 * 24 * 60 * 60 * 1000) {
      await _prefs!.setInt(_lastResetKey, now);
      // Weekly cycle reset: maintain historical high score but refresh seasonal trophies if desired
      notifyListeners();
    }
  }

  // Reward Tiers list
  static const List<RewardTier> rewardTiers = [
    RewardTier(
      title: 'Mestre Supremo',
      percentile: 'Top 5%',
      skinName: 'Cobra Dourada Cibernética',
      skinDescription: 'Textura dourada radiante com circuitos neon iluminados e olhos holográficos.',
      primaryColor: Color(0xFFFFD700),
      accentColor: Color(0xFFFFF8DC),
      bonusTrophies: 500,
      icon: Icons.military_tech,
    ),
    RewardTier(
      title: 'Campeão Diamante',
      percentile: 'Top 10%',
      skinName: 'Cobra Elétrica Neon',
      skinDescription: 'Brilho ciano elétrico com rastro de partículas trovejantes e alta reflexão.',
      primaryColor: Color(0xFF00E5FF),
      accentColor: Color(0xFF18FFFF),
      bonusTrophies: 300,
      icon: Icons.diamond,
    ),
    RewardTier(
      title: 'Mestre Platina',
      percentile: 'Top 20%',
      skinName: 'Cobra Cósmica Violeta',
      skinDescription: 'Gradiente púrpura estelar com nebulosas brilhantes e núcleo gravitacional.',
      primaryColor: Color(0xFFBA68C8),
      accentColor: Color(0xFFE1BEE7),
      bonusTrophies: 150,
      icon: Icons.stars,
    ),
    RewardTier(
      title: 'Guerreiro de Ouro',
      percentile: 'Top 30%',
      skinName: 'Cobra Esmeralda Tóxica',
      skinDescription: 'Escamas verdes bio-luminescentes com veneno radioativo e rastro líquido.',
      primaryColor: Color(0xFF00E676),
      accentColor: Color(0xFFB9F6CA),
      bonusTrophies: 80,
      icon: Icons.shield,
    ),
    RewardTier(
      title: 'Sobrevivente de Prata',
      percentile: 'Top 50%',
      skinName: 'Cobra Titânio Metálica',
      skinDescription: 'Carapaça blindada de titânio escovado com acabamento prateado brilhante.',
      primaryColor: Color(0xFFCFD8DC),
      accentColor: Color(0xFFECEFF1),
      bonusTrophies: 40,
      icon: Icons.workspace_premium,
    ),
  ];

  // Helper to determine the tier for a given rank out of total players
  static RewardTier? getTierForRank(int rank, int totalPlayers) {
    if (totalPlayers <= 0 || rank <= 0) return null;
    final percentile = (rank / totalPlayers) * 100.0;
    if (percentile <= 5.0 || rank == 1) return rewardTiers[0];
    if (percentile <= 10.0) return rewardTiers[1];
    if (percentile <= 20.0) return rewardTiers[2];
    if (percentile <= 30.0) return rewardTiers[3];
    if (percentile <= 50.0) return rewardTiers[4];
    return null;
  }

  static const int maxLocalEntries = 10;

  // Load local leaderboard from SharedPreferences
  Future<void> _loadLocalLeaderboard() async {
    if (_prefs == null) return;
    
    try {
      final String? savedData = _prefs!.getString(_localLeaderboardKey);
      if (savedData != null) {
        final List<dynamic> jsonData = json.decode(savedData);
        _localLeaderboard = jsonData
            .map((item) => LeaderboardEntry.fromJson(item))
            .toList();
        
        _sortLocalLeaderboard();
        if (_localLeaderboard.length > maxLocalEntries) {
          _localLeaderboard = _localLeaderboard.take(maxLocalEntries).toList();
          await _saveLocalLeaderboard();
        }
      }
    } catch (e) {
      debugPrint('Error loading local leaderboard: $e');
      _localLeaderboard = [];
    }
  }

  void _sortLocalLeaderboard() {
    _localLeaderboard.sort((a, b) {
      final scoreComp = b.score.compareTo(a.score);
      if (scoreComp != 0) return scoreComp;
      return b.timestamp.compareTo(a.timestamp); // Newest first on tie
    });
  }

  // Save local leaderboard to SharedPreferences
  Future<void> _saveLocalLeaderboard() async {
    if (_prefs == null) return;
    
    try {
      final List<Map<String, dynamic>> jsonData = 
          _localLeaderboard.map((entry) => entry.toJson()).toList();
      await _prefs!.setString(_localLeaderboardKey, json.encode(jsonData));
    } catch (e) {
      debugPrint('Error saving local leaderboard: $e');
    }
  }

  // Add a new local score
  Future<void> addLocalScore(String playerName, int score, int trophies) async {
    // Only save positive scores to avoid cluttering leaderboard with failed starts
    if (score <= 0) return;

    final cleanName = playerName.trim().isEmpty ? 'Jogador Local' : playerName.trim();
    final cleanTrophies = trophies < 0 ? 0 : trophies;

    final entry = LeaderboardEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      playerName: cleanName,
      score: score,
      trophies: cleanTrophies,
      timestamp: DateTime.now(),
      isLocal: true,
    );

    _localLeaderboard.add(entry);
    _sortLocalLeaderboard();
    
    // Keep only the top 10 best local scores, erasing any lower than the 10th
    if (_localLeaderboard.length > maxLocalEntries) {
      _localLeaderboard = _localLeaderboard.take(maxLocalEntries).toList();
    }

    await _saveLocalLeaderboard();
    notifyListeners();
  }

  // Update trophies for existing player (for win/loss system)
  Future<void> updateTrophies(String playerId, int trophyChange, {int? newScore}) async {
    // Update local leaderboard
    final localIndex = _localLeaderboard.indexWhere((entry) => entry.id == playerId);
    if (localIndex != -1) {
      final currentTrophies = _localLeaderboard[localIndex].trophies;
      final newTrophies = (currentTrophies + trophyChange).clamp(0, 999999);
      final updatedEntry = _localLeaderboard[localIndex].copyWith(
        trophies: newTrophies,
        score: newScore ?? _localLeaderboard[localIndex].score,
        timestamp: DateTime.now(),
      );
      
      _localLeaderboard[localIndex] = updatedEntry;
      _localLeaderboard.sort((a, b) => b.score.compareTo(a.score));
      if (_localLeaderboard.length > maxLocalEntries) {
        _localLeaderboard = _localLeaderboard.take(maxLocalEntries).toList();
      }
      
      await _saveLocalLeaderboard();
      notifyListeners();
    }
  }

  // Apply trophy changes based on game result:
  // - Win: +3 points
  // - Draw: +2 points
  // - Loss: if points < 30: +1 point (incentive)
  // - Loss: if points >= 30: -1 point (penalty down to min 0)
  Future<void> applyGameResult(String playerId, bool isWin, int finalScore, {bool isDraw = false}) async {
    final currentTrophies = _getTrophiesById(playerId);
    int trophyChange = 0;
    
    if (isDraw) {
      trophyChange = 2;  // +2 points for draw
    } else if (isWin) {
      trophyChange = 3;  // +3 points for winning
    } else {
      if (currentTrophies < 30) {
        trophyChange = 1;  // +1 consolation point for beginners (< 30 pts)
      } else {
        trophyChange = -1; // -1 competitive loss penalty (>= 30 pts)
      }
    }
    
    await updateTrophies(playerId, trophyChange, newScore: finalScore);
    
    // Also add to local leaderboard if it's a new game session
    final playerName = _getPlayerNameById(playerId) ?? 'Jogador Local';
    await addLocalScore(playerName, finalScore, _getTrophiesById(playerId));
  }

  // Get player name by ID (helper function)
  String? _getPlayerNameById(String playerId) {
    final entry = _localLeaderboard.firstWhere(
      (entry) => entry.id == playerId,
      orElse: () => LeaderboardEntry(
        id: '',
        playerName: '',
        score: 0,
        trophies: 0,
        timestamp: DateTime.now(),
        isLocal: true,
      ),
    );
    return entry.playerName.isNotEmpty ? entry.playerName : null;
  }

  // Get current trophies by ID (helper function)
  int _getTrophiesById(String playerId) {
    final entry = _localLeaderboard.firstWhere(
      (entry) => entry.id == playerId,
      orElse: () => LeaderboardEntry(
        id: '',
        playerName: '',
        score: 0,
        trophies: 0,
        timestamp: DateTime.now(),
        isLocal: true,
      ),
    );
    return entry.trophies;
  }

  // Fetch worldwide leaderboard (placeholder for future API implementation)
  Future<void> fetchWorldwideLeaderboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Replace with actual API endpoint when backend is ready
      // For now, simulate network delay and return mock data
      await Future.delayed(const Duration(seconds: 2));
      
      _worldwideLeaderboard = _generateMockWorldwideData();
      _error = null;
    } catch (e) {
      _error = 'Failed to load worldwide leaderboard: $e';
      debugPrint('Error fetching worldwide leaderboard: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Generate mock worldwide leaderboard data
  List<LeaderboardEntry> _generateMockWorldwideData() {
    final mockData = [
      LeaderboardEntry(
        id: 'world_1',
        playerName: 'SnakeMaster2024',
        score: 1250,
        trophies: 145,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isLocal: false,
      ),
      LeaderboardEntry(
        id: 'world_2',
        playerName: 'RetroGamer',
        score: 980,
        trophies: 132,
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        isLocal: false,
      ),
      LeaderboardEntry(
        id: 'world_3',
        playerName: 'SpeedSnake',
        score: 875,
        trophies: 128,
        timestamp: DateTime.now().subtract(const Duration(hours: 8)),
        isLocal: false,
      ),
      LeaderboardEntry(
        id: 'world_4',
        playerName: 'ClassicFan',
        score: 720,
        trophies: 115,
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isLocal: false,
      ),
      LeaderboardEntry(
        id: 'world_5',
        playerName: 'PixelPro',
        score: 650,
        trophies: 98,
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isLocal: false,
      ),
    ];

    // Add some of the local scores to simulate mixed leaderboard
    mockData.addAll(_localLeaderboard.take(3).map((entry) => 
      entry.copyWith(isLocal: false, playerName: '${entry.playerName} (Você)')));

    // Sort by trophies, then by score
    mockData.sort((a, b) {
      final trophyCompare = b.trophies.compareTo(a.trophies);
      return trophyCompare != 0 ? trophyCompare : b.score.compareTo(a.score);
    });

    return mockData.take(10).toList();
  }

  // Get player rank in local leaderboard
  int getLocalRank(String playerId) {
    final index = _localLeaderboard.indexWhere((entry) => entry.id == playerId);
    return index != -1 ? index + 1 : -1;
  }

  // Get player rank in worldwide leaderboard
  int getWorldwideRank(String playerId) {
    final index = _worldwideLeaderboard.indexWhere((entry) => entry.id == playerId);
    return index != -1 ? index + 1 : -1;
  }

  // Update player name for all entries with the old name (kept for backward compatibility)
  Future<void> updatePlayerName(String oldName, String newName) async {
    if (newName.trim().isEmpty || oldName == newName) return;
    
    bool hasChanges = false;
    for (int i = 0; i < _localLeaderboard.length; i++) {
      if (_localLeaderboard[i].playerName == oldName) {
        _localLeaderboard[i] = _localLeaderboard[i].copyWith(
          playerName: newName.trim(),
        );
        hasChanges = true;
      }
    }
    
    if (hasChanges) {
      await _saveLocalLeaderboard();
      notifyListeners();
    }
  }

  // Update player name for a specific entry by ID
  Future<void> updatePlayerNameById(String entryId, String newName) async {
    if (newName.trim().isEmpty) return;
    
    final index = _localLeaderboard.indexWhere((entry) => entry.id == entryId);
    if (index != -1) {
      _localLeaderboard[index] = _localLeaderboard[index].copyWith(
        playerName: newName.trim(),
      );
      
      await _saveLocalLeaderboard();
      notifyListeners();
    }
  }

  // Clear all local data (for testing or reset)
  Future<void> clearLocalLeaderboard() async {
    _localLeaderboard.clear();
    await _prefs?.remove(_localLeaderboardKey);
    notifyListeners();
  }

  // Submit score to worldwide leaderboard (future API integration)
  Future<void> submitWorldwideScore(String playerName, int score, int trophies) async {
    // TODO: Implement API call to submit score to worldwide leaderboard
    // This would require a backend server with user authentication
    
    // For now, just add to local leaderboard
    await addLocalScore(playerName, score, trophies);
  }
}

// Leaderboard entry model
class LeaderboardEntry {
  final String id;
  final String playerName;
  final int score;
  final int trophies;
  final DateTime timestamp;
  final bool isLocal;

  const LeaderboardEntry({
    required this.id,
    required this.playerName,
    required this.score,
    required this.trophies,
    required this.timestamp,
    required this.isLocal,
  });

  LeaderboardEntry copyWith({
    String? id,
    String? playerName,
    int? score,
    int? trophies,
    DateTime? timestamp,
    bool? isLocal,
  }) {
    return LeaderboardEntry(
      id: id ?? this.id,
      playerName: playerName ?? this.playerName,
      score: score ?? this.score,
      trophies: trophies ?? this.trophies,
      timestamp: timestamp ?? this.timestamp,
      isLocal: isLocal ?? this.isLocal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playerName': playerName,
      'score': score,
      'trophies': trophies,
      'timestamp': timestamp.toIso8601String(),
      'isLocal': isLocal,
    };
  }

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      id: json['id'] ?? '',
      playerName: json['playerName'] ?? '',
      score: json['score'] ?? 0,
      trophies: json['trophies'] ?? 0,
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      isLocal: json['isLocal'] ?? true,
    );
  }

  // Helper getters for display
  String get formattedDate {
    final localTime = timestamp.toLocal();
    
    // Format as dd/MM/yyyy HH:mm
    final day = localTime.day.toString().padLeft(2, '0');
    final month = localTime.month.toString().padLeft(2, '0');
    final year = localTime.year.toString();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    
    return '$day/$month/$year $hour:$minute';
  }

  String get rankIcon {
    // Return trophy emoji based on rank (will be determined when displaying)
    return '🏆';
  }
}

// Reward Tier definition for seasonal leaderboard prizes and skins
class RewardTier {
  final String title;
  final String percentile; // e.g. "Top 5%"
  final String skinName;
  final String skinDescription;
  final Color primaryColor;
  final Color accentColor;
  final int bonusTrophies;
  final IconData icon;

  const RewardTier({
    required this.title,
    required this.percentile,
    required this.skinName,
    required this.skinDescription,
    required this.primaryColor,
    required this.accentColor,
    required this.bonusTrophies,
    required this.icon,
  });
}
