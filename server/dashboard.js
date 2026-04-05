const express = require("express");
const path = require("path");
const db = require("./db");

function setupDashboard(app) {
  app.use(express.static(path.join(__dirname, "public")));

  app.get("/api/leaderboard", (req, res) => {
    const limit = parseInt(req.query.limit) || 100;
    res.json(db.getLeaderboard(limit));
  });

  app.get("/api/player/:deviceId", (req, res) => {
    const player = db.getPlayerStats(req.params.deviceId);
    if (player) {
      res.json(player);
    } else {
      res.status(404).json({ error: "Player not found" });
    }
  });

  app.get("/api/stats", (req, res) => {
    res.json(db.getGlobalStats());
  });
}

module.exports = { setupDashboard };
