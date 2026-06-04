// __tests__/server.test.js
const request = require('supertest');

// Mock mysql2/promise to avoid real DB connections
jest.mock('mysql2/promise', () => {
  const mockExecute = jest.fn();
  const mockPool = { execute: mockExecute };
  return { createPool: jest.fn(() => mockPool) };
});

// Mock prom-client to avoid metric side‑effects (enhanced)
jest.mock('prom-client', () => {
  class Registry {
    constructor() {
      this.contentType = 'text/plain';
    }
    metrics() { return ''; }
  }
  class Counter {
    inc() {}
    labels() { return this; }
  }
  class Gauge {
    set() {}
    labels() { return this; }
  }
  class Histogram {
    observe() {}
    labels() { return this; }
  }
  const register = new Registry();
  Registry.defaultRegistry = register;
  return {
    Registry,
    Counter,
    Gauge,
    Histogram,
    register
  };
});

const { app, initDB } = require('../server');

beforeAll(async () => {
  await initDB();
});

describe('Backend API', () => {
  test('GET /health returns status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  test('POST /api/users creates a user', async () => {
    // Mock the INSERT query response
    const mysql = require('mysql2/promise');
    mysql.createPool().execute.mockResolvedValueOnce([{ insertId: 1 }]);

    const res = await request(app)
      .post('/api/users')
      .send({ name: 'Alice', email: 'alice@example.com' });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toMatchObject({ id: 1, name: 'Alice', email: 'alice@example.com' });
  });

  test('GET /api/users returns an empty list', async () => {
    const mysql = require('mysql2/promise');
    mysql.createPool().execute.mockResolvedValueOnce([[]]);
    const res = await request(app).get('/api/users');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBe(0);
  });

  test('DELETE /api/users/:id deletes a user', async () => {
    const mysql = require('mysql2/promise');
    mysql.createPool().execute.mockResolvedValueOnce([]);
    const res = await request(app).delete('/api/users/1');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.message).toBe('User deleted');
  });
});
