const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

const app = express();
app.disable('x-powered-by');
app.use(cors());

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
  pingTimeout: 5000,
  pingInterval: 5000,
});

const PORT = process.env.PORT || 3000;
const GAME_SECRET_TOKEN = process.env.GAME_SECRET || 'dk_snake_live_sec_78f29a0b12';

// Rate limiting by IP for connection attempts
const connectionAttempts = new Map();
const MAX_CONNECTIONS_PER_MINUTE = 25;

// Socket.io security middleware: Token authentication & rate limit
io.use((socket, next) => {
  const ip = socket.handshake.address;
  const now = Date.now();
  const history = (connectionAttempts.get(ip) || []).filter(t => now - t < 60000);
  history.push(now);
  connectionAttempts.set(ip, history);

  if (history.length > MAX_CONNECTIONS_PER_MINUTE) {
    console.warn(`[Security] Rate limit excedido para IP: ${ip}`);
    return next(new Error('Rate limit exceeded'));
  }

  const clientToken = socket.handshake.auth?.token || socket.handshake.headers?.['x-game-token'];
  if (clientToken !== GAME_SECRET_TOKEN) {
    console.warn(`[Security] Conexão bloqueada sem token válido de ${ip}`);
    return next(new Error('Unauthorized'));
  }

  next();
});

// Worldwide leaderboard of real players
let worldwideLeaderboard = [];

// Secure API endpoints for Worldwide Leaderboard
app.use(express.json());

app.get('/api/leaderboard', (req, res) => {
  const token = req.headers['x-game-token'];
  if (token !== GAME_SECRET_TOKEN) {
    return res.status(401).send('Unauthorized');
  }
  res.json(worldwideLeaderboard);
});

app.post('/api/leaderboard', (req, res) => {
  const token = req.headers['x-game-token'];
  if (token !== GAME_SECRET_TOKEN) {
    return res.status(401).send('Unauthorized');
  }
  const data = req.body;
  if (!data || !data.playerName) {
    return res.status(400).json({ error: 'Missing playerName' });
  }
  const cleanName = data.playerName.trim();
  const existingIndex = worldwideLeaderboard.findIndex(
    p => p.playerName.toLowerCase() === cleanName.toLowerCase()
  );
  const entry = {
    id: data.id || `player_${Date.now()}`,
    playerName: cleanName,
    score: Number(data.score) || 0,
    trophies: Number(data.trophies) || 0,
    timestamp: new Date().toISOString(),
    isLocal: false,
  };
  if (existingIndex !== -1) {
    worldwideLeaderboard[existingIndex] = {
      ...worldwideLeaderboard[existingIndex],
      score: Math.max(worldwideLeaderboard[existingIndex].score, entry.score),
      trophies: entry.trophies,
      timestamp: entry.timestamp,
    };
  } else {
    worldwideLeaderboard.push(entry);
  }
  worldwideLeaderboard.sort((a, b) => (b.trophies - a.trophies) || (b.score - a.score));
  res.json(worldwideLeaderboard);
});

// Stealth mode: Return 404 for any direct browser / HTTP probe
app.use((req, res) => {
  res.status(404).send('Not Found');
});

// Matchmaking queues separated by difficulty
const queues = {
  'Normal': [],
  'Difícil': [],
  'Muito Difícil': [],
};

// Active games
const activeGames = new Map();

// Finished games cache (kept for 2 minutes to reliably report match results to reconnected/resumed players)
const finishedGames = new Map();

setInterval(() => {
  const now = Date.now();
  for (const [gameId, rec] of finishedGames.entries()) {
    if (now - rec.endedAt > 120000) { // 2 minutes
      finishedGames.delete(gameId);
    }
  }
}, 30000);

function finishGame(targetGameId, winnerUser, loserUser, reason, crashedSocket) {
  if (!targetGameId) return;
  const game = activeGames.get(targetGameId);
  if (game) {
    if (game.disconnectTimer) clearTimeout(game.disconnectTimer);
    if (game.minimizeTimer) clearTimeout(game.minimizeTimer);
    activeGames.delete(targetGameId);
  }

  const finishedRecord = {
    gameId: targetGameId,
    winnerUser: winnerUser ? { ...winnerUser } : null,
    loserUser: loserUser ? { ...loserUser } : null,
    reason: reason || 'crashed',
    endedAt: Date.now(),
  };
  finishedGames.set(targetGameId, finishedRecord);

  const crashedName = loserUser?.name || 'Oponente';
  console.log(`[Game Over] Partida encerrada: ${targetGameId}. Vencedor: ${winnerUser?.name}, Perdedor: ${crashedName} (motivo: ${reason})`);

  // 1. Broadcast to the room: socket.to(room) reaches the opponent
  if (crashedSocket) {
    crashedSocket.to(targetGameId).emit('opponent_crashed', {
      crashedPlayer: crashedName,
      winner: winnerUser?.name,
      isWin: true,
      reason: reason,
    });
    crashedSocket.to(targetGameId).emit('match_finished', {
      gameId: targetGameId,
      isWin: true,
      winner: winnerUser,
      loser: loserUser,
      reason: reason,
    });
    crashedSocket.emit('match_finished', {
      gameId: targetGameId,
      isWin: false,
      winner: winnerUser,
      loser: loserUser,
      reason: reason,
    });
  }

  // 2. Direct socket delivery to all known players
  if (game && Array.isArray(game.playerData)) {
    for (const p of game.playerData) {
      if (!p.socketId) continue;
      if (crashedSocket && p.socketId === crashedSocket.id) continue;

      const isWinner = winnerUser && p.user && 
        (p.user === winnerUser ||
         (winnerUser.id && p.user.id === winnerUser.id) ||
         (winnerUser.name && p.user.name === winnerUser.name));

      if (isWinner) {
        io.to(p.socketId).emit('opponent_crashed', {
          crashedPlayer: crashedName,
          winner: winnerUser?.name,
          isWin: true,
          reason: reason,
        });
        io.to(p.socketId).emit('match_finished', {
          gameId: targetGameId,
          isWin: true,
          winner: winnerUser,
          loser: loserUser,
          reason: reason,
        });
      }
    }
  }

  // 3. Fallback: room broadcast with crashedPlayer tag
  io.to(targetGameId).emit('opponent_crashed', {
    crashedPlayer: crashedName,
    winner: winnerUser?.name,
    reason: reason,
  });
}

// Helper to find an active match for a user (within 5 minutes)
function findActiveGameForUser(user) {
  if (!user) return null;
  const now = Date.now();
  for (const [gameId, game] of activeGames.entries()) {
    const age = now - game.createdAt;
    if (age < 300000) { // 5 minutes
      if (Array.isArray(game.playerData)) {
        for (const p of game.playerData) {
          const matchesId = user.id && p.user && p.user.id && (p.user.id === user.id);
          const matchesName = user.name && p.user && p.user.name &&
            (p.user.name.trim().toLowerCase() === user.name.trim().toLowerCase() ||
             p.user.name.startsWith(`${user.name} #`));
          if (matchesId || matchesName) {
            console.log(`[findActiveGame] Partida encontrada para ${user.name} (id=${user.id}): gameId=${gameId}, age=${Math.round(age/1000)}s`);
            return { game, myPlayerData: p };
          }
        }
      }
    }
  }
  console.log(`[findActiveGame] Nenhuma partida ativa para ${user.name} (id=${user.id}). Total de jogos ativos: ${activeGames.size}`);
  return null;
}

// Helper to remove socket from all queues by socket ID
function removeFromAllQueues(socketId) {
  for (const diff of Object.keys(queues)) {
    queues[diff] = queues[diff].filter((item) => item.socket.id !== socketId);
  }
}

// Helper to remove a user from all queues by user identity (ID or name)
function removeUserFromAllQueues(user) {
  if (!user) return;
  for (const diff of Object.keys(queues)) {
    const before = queues[diff].length;
    queues[diff] = queues[diff].filter((item) => {
      const matchesId = user.id && item.user && item.user.id && (item.user.id === user.id);
      const matchesName = user.name && item.user && item.user.name &&
        (item.user.name.trim().toLowerCase() === user.name.trim().toLowerCase());
      return !matchesId && !matchesName;
    });
    if (queues[diff].length < before) {
      console.log(`[Fila] Removido jogador antigo ${user.name} da fila ${diff} (limpeza por identidade)`);
    }
  }
}

// Clean up disconnected queue entries older than 45s
setInterval(() => {
  const now = Date.now();
  for (const diff of Object.keys(queues)) {
    queues[diff] = queues[diff].filter((item) => {
      if (!item.socket.connected && item.disconnectedAt && (now - item.disconnectedAt > 45000)) {
        console.log(`[Fila] Removendo jogador desconectado expirado: ${item.user?.name || item.socket.id}`);
        return false;
      }
      return true;
    });
  }
}, 5000);

io.on('connection', (socket) => {
  console.log(`[Socket] Conectado: ${socket.id}`);
  socket.user = {
    id: socket.id,
    name: `Jogador_${socket.id.substring(0, 4)}`,
    trophies: 0,
  };

  // User authentication / profile update
  socket.on('authenticate', (userData) => {
    if (userData) {
      socket.user = {
        id: userData.id || socket.id,
        name: userData.name || socket.user.name,
        trophies: userData.trophies || 0,
      };
      console.log(`[Auth] Jogador autenticado: ${socket.user.name} (id=${socket.user.id}, ${socket.user.trophies} troféus)`);

      // Clean up stale queue entries for this user from old/disconnected sockets
      removeUserFromAllQueues(socket.user);

      // Check if user has active ongoing match created while app was backgrounded
      const activeMatchInfo = findActiveGameForUser(socket.user);
      if (activeMatchInfo) {
        const { game, myPlayerData } = activeMatchInfo;
        myPlayerData.socketId = socket.id;
        if (!game.players.includes(socket.id)) {
          game.players.push(socket.id);
        }
        game.playerUsers[socket.id] = myPlayerData.user;
        socket.join(game.gameId);
        socket.gameId = game.gameId;

        if (game.disconnectTimer) {
          clearTimeout(game.disconnectTimer);
          game.disconnectTimer = null;
        }

        const opponentEntry = game.playerData.find(p => p !== myPlayerData);
        const opponentUser = opponentEntry ? opponentEntry.user : { name: 'Adversário Online', trophies: 0 };

        console.log(`[Auth -> Partida Ativa] Jogador ${socket.user.name} recuperado para a partida ${game.gameId}`);
        socket.emit('match_found', {
          gameId: game.gameId,
          matchSeed: game.matchSeed,
          difficulty: game.difficulty,
          opponent: opponentUser,
          isCatchUp: true,
        });
        socket.to(game.gameId).emit('opponent_connection_state', {
          state: 'reconnected',
          playerId: socket.id,
        });
      }
    }
  });

  // Worldwide leaderboard query via socket
  socket.on('get_worldwide_leaderboard', (ack) => {
    if (typeof ack === 'function') {
      ack(worldwideLeaderboard);
    }
  });

  // Submit score via socket
  socket.on('submit_worldwide_score', (data) => {
    if (!data || !data.playerName) return;
    const cleanName = data.playerName.trim();
    const existingIndex = worldwideLeaderboard.findIndex(
      p => p.playerName.toLowerCase() === cleanName.toLowerCase()
    );
    const entry = {
      id: socket.user.id,
      playerName: cleanName,
      score: Number(data.score) || 0,
      trophies: Number(data.trophies) || 0,
      timestamp: new Date().toISOString(),
      isLocal: false,
    };
    if (existingIndex !== -1) {
      worldwideLeaderboard[existingIndex] = {
        ...worldwideLeaderboard[existingIndex],
        score: Math.max(worldwideLeaderboard[existingIndex].score, entry.score),
        trophies: entry.trophies,
        timestamp: entry.timestamp,
      };
    } else {
      worldwideLeaderboard.push(entry);
    }
    worldwideLeaderboard.sort((a, b) => (b.trophies - a.trophies) || (b.score - a.score));
  });

  // Player ping check
  socket.on('ping', (ack) => {
    if (typeof ack === 'function') ack();
  });

  // Find match
  socket.on('find_match', (data) => {
    removeFromAllQueues(socket.id);

    const difficulty = (data && data.difficulty) || 'Normal';
    const queue = queues[difficulty] || queues['Normal'];

    if (data && data.user) {
      socket.user = {
        id: data.user.id || socket.id,
        name: data.user.name || socket.user.name,
        trophies: data.user.trophies || socket.user.trophies,
      };
    }

    // Also remove any stale queue entries for this user from previous sockets
    removeUserFromAllQueues(socket.user);

    // If authenticate already reconnected this socket to an active game, skip
    if (socket.gameId && activeGames.has(socket.gameId)) {
      console.log(`[Fila] ${socket.user.name} já está na partida ${socket.gameId} (via authenticate). Ignorando find_match.`);
      return;
    }

    // Check if this user already has an active ongoing match created recently!
    const activeMatchInfo = findActiveGameForUser(socket.user);
    if (activeMatchInfo) {
      const { game, myPlayerData } = activeMatchInfo;
      myPlayerData.socketId = socket.id;
      if (!game.players.includes(socket.id)) {
        game.players.push(socket.id);
      }
      game.playerUsers[socket.id] = myPlayerData.user;
      socket.join(game.gameId);
      socket.gameId = game.gameId;

      if (game.disconnectTimer) {
        clearTimeout(game.disconnectTimer);
        game.disconnectTimer = null;
      }

      const opponentEntry = game.playerData.find(p => p !== myPlayerData);
      const opponentUser = opponentEntry ? opponentEntry.user : { name: 'Adversário Online', trophies: 0 };

      console.log(`[Fila -> Reconexão Imediata] ${socket.user.name} reconectou à partida ativa ${game.gameId}`);
      socket.emit('match_found', {
        gameId: game.gameId,
        matchSeed: game.matchSeed,
        difficulty: game.difficulty,
        opponent: opponentUser,
        isCatchUp: true,
      });
      socket.to(game.gameId).emit('opponent_connection_state', {
        state: 'reconnected',
        playerId: socket.id,
      });
      return;
    }

    console.log(`[Fila] ${socket.user.name} entrou na fila para ${difficulty}`);

    // Check if another real player is waiting
    let opponentEntry = null;
    let selectedDiff = difficulty;

    // 1. Check exact difficulty queue
    const oppIndex = queue.findIndex(item => item.socket.id !== socket.id);
    if (oppIndex !== -1) {
      opponentEntry = queue.splice(oppIndex, 1)[0];
    } else {
      // 2. Cross-difficulty fallback if someone in another queue has waited >= 6s
      for (const diff of Object.keys(queues)) {
        if (diff === difficulty) continue;
        const otherIndex = queues[diff].findIndex(item => 
          item.socket.id !== socket.id && (Date.now() - item.joinedAt >= 6000)
        );
        if (otherIndex !== -1) {
          opponentEntry = queues[diff].splice(otherIndex, 1)[0];
          selectedDiff = difficulty;
          console.log(`[Fila] Pareamento inter-dificuldades: ${socket.user.name} (${difficulty}) vs ${opponentEntry.user?.name} (${diff})`);
          break;
        }
      }
    }

    if (opponentEntry) {
      const opponentSocket = opponentEntry.socket;
      const gameId = `game_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      const matchSeed = Math.floor(Math.random() * 10000000);

      socket.join(gameId);
      opponentSocket.join(gameId);

      socket.gameId = gameId;
      opponentSocket.gameId = gameId;

      let p1User = { ...socket.user };
      let p2User = { ...(opponentEntry.user || opponentSocket.user) };

      // If dual app on same device with identical names, disambiguate
      if (p1User.name === p2User.name) {
        p1User.name = `${p1User.name} #1`;
        p2User.name = `${p2User.name} #2`;
      }

      activeGames.set(gameId, {
        gameId,
        difficulty: selectedDiff,
        matchSeed,
        players: [socket.id, opponentSocket.id],
        playerUsers: { [socket.id]: p1User, [opponentSocket.id]: p2User },
        playerData: [
          { socketId: socket.id, user: p1User },
          { socketId: opponentSocket.id, user: p2User },
        ],
        createdAt: Date.now(),
      });

      console.log(`[Partida Criada] ${p1User.name} VS ${p2User.name} (${gameId})`);

      // Notify player 1
      socket.emit('match_found', {
        gameId,
        matchSeed,
        difficulty: selectedDiff,
        opponent: p2User,
      });

      // Notify player 2
      opponentSocket.emit('match_found', {
        gameId,
        matchSeed,
        difficulty: selectedDiff,
        opponent: p1User,
      });
      return;
    }

    // Otherwise add to queue
    queue.push({
      socket,
      user: socket.user,
      joinedAt: Date.now(),
      disconnectedAt: null,
    });
    socket.emit('queue_joined', { difficulty, position: queue.length });
  });

  // Check if player has an active ongoing match (e.g. after resuming app from background)
  socket.on('check_active_match', (data, ack) => {
    const user = (data && data.user) || socket.user;
    const activeMatchInfo = findActiveGameForUser(user);
    if (activeMatchInfo) {
      const { game, myPlayerData } = activeMatchInfo;
      myPlayerData.socketId = socket.id;
      if (!game.players.includes(socket.id)) {
        game.players.push(socket.id);
      }
      game.playerUsers[socket.id] = myPlayerData.user;
      socket.join(game.gameId);
      socket.gameId = game.gameId;

      if (game.disconnectTimer) {
        clearTimeout(game.disconnectTimer);
        game.disconnectTimer = null;
      }

      const opponentEntry = game.playerData.find(p => p !== myPlayerData);
      const opponentUser = opponentEntry ? opponentEntry.user : { name: 'Adversário Online', trophies: 0 };

      const matchData = {
        gameId: game.gameId,
        matchSeed: game.matchSeed,
        difficulty: game.difficulty,
        opponent: opponentUser,
        isCatchUp: true,
      };

      socket.emit('match_found', matchData);
      socket.to(game.gameId).emit('opponent_connection_state', {
        state: 'reconnected',
        playerId: socket.id,
      });
      if (typeof ack === 'function') {
        ack({ active: true, match: matchData });
      }
    } else {
      if (typeof ack === 'function') {
        ack({ active: false });
      }
    }
  });

  // Cancel matchmaking
  socket.on('cancel_matchmaking', () => {
    removeFromAllQueues(socket.id);
    socket.emit('matchmaking_canceled');
    console.log(`[Fila] ${socket.user.name} cancelou a busca`);
  });

  // Reconnect active game if app was minimized/backgrounded
  socket.on('reconnect_game', (data) => {
    if (!data || !data.gameId) return;
    const gameId = data.gameId;

    // Check if game already finished while user was away
    const finished = finishedGames.get(gameId);
    if (finished) {
      const isWinner = (finished.winnerUser?.id && socket.user?.id && finished.winnerUser.id === socket.user.id) ||
                       (finished.winnerUser?.name && socket.user?.name && 
                        (finished.winnerUser.name === socket.user.name || finished.winnerUser.name.startsWith(`${socket.user.name} #`)));
      if (isWinner) {
        socket.emit('opponent_crashed', {
          crashedPlayer: finished.loserUser?.name || 'Oponente',
          winner: finished.winnerUser?.name,
          reason: finished.reason,
        });
      }
      socket.emit('match_finished', {
        gameId,
        winner: finished.winnerUser,
        loser: finished.loserUser,
        isWin: isWinner,
        reason: finished.reason,
      });
      console.log(`[Partida] Jogador ${socket.user.name} reconectou a partida já encerrada: ${gameId} (isWinner=${isWinner})`);
      return;
    }

    const game = activeGames.get(gameId);
    if (game) {
      if (game.disconnectTimer) {
        clearTimeout(game.disconnectTimer);
        game.disconnectTimer = null;
      }
      if (game.minimizeTimer) {
        clearTimeout(game.minimizeTimer);
        game.minimizeTimer = null;
      }
      socket.join(gameId);
      socket.gameId = gameId;
      if (!game.players.includes(socket.id)) {
        game.players.push(socket.id);
      }
      if (Array.isArray(game.playerData)) {
        const myP = game.playerData.find(p => 
          (socket.user?.id && p.user?.id === socket.user.id) || 
          (socket.user?.name && p.user?.name === socket.user.name)
        );
        if (myP) myP.socketId = socket.id;
      }
      socket.to(gameId).emit('opponent_connection_state', {
        state: 'reconnected',
        playerId: socket.id,
      });
      console.log(`[Partida] Jogador ${socket.user.name} reconectou à sala ${gameId}`);
    }
  });

  // Query game status (e.g. after app resume to verify if game already ended)
  socket.on('get_game_status', (data, ack) => {
    const gameId = (data && data.gameId) || socket.gameId;
    const reqUser = (data && data.user) || socket.user;
    if (!gameId) {
      if (typeof ack === 'function') ack({ status: 'unknown' });
      return;
    }

    const finished = finishedGames.get(gameId);
    if (finished) {
      const isWinner = (finished.winnerUser?.id && reqUser?.id && finished.winnerUser.id === reqUser.id) ||
                       (finished.winnerUser?.name && reqUser?.name && 
                        (finished.winnerUser.name === reqUser.name || finished.winnerUser.name.startsWith(`${reqUser.name} #`)));
      if (typeof ack === 'function') {
        ack({
          status: 'finished',
          isWin: isWinner,
          winner: finished.winnerUser,
          loser: finished.loserUser,
          reason: finished.reason,
        });
      }
      return;
    }

    const active = activeGames.get(gameId);
    if (active) {
      if (typeof ack === 'function') {
        ack({ status: 'active' });
      }
      return;
    }

    if (typeof ack === 'function') {
      ack({ status: 'unknown' });
    }
  });

  // Player minimized app (e.g. switched dual app or backgrounded)
  socket.on('player_minimized', (data) => {
    let targetGameId = (data && data.gameId) || socket.gameId;
    if (!targetGameId) {
      const active = findActiveGameForUser(socket.user);
      if (active) targetGameId = active.game.gameId;
    }
    if (!targetGameId) return;

    const game = activeGames.get(targetGameId);
    if (!game) return;

    console.log(`[Partida] Jogador ${socket.user.name} minimizou o app na sala ${targetGameId}`);
    socket.to(targetGameId).emit('opponent_connection_state', {
      state: 'minimized',
      playerId: socket.id,
    });

    // Start 3.5s minimize timer: if player does not return, their snake crashes into the wall
    if (!game.minimizeTimer) {
      game.minimizeTimer = setTimeout(() => {
        if (activeGames.has(targetGameId)) {
          console.log(`[Partida] Tempo minimizado expirado (3.5s) para ${socket.user.name} na sala ${targetGameId}. Registrando batida!`);
          let minimizedUser = socket.user;
          let opponentUser = null;
          if (Array.isArray(game.playerData)) {
            const mEntry = game.playerData.find(p => 
              (socket.user?.id && p.user?.id === socket.user.id) ||
              (socket.user?.name && p.user?.name === socket.user.name) ||
              p.socketId === socket.id
            );
            if (mEntry) minimizedUser = mEntry.user;
            const opEntry = game.playerData.find(p => p !== mEntry);
            if (opEntry) opponentUser = opEntry.user;
          }
          finishGame(targetGameId, opponentUser, minimizedUser, 'minimized_timeout');
        }
      }, 3500);
    }
  });

  // Player resumed app
  socket.on('player_resumed', (data) => {
    let targetGameId = (data && data.gameId) || socket.gameId;
    if (!targetGameId) {
      const active = findActiveGameForUser(socket.user);
      if (active) targetGameId = active.game.gameId;
    }
    if (!targetGameId) return;

    const game = activeGames.get(targetGameId);
    if (game) {
      if (game.minimizeTimer) {
        clearTimeout(game.minimizeTimer);
        game.minimizeTimer = null;
      }
      socket.to(targetGameId).emit('opponent_connection_state', {
        state: 'active',
        playerId: socket.id,
      });
      console.log(`[Partida] Jogador ${socket.user.name} retornou ao primeiro plano na sala ${targetGameId}`);
    }
  });

  // In-game: Apple eaten sync
  socket.on('player_apple_eaten', (data) => {
    if (socket.gameId) {
      socket.to(socket.gameId).emit('opponent_apple_eaten', data);
    }
  });

  // In-game: Player crashed
  socket.on('player_crashed', (data) => {
    let targetGameId = (data && data.gameId) || socket.gameId;

    if (!targetGameId) {
      for (const [gId, g] of activeGames.entries()) {
        if (g.players.includes(socket.id)) {
          targetGameId = gId;
          break;
        }
        if (Array.isArray(g.playerData)) {
          for (const p of g.playerData) {
            if ((socket.user?.id && p.user?.id === socket.user.id) ||
                (socket.user?.name && p.user?.name === socket.user.name)) {
              targetGameId = gId;
              break;
            }
          }
        }
        if (targetGameId) break;
      }
    }

    if (!targetGameId) {
      return;
    }

    const game = activeGames.get(targetGameId);
    let crashedUser = (data && data.user) || socket.user;
    let winnerUser = null;

    if (game && Array.isArray(game.playerData) && game.playerData.length >= 2) {
      let loserEntry = game.playerData.find(p => 
        p.socketId === socket.id ||
        (crashedUser?.id && p.user?.id === crashedUser.id) ||
        (crashedUser?.name && p.user?.name && (
          p.user.name === crashedUser.name ||
          p.user.name.startsWith(crashedUser.name) ||
          crashedUser.name.startsWith(p.user.name)
        ))
      );

      if (!loserEntry) {
        loserEntry = game.playerData[0];
      }
      const winnerEntry = game.playerData.find(p => p !== loserEntry) ||
                          (loserEntry === game.playerData[0] ? game.playerData[1] : game.playerData[0]);

      crashedUser = loserEntry.user;
      winnerUser = winnerEntry.user;
    }

    finishGame(targetGameId, winnerUser, crashedUser, 'crashed', socket);
  });

  // Leave game
  socket.on('leave_game', () => {
    if (socket.gameId) {
      socket.to(socket.gameId).emit('opponent_left');
      activeGames.delete(socket.gameId);
      socket.leave(socket.gameId);
      socket.gameId = null;
    }
  });

  // Disconnect
  socket.on('disconnect', (reason) => {
    console.log(`[Socket] Desconectado: ${socket.id} (${socket.user.name}) - motivo: ${reason}`);

    // If socket was in matchmaking queue, mark disconnectedAt for 45s grace period
    for (const diff of Object.keys(queues)) {
      for (const item of queues[diff]) {
        if (item.socket.id === socket.id) {
          item.disconnectedAt = Date.now();
          console.log(`[Fila] Jogador ${socket.user.name} desconectado temporariamente da fila (grace period 45s)`);
        }
      }
    }

    // If socket was in active game, grant 3.5s reconnect grace period
    if (socket.gameId) {
      const gameId = socket.gameId;
      const game = activeGames.get(gameId);
      if (game) {
        io.to(gameId).emit('opponent_connection_state', {
          state: 'disconnected',
          playerId: socket.id,
        });

        if (game.disconnectTimer) {
          clearTimeout(game.disconnectTimer);
        }

        game.disconnectTimer = setTimeout(() => {
          if (activeGames.has(gameId)) {
            console.log(`[Partida] Tempo de reconexão esgotado para ${socket.user.name} na sala ${gameId}`);
            let disconnectedUser = socket.user;
            let opponentUser = null;
            if (Array.isArray(game.playerData)) {
              const dEntry = game.playerData.find(p => 
                (socket.user?.id && p.user?.id === socket.user.id) ||
                (socket.user?.name && p.user?.name === socket.user.name) ||
                p.socketId === socket.id
              );
              if (dEntry) disconnectedUser = dEntry.user;
              const opEntry = game.playerData.find(p => p !== dEntry);
              if (opEntry) opponentUser = opEntry.user;
            }
            finishGame(gameId, opponentUser, disconnectedUser, 'disconnected_timeout');
          }
        }, 3500); // 3.5s reconnect grace period during live match
      }
    }
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`=========================================`);
  console.log(`🐍 Servidor Snake Online Ativo na Porta ${PORT}`);
  console.log(`📡 Endereços Locais:`);
  console.log(`   - Localhost:       http://localhost:${PORT}`);
  console.log(`   - Emulador Android: http://10.0.2.2:${PORT}`);
  console.log(`   - Rede Local (Wi-Fi): http://192.168.0.8:${PORT}`);
  console.log(`=========================================`);
});

