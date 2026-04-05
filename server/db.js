const fs = require("fs");
const path = require("path");

const DB_PATH = path.join(__dirname, "frograce.json");

function loadDb() {
  try {
    if (fs.existsSync(DB_PATH)) {
      return JSON.parse(fs.readFileSync(DB_PATH, "utf8"));
    }
  } catch {}
  return { players: {} };
}

function saveDb(data) {
  fs.writeFileSync(DB_PATH, JSON.stringify(data, null, 2));
}

function getOrCreatePlayer(deviceId) {
  const data = loadDb();
  if (!data.players[deviceId]) {
    data.players[deviceId] = {
      device_id: deviceId,
      nickname: "Anonymous",
      rating: 0,
      wins: 0,
      losses: 0,
      games_played: 0,
      created_at: new Date().toISOString(),
      last_seen: new Date().toISOString(),
    };
    saveDb(data);
  } else {
    data.players[deviceId].last_seen = new Date().toISOString();
    saveDb(data);
  }
  return data.players[deviceId];
}

function updateAfterMatch(winnerDeviceId, loserDeviceId) {
  const data = loadDb();
  const winner = data.players[winnerDeviceId];
  const loser = data.players[loserDeviceId];
  if (winner) {
    winner.rating += 20;
    winner.wins += 1;
    winner.games_played += 1;
    winner.last_seen = new Date().toISOString();
  }
  if (loser) {
    loser.rating = Math.max(0, loser.rating - 20);
    loser.losses += 1;
    loser.games_played += 1;
    loser.last_seen = new Date().toISOString();
  }
  saveDb(data);
}

function getLeaderboard(limit = 100) {
  const data = loadDb();
  return Object.values(data.players)
    .sort((a, b) => b.rating - a.rating)
    .slice(0, limit);
}

function getPlayerStats(deviceId) {
  const data = loadDb();
  return data.players[deviceId] || null;
}

function getGlobalStats() {
  const data = loadDb();
  const players = Object.values(data.players);
  const totalPlayers = players.length;
  const totalGames = Math.floor(players.reduce((sum, p) => sum + p.games_played, 0) / 2);
  const now = Date.now();
  const activeLast24h = players.filter(
    (p) => now - new Date(p.last_seen).getTime() < 86400000
  ).length;
  return { totalPlayers, totalGames, activeLast24h };
}

module.exports = {
  getOrCreatePlayer,
  updateAfterMatch,
  getLeaderboard,
  getPlayerStats,
  getGlobalStats,
};
