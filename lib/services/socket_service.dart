import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import '../models/snake_model.dart';
import '../models/user_model.dart';

class SocketService extends ChangeNotifier {
  static const String defaultServerUrl = 'https://snake-online-server-uxpy.onrender.com';
  static const String gameSecretToken = 'dk_snake_live_sec_78f29a0b12';
  
  io.Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _error;
  String? _gameId;
  User? _currentUser;
  
  // Game state callbacks
  Function(GameState)? onGameStateUpdate;
  Function(GameState)? onGameStart;
  Function(GameResult_)? onGameEnd;
  Function(User)? onOpponentJoined;
  Function()? onOpponentLeft;
  Function(String)? onMatchFound;
  Function(Map<String, dynamic>)? onRealMatchFound;
  Function(Map<String, dynamic>)? onOpponentAppleEaten;
  Function(Map<String, dynamic>)? onOpponentCrashed;
  Function()? onMatchmakingCanceled;
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get error => _error;
  String? get gameId => _gameId;
  
  // Initialize socket connection
  Future<void> connect({String? serverUrl, User? user}) async {
    if (_isConnecting || _isConnected) return;
    
    _isConnecting = true;
    _currentUser = user;
    _clearError();
    notifyListeners();
    
    try {
      _socket = io.io(
        serverUrl ?? defaultServerUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .setAuth({'token': gameSecretToken})
            .setExtraHeaders({'x-game-token': gameSecretToken})
            .build(),
      );
      
      _setupSocketListeners();
      
      // Authenticate if user is provided
      if (_currentUser != null) {
        _socket!.emit('authenticate', _currentUser!.toJson());
      }
      
    } catch (e) {
      _setError('Failed to connect to server: ${e.toString()}');
      _isConnecting = false;
      notifyListeners();
    }
  }
  
  // Disconnect from socket
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isConnecting = false;
    _gameId = null;
    _clearError();
    notifyListeners();
  }
  
  // Setup socket event listeners
  void _setupSocketListeners() {
    if (_socket == null) return;
    
    // Connection events
    _socket!.onConnect((_) {
      _isConnected = true;
      _isConnecting = false;
      _clearError();
      notifyListeners();
      debugPrint('Socket connected');
    });
    
    _socket!.onDisconnect((_) {
      _isConnected = false;
      _isConnecting = false;
      notifyListeners();
      debugPrint('Socket disconnected');
    });
    
    _socket!.onConnectError((error) {
      _setError('Connection error: ${error.toString()}');
      _isConnecting = false;
      notifyListeners();
      debugPrint('Socket connection error: $error');
    });
    
    _socket!.onError((error) {
      _setError('Socket error: ${error.toString()}');
      debugPrint('Socket error: $error');
    });
    
    // Game events
    _socket!.on('match_found', (data) {
      if (data is Map) {
        _gameId = data['gameId']?.toString();
        onRealMatchFound?.call(Map<String, dynamic>.from(data));
      }
      onMatchFound?.call(_gameId ?? '');
      notifyListeners();
    });

    _socket!.on('opponent_apple_eaten', (data) {
      if (data is Map) {
        onOpponentAppleEaten?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('opponent_crashed', (data) {
      if (data is Map) {
        onOpponentCrashed?.call(Map<String, dynamic>.from(data));
      } else {
        onOpponentCrashed?.call({});
      }
    });
    
    _socket!.on('game_start', (data) {
      final gameState = GameState.fromJson(data);
      onGameStart?.call(gameState);
    });
    
    _socket!.on('game_state_update', (data) {
      final gameState = GameState.fromJson(data);
      onGameStateUpdate?.call(gameState);
    });
    
    _socket!.on('opponent_joined', (data) {
      final opponent = User.fromJson(data);
      onOpponentJoined?.call(opponent);
    });
    
    _socket!.on('opponent_left', (_) {
      onOpponentLeft?.call();
    });
    
    _socket!.on('game_end', (data) {
      final gameResult = GameResult_.fromJson(data);
      onGameEnd?.call(gameResult);
      _gameId = null;
    });
    
    _socket!.on('matchmaking_canceled', (_) {
      onMatchmakingCanceled?.call();
    });
    
    // Reconnection events
    _socket!.onReconnect((_) {
      debugPrint('Socket reconnected');
      // Re-authenticate on reconnection
      if (_currentUser != null) {
        _socket!.emit('authenticate', _currentUser!.toJson());
      }
    });
  }
  
  // Matchmaking
  Future<void> findMatch() async {
    if (!_isConnected) {
      _setError('Not connected to server');
      return;
    }
    
    _socket!.emit('find_match', {
      'user': _currentUser?.toJson(),
    });
  }

  Future<void> findRealMatch({required String difficulty, User? user}) async {
    if (!_isConnected || _socket == null) return;
    _socket!.emit('find_match', {
      'difficulty': difficulty,
      'user': (user ?? _currentUser)?.toJson(),
    });
  }

  void sendAppleEaten({required int apples, required int length, required int score}) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit('player_apple_eaten', {
      'apples': apples,
      'length': length,
      'score': score,
    });
  }

  void sendPlayerCrashed() {
    if (!_isConnected || _socket == null) return;
    _socket!.emit('player_crashed');
  }
  
  Future<void> cancelMatchmaking() async {
    if (!_isConnected) return;
    
    _socket!.emit('cancel_matchmaking');
  }
  
  // Game actions
  Future<void> sendMove(Direction direction) async {
    if (!_isConnected || _gameId == null) return;
    
    _socket!.emit('player_move', {
      'gameId': _gameId,
      'direction': direction.index,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  Future<void> pauseGame() async {
    if (!_isConnected || _gameId == null) return;
    
    _socket!.emit('pause_game', {'gameId': _gameId});
  }
  
  Future<void> resumeGame() async {
    if (!_isConnected || _gameId == null) return;
    
    _socket!.emit('resume_game', {'gameId': _gameId});
  }
  
  Future<void> leaveGame() async {
    if (!_isConnected || _gameId == null) return;
    
    _socket!.emit('leave_game', {'gameId': _gameId});
    _gameId = null;
  }
  
  // Send game state (for host/authoritative client)
  Future<void> sendGameState(GameState gameState) async {
    if (!_isConnected || _gameId == null) return;
    
    _socket!.emit('game_state_sync', {
      'gameId': _gameId,
      'gameState': gameState.toJson(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  // Chat functionality (optional)
  Future<void> sendMessage(String message) async {
    if (!_isConnected || _gameId == null) return;
    
    _socket!.emit('chat_message', {
      'gameId': _gameId,
      'message': message,
      'sender': _currentUser?.id,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  // Utility methods
  void _setError(String errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }
  
  void _clearError() {
    _error = null;
  }
  
  // Connection health check
  bool get isHealthy => _isConnected && _socket != null && _socket!.connected;
  
  // Get connection latency (ping)
  Future<int> getPing() async {
    if (!_isConnected) return -1;
    
    final completer = Completer<int>();
    final startTime = DateTime.now().millisecondsSinceEpoch;
    
    _socket!.emitWithAck('ping', null, ack: (data) {
      final endTime = DateTime.now().millisecondsSinceEpoch;
      completer.complete(endTime - startTime);
    });
    
    try {
      return await completer.future.timeout(const Duration(seconds: 5));
    } catch (e) {
      return -1;
    }
  }
  
  // Update user information
  void updateUser(User user) {
    _currentUser = user;
    if (_isConnected) {
      _socket!.emit('user_update', user.toJson());
    }
  }
  
  // Force reconnection
  Future<void> forceReconnect() async {
    disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    await connect(user: _currentUser);
  }
}

// Event data classes for type safety
class MatchFoundEvent {
  final String gameId;
  final User opponent;
  
  const MatchFoundEvent({required this.gameId, required this.opponent});
  
  factory MatchFoundEvent.fromJson(Map<String, dynamic> json) {
    return MatchFoundEvent(
      gameId: json['gameId'],
      opponent: User.fromJson(json['opponent']),
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
  });
  
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      message: json['message'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}
