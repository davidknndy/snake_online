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

// Helper to remove socket from all queues
function removeFromAllQueues(socket) {
  for (const diff of Object.keys(queues)) {
    queues[diff] = queues[diff].filter((item) => item.socket.id !== socket.id);
  }
}

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
      console.log(`[Auth] Jogador autenticado: ${socket.user.name} (${socket.user.trophies} troféus)`);
    }
  });

  // Player ping check
  socket.on('ping', (ack) => {
    if (typeof ack === 'function') ack();
  });

  // Find match
  socket.on('find_match', (data) => {
    removeFromAllQueues(socket);

    const difficulty = (data && data.difficulty) || 'Normal';
    const queue = queues[difficulty] || queues['Normal'];

    if (data && data.user) {
      socket.user = {
        id: data.user.id || socket.id,
        name: data.user.name || socket.user.name,
        trophies: data.user.trophies || socket.user.trophies,
      };
    }

    console.log(`[Fila] ${socket.user.name} entrou na fila para ${difficulty}`);

    // Check if another real player is waiting in this difficulty queue
    if (queue.length > 0) {
      const opponentEntry = queue.shift();
      const opponentSocket = opponentEntry.socket;

      // Ensure opponent socket is still connected
      if (opponentSocket.connected && opponentSocket.id !== socket.id) {
        const gameId = `game_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
        const matchSeed = Math.floor(Math.random() * 10000000);

        socket.join(gameId);
        opponentSocket.join(gameId);

        socket.gameId = gameId;
        opponentSocket.gameId = gameId;

        activeGames.set(gameId, {
          gameId,
          difficulty,
          matchSeed,
          players: [socket.id, opponentSocket.id],
        });

        console.log(`[Partida Criada] ${socket.user.name} VS ${opponentSocket.user.name} (${gameId})`);

        // Notify player 1
        socket.emit('match_found', {
          gameId,
          matchSeed,
          difficulty,
          opponent: opponentSocket.user,
        });

        // Notify player 2
        opponentSocket.emit('match_found', {
          gameId,
          matchSeed,
          difficulty,
          opponent: socket.user,
        });
        return;
      }
    }

    // Otherwise add to queue
    queue.push({ socket, joinedAt: Date.now() });
    socket.emit('queue_joined', { difficulty, position: queue.length });
  });

  // Cancel matchmaking
  socket.on('cancel_matchmaking', () => {
    removeFromAllQueues(socket);
    socket.emit('matchmaking_canceled');
    console.log(`[Fila] ${socket.user.name} cancelou a busca`);
  });

  // In-game: Apple eaten sync
  socket.on('player_apple_eaten', (data) => {
    if (socket.gameId) {
      socket.to(socket.gameId).emit('opponent_apple_eaten', data);
    }
  });

  // In-game: Player crashed
  socket.on('player_crashed', (data) => {
    if (socket.gameId) {
      console.log(`[Game Over] Jogador bateu: ${socket.user.name} na sala ${socket.gameId}`);
      socket.to(socket.gameId).emit('opponent_crashed', {
        crashedPlayer: socket.user.name,
      });
      activeGames.delete(socket.gameId);
    }
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
  socket.on('disconnect', () => {
    console.log(`[Socket] Desconectado: ${socket.id} (${socket.user.name})`);
    removeFromAllQueues(socket);

    if (socket.gameId) {
      socket.to(socket.gameId).emit('opponent_left');
      activeGames.delete(socket.gameId);
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

