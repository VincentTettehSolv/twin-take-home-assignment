'use strict';

const request = require('supertest');
const app = require('../src/app');

describe('Health Endpoints', () => {
  it('GET /health → 200 { status: ok }', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });

  it('GET /health/ready → 200 with uptime and DB checks', async () => {
    const res = await request(app).get('/health/ready');
    expect(res.status).toBe(200); // 'disabled' counts as ok — no DB env vars in tests
    expect(res.body.status).toBe('ready');
    expect(typeof res.body.uptime_ms).toBe('number');
    expect(res.body.checks.server).toBe('ok');
    // DB checks are present and report 'disabled' (no DATABASE_URL/REDIS_URL in test env)
    expect(res.body.checks).toHaveProperty('postgres');
    expect(res.body.checks).toHaveProperty('redis');
  });

  it('GET /health/live → 200 { status: ok }', async () => {
    const res = await request(app).get('/health/live');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});

describe('API Endpoints', () => {
  it('GET /api/info → 200 with correct shape', async () => {
    const res = await request(app).get('/api/info');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('version');
    expect(res.body).toHaveProperty('environment');
    expect(res.body).toHaveProperty('timestamp');
    expect(res.body).toHaveProperty('hostname');
    expect(res.body).toHaveProperty('uptime_seconds');
    expect(res.body).toHaveProperty('memory');
    // databases field is present; status is 'disabled' when env vars are not set
    expect(res.body).toHaveProperty('databases');
    expect(res.body.databases).toHaveProperty('postgres');
    expect(res.body.databases).toHaveProperty('redis');
  });

  it('GET /api/info timestamp is valid ISO8601', async () => {
    const res = await request(app).get('/api/info');
    expect(() => new Date(res.body.timestamp)).not.toThrow();
    expect(new Date(res.body.timestamp).toISOString()).toBe(res.body.timestamp);
  });

  it('GET /api/info uses APP_ENV env var', async () => {
    process.env.APP_ENV = 'staging';
    const res = await request(app).get('/api/info');
    expect(res.body.environment).toBe('staging');
    delete process.env.APP_ENV;
  });
});

describe('Metrics Endpoint', () => {
  it('GET /metrics → 200 with prometheus format', async () => {
    const res = await request(app).get('/metrics');
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/text\/plain/);
  });
});

describe('Web Page', () => {
  it('GET / → 200 HTML page', async () => {
    const res = await request(app).get('/');
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/html/);
  });
});

describe('Security Headers', () => {
  it('responses include security headers', async () => {
    const res = await request(app).get('/health');
    expect(res.headers).toHaveProperty('x-content-type-options');
    expect(res.headers).toHaveProperty('x-frame-options');
  });

  it('responses include X-Request-ID', async () => {
    const res = await request(app).get('/health');
    expect(res.headers).toHaveProperty('x-request-id');
  });
});

describe('404 Handling', () => {
  it('GET /nonexistent → 404', async () => {
    const res = await request(app).get('/nonexistent-route-xyz');
    expect(res.status).toBe(404);
    expect(res.body).toHaveProperty('error');
  });
});
