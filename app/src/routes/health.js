'use strict';

const express = require('express');
const router = express.Router();

const postgres = require('../db/postgres');
const redis = require('../db/redis');

const START_TIME = Date.now();

/**
 * GET /health
 * Liveness probe — confirms the process is alive.
 * Returns 200 immediately; does not check dependencies.
 */
router.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

/**
 * GET /health/ready
 * Readiness probe — confirms the app is ready to serve traffic.
 * Checks Postgres and Redis connectivity in parallel.
 * Returns 503 if either dependency is in 'error' state.
 * 'disabled' (env var not set) is treated as OK so local dev still works.
 */
router.get('/health/ready', async (req, res) => {
  const uptimeMs = Date.now() - START_TIME;

  const [pgStatus, redisStatus] = await Promise.all([
    postgres.healthCheck(),
    redis.ping(),
  ]);

  const allOk = pgStatus.status !== 'error' && redisStatus.status !== 'error';

  res.status(allOk ? 200 : 503).json({
    status: allOk ? 'ready' : 'degraded',
    uptime_ms: uptimeMs,
    uptime_human: formatUptime(uptimeMs),
    checks: {
      server: 'ok',
      postgres: pgStatus.status,
      redis: redisStatus.status,
    },
  });
});

/**
 * GET /health/live
 * Alias for liveness probe (k8s convention).
 */
router.get('/health/live', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

function formatUptime(ms) {
  const seconds = Math.floor(ms / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  return `${days}d ${hours % 24}h ${minutes % 60}m ${seconds % 60}s`;
}

module.exports = router;
