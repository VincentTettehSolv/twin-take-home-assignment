'use strict';

/**
 * Redis client module.
 *
 * Uses ioredis sourced from the REDIS_URL env var.
 * Designed to fail gracefully — if REDIS_URL is not set the app starts
 * normally and all cache routes return 503.
 */

const logger = require('../logger');

let client = null;

/**
 * Returns the singleton ioredis client, creating it on first call.
 * @returns {import('ioredis').Redis|null}
 */
function getClient() {
    if (client) return client;
    if (!process.env.REDIS_URL) return null;

    // Lazy require so the module loads even when ioredis is absent (tests).
    const Redis = require('ioredis');

    client = new Redis(process.env.REDIS_URL, {
        lazyConnect: true,
        enableReadyCheck: false,  // don't block until Redis sends READY
        maxRetriesPerRequest: 1,
        connectTimeout: 3_000,
        commandTimeout: 3_000,
        retryStrategy: (times) => (times > 3 ? null : Math.min(times * 200, 2000)),
    });

    client.on('connect', () => logger.info('Redis: connected'));
    client.on('error', (err) => {
        // ioredis emits 'error' on every failed reconnect — log but don't crash.
        logger.warn('Redis: connection error', { error: err.message });
    });

    return client;
}

/**
 * Health check — sends PING to Redis.
 * @returns {{ status: 'ok'|'disabled'|'error', message?: string }}
 */
async function ping() {
    const c = getClient();
    if (!c) return { status: 'disabled', message: 'REDIS_URL not set' };

    try {
        const result = await c.ping();
        return result === 'PONG' ? { status: 'ok' } : { status: 'error', message: `Unexpected PING response: ${result}` };
    } catch (err) {
        return { status: 'error', message: err.message };
    }
}

module.exports = { getClient, ping };
