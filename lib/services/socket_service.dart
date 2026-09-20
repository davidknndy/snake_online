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
  bool _isSearchingMatch = false;
  String? _searchDifficulty;
  User? _searchUser;
  Map<String, dynamic>? _lastActiveMatch;
  
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
  Function(Map<String, dynamic>)? onMatchFinished;
  Function()? onMatchmakingCanceled;
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isSearchingMatch => _isSearchingMatch;
  String? get error => _error;
  String? get gameId => _gameId;
  Map<String, dynamic>? get lastActiveMatch => _lastActiveMatch;
  User? get currentUser => _currentUser;
  
  // Initialize socket connection
  Future<void> connect({String? serverUrl, User? user}) async {
    if (user != null) _currentUser = user;
    if (_isConnected) return;
    if (_socket != null && _isConnecting) return;
    
    _isConnecting = true;
    _clearError();
    notifyListeners();
    
    try {
      _socket?.dispose();
      _socket = io.io(
        serverUrl ?? defaultServerUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableReconnection()
            .setReconnectionAttempts(10)
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
    _isSearchingMatch = false;
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
      debugPrint('Socket connected: ${_socket?.id}');

      if (_currentUser != null) {
        _socket!.emit('authenticate', _currentUser!.toJson());
      }

      // If matchmaking was requested, auto-emit find_match upon connection!
      if (_isSearchingMatch && _searchDifficulty != null) {
        _socket!.emit('find_match', {
          'difficulty': _searchDifficulty,
          'user': (_searchUser ?? _currentUser)?.toJson(),
        });
        debugPrint('find_match auto-emitted on connect: $_searchDifficulty');
      }

      // If active game existed, reconnect
      if (_gameId != null) {
        _socket!.emit('reconnect_game', {'gameId': _gameId});
      }

      // If player crashed while offline/resuming, guarantee delivery now
      if (_pendingPlayerCrash) {
        _sendPendingCrashIfPossible();
      }
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
      _isSearchingMatch = false;
      if (data is Map) {
        _lastActiveMatch = Map<String, dynamic>.from(data);
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

    _socket!.on('match_finished', (data) {
      if (data is Map) {
        onMatchFinished?.call(Map<String, dynamic>.from(data));
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
      _lastActiveMatch = null;
    });
    
    _socket!.on('matchmaking_canceled', (_) {
      _lastActiveMatch = null;
      onMatchmakingCanceled?.call();
    });
    
    // Reconnection events
    _socket!.onReconnect((_) {
      _isConnected = true;
      _isConnecting = false;
      _clearError();
      notifyListeners();
      debugPrint('Socket reconnected: ${_socket?.id}');

      if (_currentUser != null) {
        _socket!.emit('authenticate', _currentUser!.toJson());
      }

      if (_isSearchingMatch && _searchDifficulty != null) {
        _socket!.emit('find_match', {
          'difficulty': _searchDifficulty,
          'user': (_searchUser ?? _currentUser)?.toJson(),
        });
        debugPrint('find_match auto-emitted on reconnect: $_searchDifficulty');
      }

      if (_gameId != null) {
        _socket!.emit('reconnect_game', {'gameId': _gameId});
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
    _isSearchingMatch = true;
    _searchDifficulty = difficulty;
    if (user != null) _currentUser = user;
    _searchUser = user ?? _currentUser;

    if (_isConnected && _socket != null) {
      _socket!.emit('find_match', {
        'difficulty': difficulty,
        'user': _searchUser?.toJson(),
      });
      debugPrint('find_match emitted to server: difficulty=$difficulty, user=${_searchUser?.name}');
    } else {
      debugPrint('find_match queued: waiting for socket connection...');
    }
  }

  /// Check if this user already has an active ongoing match on the server (e.g. after resuming from background)
  Future<Map<String, dynamic>?> checkActiveMatch({User? user}) async {
    if (user != null) _currentUser = user;
    if (!_isConnected || _socket == null) return _lastActiveMatch;

    final completer = Completer<Map<String, dynamic>?>();
    try {
      _socket!.emitWithAck('check_active_match', {
        'user': (_currentUser ?? user)?.toJson(),
      }, ack: (response) {
        if (response is Map && response['active'] == true && response['match'] is Map) {
          final matchData = Map<String, dynamic>.from(response['match']);
          _lastActiveMatch = matchData;
          _gameId = matchData['gameId']?.toString();
          _isSearchingMatch = false;
          onRealMatchFound?.call(matchData);
          onMatchFound?.call(_gameId ?? '');
          notifyListeners();
          if (!completer.isCompleted) {
            completer.complete(matchData);
          }
        } else {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      });
      return await completer.future.timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
  }

  /// Reconnect to an active game room
  void reconnectGame(String gId) {
    _gameId = gId;
    if (_isConnected && _socket != null) {
      _socket!.emit('reconnect_game', {'gameId': gId});
    }
  }

  void notifyAppMinimized() {
    if (!_isConnected || _socket == null || _gameId == null) return;
    _socket!.emit('player_minimized', {
      'gameId': _gameId,
      'user': _currentUser?.toJson(),
    });
  }

  void notifyAppResumed() {
    if (!_isConnected || _socket == null || _gameId == null) return;
    _socket!.emit('player_resumed', {
      'gameId': _gameId,
      'user': _currentUser?.toJson(),
    });
  }

  Future<Map<String, dynamic>?> checkGameStatus(String gameId) async {
    if (_socket == null) return null;
    if (!_isConnected || !_socket!.connected) {
      await ensureHealthyConnection(user: _currentUser);
      int waitedMs = 0;
      while ((!_isConnected || !_socket!.connected) && waitedMs < 1200) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitedMs += 100;
      }
    }
    if (!_isConnected || _socket == null || !_socket!.connected) return null;

    final completer = Completer<Map<String, dynamic>?>();
    try {
      _socket!.emitWithAck('get_game_status', {
        'gameId': gameId,
        'user': _currentUser?.toJson(),
      }, ack: (response) {
        if (response is Map) {
          if (!completer.isCompleted) {
            completer.complete(Map<String, dynamic>.from(response));
          }
        } else {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      });
      return await completer.future.timeout(const Duration(milliseconds: 2000));
    } catch (_) {
      return null;
    }
  }

  void sendAppleEaten({required int apples, required int length, required int score}) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit('player_apple_eaten', {
      'apples': apples,
      'length': length,
      'score': score,
    });
  }

  bool _pendingPlayerCrash = false;

  void sendPlayerCrashed() {
    _pendingPlayerCrash = true;
    _sendPendingCrashIfPossible();
  }

  void _sendPendingCrashIfPossible() {
    if (!_pendingPlayerCrash) return;

    if (_isConnected && _socket != null && _socket!.connected) {
      debugPrint('[Socket] Enviando player_crashed: gameId=$_gameId');
      _socket!.emit('player_crashed', {
        'gameId': _gameId,
        'user': _currentUser?.toJson(),
      });
      _socket!.emit('player_crashed');
      _pendingPlayerCrash = false;
    } else {
      debugPrint('[Socket] Conexão indisponível ao bater. Aguardando reconexão...');
      if (_currentUser != null) {
        ensureHealthyConnection(user: _currentUser);
      }
    }
  }
  
  Future<void> cancelMatchmaking() async {
    _isSearchingMatch = false;
    _searchDifficulty = null;
    _searchUser = null;
    _lastActiveMatch = null;
    if (!_isConnected || _socket == null) return;
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
    _isSearchingMatch = false;
    _lastActiveMatch = null;
    _pendingPlayerCrash = false;
    if (_isConnected && _socket != null && _gameId != null) {
      _socket!.emit('leave_game', {'gameId': _gameId});
    }
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

  /// Ensure socket is actually connected at the native level.
  /// When Android suspends the Dart isolate (app backgrounded), the socket
  /// may disconnect but our cached [_isConnected] stays true because
  /// [onDisconnect] never ran. This method detects that stale state and
  /// forces a fresh connection while preserving matchmaking state.
  Future<void> ensureHealthyConnection({String? serverUrl, User? user}) async {
    if (user != null) _currentUser = user;

    if (_isConnecting) {
      debugPrint('ensureHealthyConnection: conexão já em andamento, ignorando chamada redundante');
      return;
    }

    // Check the ACTUAL native socket state, not our cached _isConnected
    if (_socket != null && _socket!.connected) {
      // Socket is truly alive — re-emit authenticate so the server can
      // catch us up to any match created while we were backgrounded
      if (_currentUser != null) {
        _socket!.emit('authenticate', _currentUser!.toJson());
      }
      debugPrint('ensureHealthyConnection: socket is alive, re-authenticated');
      return;
    }

    // Socket is dead/stale — save matchmaking state before teardown
    debugPrint('ensureHealthyConnection: socket is DEAD, forcing fresh connection');
    final wasSearching = _isSearchingMatch;
    final savedDifficulty = _searchDifficulty;
    final savedUser = _searchUser;
    final savedGameId = _gameId;
    final savedMatch = _lastActiveMatch;

    // Tear down the dead socket without going through disconnect()
    // (disconnect() clears search state which we need to preserve)
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isConnecting = false;

    // Restore search state so onConnect auto-emits find_match
    _isSearchingMatch = wasSearching;
    _searchDifficulty = savedDifficulty;
    _searchUser = savedUser;
    _gameId = savedGameId;
    _lastActiveMatch = savedMatch;

    // Create fresh connection — onConnect handler will auto-emit
    // authenticate + find_match, triggering server-side catch-up
    await connect(serverUrl: serverUrl, user: _currentUser);
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
