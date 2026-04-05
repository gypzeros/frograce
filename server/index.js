const { WebSocketServer } = require("ws");
const express = require("express");
const http = require("http");
const db = require("./db");
const { setupDashboard } = require("./dashboard");

const PORT = 3000;
const app = express();
const server = http.createServer(app);
setupDashboard(app);
const FROGS_TO_WIN = 3;
const MAP_WIDTH = 9;
const MAP_HEIGHT = 17;
const TICK_RATE = 20;
const TICK_MS = 1000 / TICK_RATE;
const MAX_PER_ROW = 4;
const MIN_GAP = 2.5;

const wss = new WebSocketServer({ server });

const rooms = new Map();
let waitingPlayer = null;
let nextId = 1;
let nextObsId = 1;

// --- Utilidades ---

function send(ws, type, data = {}) {
  if (ws.readyState === ws.OPEN) {
    ws.send(JSON.stringify({ type, ...data }));
  }
}

function sendToRoom(room, type, data = {}) {
  for (const p of room.players) {
    send(p, type, data);
  }
}

// --- RNG determinista simple (mulberry32) ---

function createRng(seed) {
  let s = seed | 0;
  return {
    next() {
      s |= 0;
      s = (s + 0x6d2b79f5) | 0;
      let t = Math.imul(s ^ (s >>> 15), 1 | s);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    },
    range(min, max) {
      return min + this.next() * (max - min);
    },
    pick(arr) {
      return arr[Math.floor(this.next() * arr.length)];
    },
  };
}

// --- Configuracion de filas de obstaculos ---

const ROW_CONFIGS = [
  // Carreteras superiores (3-5)
  { row: 3, dir: 1, type: "car", minSpd: 1.5, maxSpd: 4.5, minInt: 1.0, maxInt: 3.0, sizes: [[1.5, 0.5, 0.8], [2.0, 0.5, 0.8]] },
  { row: 4, dir: -1, type: "car", minSpd: 2.0, maxSpd: 5.0, minInt: 0.8, maxInt: 2.5, sizes: [[1.5, 0.5, 0.8], [2.0, 0.5, 0.8]] },
  { row: 5, dir: 1, type: "car", minSpd: 1.5, maxSpd: 3.5, minInt: 1.2, maxInt: 3.5, sizes: [[1.5, 0.5, 0.8], [2.5, 0.5, 0.8]] },
  // Agua (7-9)
  { row: 7, dir: 1, type: "log", minSpd: 0.8, maxSpd: 2.0, minInt: 1.5, maxInt: 4.0, sizes: [[3.0, 0.4, 0.8], [4.0, 0.4, 0.8]] },
  { row: 8, dir: -1, type: "log", minSpd: 1.0, maxSpd: 2.5, minInt: 1.5, maxInt: 3.5, sizes: [[2.0, 0.4, 0.8], [3.0, 0.4, 0.8]] },
  { row: 9, dir: 1, type: "log", minSpd: 0.5, maxSpd: 1.5, minInt: 2.0, maxInt: 5.0, sizes: [[3.0, 0.4, 0.8], [5.0, 0.4, 0.8]] },
  // Carreteras inferiores (11-13)
  { row: 11, dir: -1, type: "car", minSpd: 2.0, maxSpd: 5.0, minInt: 0.8, maxInt: 2.8, sizes: [[1.5, 0.5, 0.8], [2.0, 0.5, 0.8]] },
  { row: 12, dir: 1, type: "car", minSpd: 1.5, maxSpd: 3.5, minInt: 1.2, maxInt: 3.0, sizes: [[1.5, 0.5, 0.8], [2.5, 0.5, 0.8]] },
  { row: 13, dir: -1, type: "car", minSpd: 2.5, maxSpd: 5.5, minInt: 0.6, maxInt: 2.5, sizes: [[1.5, 0.5, 0.8], [2.0, 0.5, 0.8]] },
];

// --- Estado de jugador ---

function createPlayerState(playerNum) {
  return {
    playerNum,
    gridRow: playerNum === 1 ? 15 : 1,
    gridCol: 8,
    startRow: playerNum === 1 ? 15 : 1,
    score: 0,
  };
}

// --- Sala de juego ---

function createRoom(id, p1, p2) {
  const gameSeed = Math.floor(Math.random() * 2147483647);
  const rng = createRng(gameSeed);

  const room = {
    id,
    players: [p1, p2],
    state: "playing",
    scores: [0, 0],
    positions: [createPlayerState(1), createPlayerState(2)],
    gameSeed,
    rng,
    obstacles: [],
    spawnTimers: {},
    tickInterval: null,
  };

  // Inicializar timers de spawn
  for (const cfg of ROW_CONFIGS) {
    room.spawnTimers[cfg.row] = rng.range(0, cfg.minInt);
  }

  // Pre-poblar obstaculos (simular 10 segundos)
  const dt = 1 / TICK_RATE;
  for (let i = 0; i < TICK_RATE * 10; i++) {
    tickObstacles(room, dt);
  }

  // Iniciar game loop
  room.tickInterval = setInterval(() => tickRoom(room), TICK_MS);

  return room;
}

function destroyRoom(room) {
  if (room.tickInterval) {
    clearInterval(room.tickInterval);
    room.tickInterval = null;
  }
  rooms.delete(room.id);
}

// --- Game loop ---

function tickRoom(room) {
  if (room.state !== "playing") return;

  const dt = 1 / TICK_RATE;
  tickObstacles(room, dt);

  // Enviar estado a ambos clientes
  const obsState = room.obstacles.map((o) => ({
    id: o.id,
    row: o.row,
    x: Math.round(o.x * 100) / 100,
    dir: o.dir,
    speed: o.speed,
    type: o.type,
    size: o.size,
    modelIdx: o.modelIdx,
  }));

  sendToRoom(room, "tick", { obstacles: obsState });
}

function tickObstacles(room, dt) {
  const rng = room.rng;

  // Spawn
  for (const cfg of ROW_CONFIGS) {
    room.spawnTimers[cfg.row] -= dt;
    if (room.spawnTimers[cfg.row] <= 0) {
      if (canSpawn(room, cfg)) {
        spawnObstacle(room, cfg);
      } else {
        // Consumir RNG para determinismo
        rng.next();
        rng.next();
      }
      room.spawnTimers[cfg.row] = rng.range(cfg.minInt, cfg.maxInt);
    }
  }

  // Mover
  for (const obs of room.obstacles) {
    obs.x += obs.dir * obs.speed * dt;
  }

  // Limpiar fuera de mapa
  room.obstacles = room.obstacles.filter((o) => {
    if (o.dir > 0 && o.x > MAP_WIDTH + 4) return false;
    if (o.dir < 0 && o.x < -4) return false;
    return true;
  });
}

function canSpawn(room, cfg) {
  const spawnX = cfg.dir > 0 ? -2 : MAP_WIDTH + 2;
  let count = 0;
  for (const obs of room.obstacles) {
    if (obs.row !== cfg.row) continue;
    count++;
    if (Math.abs(obs.x - spawnX) < MIN_GAP + obs.halfW) return false;
  }
  return count < MAX_PER_ROW;
}

function spawnObstacle(room, cfg) {
  const rng = room.rng;
  const speed = Math.max(0.5, rng.range(cfg.minSpd, cfg.maxSpd));
  const size = rng.pick(cfg.sizes);
  const startX = cfg.dir > 0 ? -2 : MAP_WIDTH + 2;
  const modelIdx = Math.floor(rng.next() * 1000);

  // Anti-overlap: limitar velocidad
  const clampedSpeed = clampSpeedNoOverlap(room, cfg.row, cfg.dir, speed, size[0]);

  const obs = {
    id: nextObsId++,
    row: cfg.row,
    dir: cfg.dir,
    speed: clampedSpeed,
    x: startX,
    type: cfg.type,
    size,
    halfW: size[0] / 2,
    modelIdx,
  };

  room.obstacles.push(obs);
}

function clampSpeedNoOverlap(room, row, dir, desiredSpeed, newWidth) {
  // Buscar ultimo obstaculo en la misma fila
  let lastObs = null;
  const spawnX = dir > 0 ? -2 : MAP_WIDTH + 2;
  let minDist = Infinity;

  for (const obs of room.obstacles) {
    if (obs.row !== row) continue;
    const dist = Math.abs(obs.x - spawnX);
    if (dist < minDist) {
      minDist = dist;
      lastObs = obs;
    }
  }

  if (!lastObs) return desiredSpeed;

  const gap = Math.abs(lastObs.x - spawnX) - lastObs.halfW - newWidth / 2;
  if (gap <= 0.5) return lastObs.speed;
  if (desiredSpeed <= lastObs.speed) return desiredSpeed;

  const exitX = dir > 0 ? MAP_WIDTH + 4 : -4;
  const distToExit = Math.abs(exitX - lastObs.x);
  const timeToExit = lastObs.speed > 0 ? distToExit / lastObs.speed : 999;
  const timeToCatch = gap / (desiredSpeed - lastObs.speed);

  if (timeToCatch > timeToExit) return desiredSpeed;

  const maxSpeed = gap / timeToExit + lastObs.speed;
  return Math.min(desiredSpeed, Math.max(maxSpeed, lastObs.speed));
}

// --- Conexiones ---

wss.on("connection", (ws) => {
  ws.playerId = `p${nextId++}`;
  ws.roomId = null;
  ws.playerNum = 0;

  console.log(`[+] Connected: ${ws.playerId}`);

  ws.on("message", (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }

    switch (msg.type) {
      case "find_match":
        ws.pet = msg.pet || "";
        ws.deviceId = msg.deviceId || "";
        if (ws.deviceId) db.getOrCreatePlayer(ws.deviceId);
        handleFindMatch(ws);
        break;
      case "player_move":
        handleMove(ws, msg);
        break;
      case "player_died":
        handleDied(ws);
        break;
      case "player_scored":
        handleScored(ws);
        break;
    }
  });

  ws.on("close", () => {
    console.log(`[-] Disconnected: ${ws.playerId}`);

    if (waitingPlayer === ws) {
      waitingPlayer = null;
    }

    if (ws.roomId) {
      const room = rooms.get(ws.roomId);
      if (room) {
        if (room.state === "playing") {
          room.state = "finished";
          const opponent = room.players.find((p) => p !== ws);
          if (opponent) {
            send(opponent, "opponent_disconnected");
            // El que se queda gana, el que se desconecta pierde
            if (opponent.deviceId && ws.deviceId) {
              db.updateAfterMatch(opponent.deviceId, ws.deviceId);
              console.log(`[!] ${ws.playerId} disconnected, ${opponent.playerId} wins (+20/-20)`);
            }
          }
        }
        destroyRoom(room);
      }
    }
  });
});

function handleFindMatch(ws) {
  if (waitingPlayer && waitingPlayer.readyState === waitingPlayer.OPEN) {
    const roomId = `room_${Date.now()}`;
    const room = createRoom(roomId, waitingPlayer, ws);

    rooms.set(roomId, room);

    waitingPlayer.roomId = roomId;
    waitingPlayer.playerNum = 1;
    ws.roomId = roomId;
    ws.playerNum = 2;

    // Enviar estado inicial de obstaculos con el match
    const initObs = room.obstacles.map((o) => ({
      id: o.id,
      row: o.row,
      x: Math.round(o.x * 100) / 100,
      dir: o.dir,
      speed: o.speed,
      type: o.type,
      size: o.size,
      modelIdx: o.modelIdx,
    }));

    send(waitingPlayer, "match_found", {
      playerNum: 1,
      roomId,
      gameSeed: room.gameSeed,
      opponentPet: ws.pet || "",
      obstacles: initObs,
    });
    send(ws, "match_found", {
      playerNum: 2,
      roomId,
      gameSeed: room.gameSeed,
      opponentPet: waitingPlayer.pet || "",
      obstacles: initObs,
    });

    console.log(`[*] Match: ${roomId} (${waitingPlayer.playerId} vs ${ws.playerId})`);
    waitingPlayer = null;
  } else {
    waitingPlayer = ws;
    send(ws, "waiting");
    console.log(`[~] ${ws.playerId} waiting...`);
  }
}

function handleMove(ws, msg) {
  if (!ws.roomId) return;
  const room = rooms.get(ws.roomId);
  if (!room || room.state !== "playing") return;

  const gridRow = Math.max(0, Math.min(MAP_HEIGHT - 1, msg.gridRow));
  const gridCol = Math.max(0, Math.min(MAP_WIDTH - 1, msg.gridCol));

  const pos = room.positions[ws.playerNum - 1];
  pos.gridRow = gridRow;
  pos.gridCol = gridCol;

  const opponent = room.players.find((p) => p !== ws);
  if (opponent) {
    send(opponent, "opponent_moved", { gridRow, gridCol, playerNum: ws.playerNum });
  }
}

function handleDied(ws) {
  if (!ws.roomId) return;
  const room = rooms.get(ws.roomId);
  if (!room || room.state !== "playing") return;

  const pos = room.positions[ws.playerNum - 1];
  pos.gridRow = pos.startRow;
  pos.gridCol = 8;

  const opponent = room.players.find((p) => p !== ws);
  if (opponent) {
    send(opponent, "opponent_died", { playerNum: ws.playerNum });
  }
}

function handleScored(ws) {
  if (!ws.roomId) return;
  const room = rooms.get(ws.roomId);
  if (!room || room.state !== "playing") return;

  room.scores[ws.playerNum - 1] += 1;
  const score = room.scores[ws.playerNum - 1];

  const pos = room.positions[ws.playerNum - 1];
  pos.gridRow = pos.startRow;
  pos.gridCol = 8;

  const opponent = room.players.find((p) => p !== ws);
  if (opponent) {
    send(opponent, "opponent_respawned", { playerNum: ws.playerNum });
  }

  sendToRoom(room, "score_update", { playerNum: ws.playerNum, score });

  if (score >= FROGS_TO_WIN) {
    room.state = "finished";
    sendToRoom(room, "game_over", { winner: ws.playerNum });

    // Actualizar stats en DB
    const winner = room.players.find((p) => p.playerNum === ws.playerNum);
    const loser = room.players.find((p) => p.playerNum !== ws.playerNum);
    if (winner && loser && winner.deviceId && loser.deviceId) {
      db.updateAfterMatch(winner.deviceId, loser.deviceId);
      console.log(`[!] Player ${ws.playerNum} wins in ${ws.roomId} (${winner.deviceId} +20, ${loser.deviceId} -20)`);
    } else {
      console.log(`[!] Player ${ws.playerNum} wins in ${ws.roomId}`);
    }

    destroyRoom(room);
  }
}

server.listen(PORT, () => {
  console.log(`[Frog Race Server] WebSocket + Dashboard on port ${PORT} (${TICK_RATE} ticks/s)`);
  console.log(`[Dashboard] http://localhost:${PORT}`);
});
