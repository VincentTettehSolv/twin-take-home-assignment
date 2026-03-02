'use strict';

/**
 * PostgreSQL client module.
 *
 * Uses a connection pool (pg.Pool) sourced from the DATABASE_URL env var.
 * Designed to fail gracefully — if DATABASE_URL is not set the app starts
 * normally, all DB routes return 503, and the readiness probe marks the
 * `postgres` check as "disabled" rather than crashing.
 */

const { Pool } = require('pg');
const logger = require('../logger');

let pool = null;

/**
 * Returns the singleton Pool, creating it on first call if DATABASE_URL is set.
 */
function getPool() {
    if (pool) { return pool; }
    if (!process.env.DATABASE_URL) { return null; }

    pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        max: 5,
        idleTimeoutMillis: 30_000,
        connectionTimeoutMillis: 3_000,
    });

    pool.on('error', (err) => {
        logger.error('Unexpected Postgres pool error', { error: err.message });
    });

    return pool;
}

/**
 * Run a parameterised query.
 * @param {string} text  SQL string (use $1, $2 … for params)
 * @param {Array}  params
 * @returns {Promise<import('pg').QueryResult>}
 */
async function query(text, params) {
    const p = getPool();
    if (!p) { throw new Error('Postgres not configured (DATABASE_URL not set)'); }
    return p.query(text, params);
}

/**
 * Health check — runs SELECT 1 to verify connectivity.
 * @returns {{ status: 'ok'|'disabled'|'error', message?: string }}
 */
async function healthCheck() {
    const p = getPool();
    if (!p) { return { status: 'disabled', message: 'DATABASE_URL not set' }; }

    try {
        await p.query('SELECT 1');
        return { status: 'ok' };
    } catch (err) {
        return { status: 'error', message: err.message };
    }
}

/**
 * Creates the page_hits table and seeds the counter row on first run.
 * Called once at application startup — safe to call multiple times (idempotent).
 */
async function initSchema() {
    const p = getPool();
    if (!p) {
        logger.warn('Postgres: skipping schema init — DATABASE_URL not set');
        return;
    }

    try {
        await p.query(`
      CREATE TABLE IF NOT EXISTS page_hits (
        id   INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
        hits BIGINT  NOT NULL DEFAULT 0
      )
    `);

        await p.query(`
      INSERT INTO page_hits (id, hits)
      VALUES (1, 0)
      ON CONFLICT (id) DO NOTHING
    `);

        logger.info('Postgres: schema initialised');
    } catch (err) {
        // Do not crash the app — DB may not be ready yet at startup.
        logger.warn('Postgres: schema init failed', { error: err.message });
    }
}

module.exports = { getPool, query, healthCheck, initSchema };
