'use strict';

const express = require('express');
const router = express.Router();
const os = require('os');

const postgres = require('../db/postgres');
const redis = require('../db/redis');

/**
 * GET /api/info
 * Returns application metadata: version, environment, timestamp, and DB status.
 * Used by the frontend dashboard and for operational visibility.
 */
router.get('/info', async (req, res) => {
  const [pgStatus, redisStatus] = await Promise.all([
    postgres.healthCheck(),
    redis.ping(),
  ]);

  res.status(200).json({
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.APP_ENV || 'local',
    timestamp: new Date().toISOString(),
    hostname: os.hostname(),
    uptime_seconds: Math.floor(process.uptime()),
    node_version: process.version,
    memory: {
      rss_mb: (process.memoryUsage().rss / 1024 / 1024).toFixed(2),
      heap_used_mb: (process.memoryUsage().heapUsed / 1024 / 1024).toFixed(2),
      heap_total_mb: (process.memoryUsage().heapTotal / 1024 / 1024).toFixed(2),
    },
    databases: {
      postgres: pgStatus.status,
      redis: redisStatus.status,
    },
  });
});

module.exports = router;
