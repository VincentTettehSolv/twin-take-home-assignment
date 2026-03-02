'use strict';

const express = require('express');
const router = express.Router();

const postgres = require('../db/postgres');
const redis = require('../db/redis');

// ─── Redis Cache ──────────────────────────────────────────────────────────────

/**
 * GET /api/cache/:key
 * Retrieve a value from the Redis cache.
 */
router.get('/cache/:key', async (req, res, next) => {
    try {
        const client = redis.getClient();
        if (!client) {
            return res.status(503).json({ error: 'Redis not configured', hint: 'Set REDIS_URL env var' });
        }

        const value = await client.get(req.params.key);
        if (value === null) {
            return res.status(404).json({ error: 'Key not found', key: req.params.key });
        }

        res.json({ key: req.params.key, value });
    } catch (err) {
        next(err);
    }
});

/**
 * POST /api/cache/:key
 * Store a value in the Redis cache.
 * Body: { "value": "...", "ttl": 3600 }
 */
router.post('/cache/:key', async (req, res, next) => {
    try {
        const client = redis.getClient();
        if (!client) {
            return res.status(503).json({ error: 'Redis not configured', hint: 'Set REDIS_URL env var' });
        }

        const { value, ttl = 3600 } = req.body;

        if (value === undefined) {
            return res.status(400).json({ error: 'Request body must include "value"' });
        }

        // Store as string; EX sets TTL in seconds.
        await client.set(req.params.key, String(value), 'EX', Number(ttl));

        res.status(201).json({ key: req.params.key, value: String(value), ttl: Number(ttl) });
    } catch (err) {
        next(err);
    }
});

/**
 * DELETE /api/cache/:key
 * Remove a key from Redis.
 */
router.delete('/cache/:key', async (req, res, next) => {
    try {
        const client = redis.getClient();
        if (!client) {
            return res.status(503).json({ error: 'Redis not configured' });
        }

        const deleted = await client.del(req.params.key);
        res.json({ key: req.params.key, deleted: deleted === 1 });
    } catch (err) {
        next(err);
    }
});

// ─── Postgres Hit Counter ─────────────────────────────────────────────────────

/**
 * GET /api/db/hits
 * Returns the current page-hit count from Postgres.
 */
router.get('/db/hits', async (req, res, next) => {
    try {
        const result = await postgres.query('SELECT hits FROM page_hits WHERE id = 1');
        res.json({ hits: Number(result.rows[0]?.hits ?? 0) });
    } catch (err) {
        if (err.message.includes('not configured')) {
            return res.status(503).json({ error: 'Database not configured', hint: 'Set DATABASE_URL env var' });
        }
        if (err.message.includes('does not exist')) {
            return res.status(503).json({ error: 'Schema not initialised' });
        }
        next(err);
    }
});

/**
 * POST /api/db/hits
 * Atomically increments and returns the hit counter.
 */
router.post('/db/hits', async (req, res, next) => {
    try {
        const result = await postgres.query(
            'UPDATE page_hits SET hits = hits + 1 WHERE id = 1 RETURNING hits'
        );
        res.json({ hits: Number(result.rows[0]?.hits ?? 0) });
    } catch (err) {
        if (err.message.includes('not configured')) {
            return res.status(503).json({ error: 'Database not configured', hint: 'Set DATABASE_URL env var' });
        }
        next(err);
    }
});

module.exports = router;
