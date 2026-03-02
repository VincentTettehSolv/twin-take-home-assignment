'use strict';

const express = require('express');
const router = express.Router();
const client = require('prom-client');

// ─── Prometheus Registry ──────────────────────────────────────────────────────
const register = new client.Registry();

// Default Node.js metrics (CPU, memory, GC, event loop lag, etc.)
client.collectDefaultMetrics({
  register,
  prefix: 'app_',
  labels: {
    app: 'devops-takehome',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.APP_ENV || 'local',
  },
});

// ─── Custom Metrics ───────────────────────────────────────────────────────────

/** Total HTTP requests counter */
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register],
});

/** HTTP request duration histogram */
const httpRequestDurationSeconds = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
  registers: [register],
});

/** Active connections gauge */
const activeConnections = new client.Gauge({
  name: 'active_connections',
  help: 'Number of active HTTP connections',
  registers: [register],
});

// ─── Middleware to track metrics ──────────────────────────────────────────────
const metricsMiddleware = (req, res, next) => {
  if (req.path === '/metrics') { return next(); }

  const start = process.hrtime.bigint();
  activeConnections.inc();

  res.on('finish', () => {
    const durationNs = Number(process.hrtime.bigint() - start);
    const durationSecs = durationNs / 1e9;
    const route = req.route ? req.route.path : req.path;

    httpRequestsTotal.inc({
      method: req.method,
      route,
      status_code: res.statusCode,
    });

    httpRequestDurationSeconds.observe(
      { method: req.method, route, status_code: res.statusCode },
      durationSecs
    );

    activeConnections.dec();
  });

  next();
};

/**
 * GET /metrics
 * Exposes Prometheus-compatible metrics for scraping.
 * In production, restrict this endpoint at the ingress/network level.
 */
router.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    res.status(500).end(err.message);
  }
});

module.exports = router;
module.exports.metricsMiddleware = metricsMiddleware;
module.exports.register = register;
