const Database = require("better-sqlite3");
const path = require("path");

const db = new Database(path.join(__dirname, "frograce.db"));

// Crear tabla
db.exec(`
  CREATE TABLE IF NOT EXISTS players (
    device_id TEXT PRIMARY KEY,
    nickname TEXT DEFAULT 'Anonymous',
    rating INTEGER DEFAULT 0,
    wins INTEGER DEFAULT 0,
    losses INTEGER DEFAULT 0,
    games_played INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    last_seen TEXT DEFAULT (datetime('now'))
  )
`);

function getOrCreatePlayer(deviceId) {
  let player = db.prepare("SELECT * FROM players WHERE device_id = ?").get(deviceId);
  if (!player) {
    db.prepare("INSERT INTO players (device_id) VALUES (?)").run(deviceId);
    player = db.prepare("SELECT * FROM players WHERE device_id = ?").get(deviceId);
  } else {
    db.prepare("UPDATE players SET last_seen = datetime('now') WHERE device_id = ?").run(deviceId);
  }
  return player;
}

function updateAfterMatch(winnerDeviceId, loserDeviceId) {
  const updateWinner = db.prepare(`
    UPDATE players SET
      rating = rating + 20,
      wins = wins + 1,
      games_played = games_played + 1,
      last_seen = datetime('now')
    WHERE device_id = ?
  `);

  const updateLoser = db.prepare(`
    UPDATE players SET
      rating = MAX(0, rating - 20),
      losses = losses + 1,
      games_played = games_played + 1,
      last_seen = datetime('now')
    WHERE device_id = ?
  `);

  const transaction = db.transaction(() => {
    updateWinner.run(winnerDeviceId);
    updateLoser.run(loserDeviceId);
  });

  transaction();
}

function getLeaderboard(limit = 100) {
  return db.prepare(`
    SELECT device_id, nickname, rating, wins, losses, games_played
    FROM players
    ORDER BY rating DESC
    LIMIT ?
  `).all(limit);
}

function getPlayerStats(deviceId) {
  return db.prepare("SELECT * FROM players WHERE device_id = ?").get(deviceId);
}

function getGlobalStats() {
  const totalPlayers = db.prepare("SELECT COUNT(*) as count FROM players").get().count;
  const totalGames = db.prepare("SELECT SUM(games_played) / 2 as count FROM players").get().count || 0;
  const activeLast24h = db.prepare(
    "SELECT COUNT(*) as count FROM players WHERE last_seen > datetime('now', '-1 day')"
  ).get().count;
  return { totalPlayers, totalGames, activeLast24h };
}

module.exports = {
  getOrCreatePlayer,
  updateAfterMatch,
  getLeaderboard,
  getPlayerStats,
  getGlobalStats,
};
