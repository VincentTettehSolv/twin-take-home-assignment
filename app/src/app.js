'use strict';

const express = require('express');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const path = require('path');

const logger = require('./logger');
const { requestId } = require('./middleware/requestId');
const { errorHandler } = require('./middleware/errorHandler');
const healthRoutes = require('./routes/health');
const apiRoutes = require('./routes/api');
const metricsRoutes = require('./routes/metrics');
const dataRoutes = require('./routes/data');
const postgres = require('./db/postgres');

const app = express();

// ─── Security Headers ─────────────────────────────────────────────────────────
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", "'unsafe-inline'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", 'data:'],
      },
    },
    referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  })
);

// ─── Trust Proxy (for k8s ingress) ────────────────────────────────────────────
app.set('trust proxy', 1);

// ─── Rate Limiting ────────────────────────────────────────────────────────────
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 500,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later.' },
  skip: (req) => req.path === '/health' || req.path === '/metrics',
});
app.use(limiter);

// ─── Request ID ───────────────────────────────────────────────────────────────
app.use(requestId);

// ─── Logging ──────────────────────────────────────────────────────────────────
app.use(
  morgan('combined', {
    stream: { write: (msg) => logger.http(msg.trim()) },
    skip: (req) => req.path === '/health',
  })
);

// ─── Body Parsing ─────────────────────────────────────────────────────────────
app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ extended: false, limit: '10kb' }));

// ─── Static Files ─────────────────────────────────────────────────────────────
app.use(express.static(path.join(__dirname, 'public')));

// ─── Routes ───────────────────────────────────────────────────────────────────
app.use('/', healthRoutes);   // /health, /health/ready, /health/live
app.use('/api', apiRoutes);      // /api/info
app.use('/api', dataRoutes);     // /api/cache/:key, /api/db/hits
app.use('/', metricsRoutes);  // /metrics (Prometheus)

// Root — serve the web page
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ─── 404 Handler ──────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ error: 'Not Found', path: req.path });
});

// ─── Error Handler ────────────────────────────────────────────────────────────
app.use(errorHandler);

// ─── DB Schema Init ───────────────────────────────────────────────────────────
// Run asynchronously after the app is exported so the server can start fast.
// Safe to call multiple times — uses CREATE TABLE IF NOT EXISTS.
setImmediate(() => {
  postgres.initSchema().catch((err) =>
    logger.warn('Postgres schema init error at startup', { error: err.message })
  );
});

module.exports = app;
