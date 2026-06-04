const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const prometheus = require('prom-client');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

// Prometheus metrics setup
const register = new prometheus.Registry();

// Counters
const httpRequestsTotal = new prometheus.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const apiErrorsTotal = new prometheus.Counter({
  name: 'api_errors_total',
  help: 'Total API errors',
  labelNames: ['route', 'error_type'],
  registers: [register]
});

const usersCreatedTotal = new prometheus.Counter({
  name: 'users_created_total',
  help: 'Total users created',
  registers: [register]
});

const usersDeletedTotal = new prometheus.Counter({
  name: 'users_deleted_total',
  help: 'Total users deleted',
  registers: [register]
});

// Gauges
const dbConnectionPoolSize = new prometheus.Gauge({
  name: 'db_connection_pool_size',
  help: 'Database connection pool size',
  registers: [register]
});

const dbConnectedStatus = new prometheus.Gauge({
  name: 'db_connected_status',
  help: 'Database connection status (1 = connected, 0 = disconnected)',
  registers: [register]
});

const backendUp = new prometheus.Gauge({
  name: 'backend_up',
  help: 'Backend service up status',
  registers: [register]
});

// Histograms
const httpRequestDuration = new prometheus.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request latency in seconds',
  labelNames: ['method', 'route'],
  buckets: [0.001, 0.01, 0.05, 0.1, 0.5, 1, 2, 5],
  registers: [register]
});

const dbQueryDuration = new prometheus.Histogram({
  name: 'db_query_duration_seconds',
  help: 'Database query duration in seconds',
  labelNames: ['operation'],
  buckets: [0.001, 0.01, 0.05, 0.1, 0.5, 1],
  registers: [register]
});

// Middleware to track request metrics
app.use((req, res, next) => {
  const startTime = Date.now();
  const route = req.route?.path || req.path;

  res.on('finish', () => {
    const duration = (Date.now() - startTime) / 1000;
    httpRequestDuration.labels(req.method, route).observe(duration);
    httpRequestsTotal.labels(req.method, route, res.statusCode).inc();
  });

  next();
});

// MySQL connection config
const dbConfig = {
  host: process.env.DB_HOST || 'mysql-service',
  user: process.env.DB_USER || 'appuser',
  password: process.env.DB_PASSWORD || 'apppass123',
  database: process.env.DB_NAME || 'appdb'
};

let pool;

// Initialize database connection
async function initDB() {
  try {
    pool = mysql.createPool(dbConfig);
    
    // Create table if not exists
    await pool.execute(`
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    
    dbConnectedStatus.set(1);
    dbConnectionPoolSize.set(10); // Default pool size
    backendUp.set(1);
    console.log('✓ Database connected and table created');
  } catch (error) {
    console.error('Database connection error:', error);
    dbConnectedStatus.set(0);
    backendUp.set(0);
    setTimeout(initDB, 5000); // Retry after 5 seconds
  }
}

// Health check - basic liveness probe
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Prometheus metrics endpoint
app.get('/metrics', (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(register.metrics());
});





// Get all users
app.get('/api/users', async (req, res) => {
  try {
    const startTime = Date.now();
    const [rows] = await pool.execute('SELECT * FROM users ORDER BY created_at DESC');
    const duration = (Date.now() - startTime) / 1000;
    
    dbQueryDuration.labels('select').observe(duration);
    res.json({ success: true, data: rows });
  } catch (error) {
    console.error('Error fetching users:', error);
    apiErrorsTotal.labels('/api/users', 'fetch_error').inc();
    res.status(500).json({ success: false, error: error.message });
  }
});

// Add new user
app.post('/api/users', async (req, res) => {
  const { name, email } = req.body;
  
  if (!name || !email) {
    return res.status(400).json({ success: false, error: 'Name and email are required' });
  }
  
  try {
    const startTime = Date.now();
    const [result] = await pool.execute(
      'INSERT INTO users (name, email) VALUES (?, ?)',
      [name, email]
    );
    const duration = (Date.now() - startTime) / 1000;
    
    dbQueryDuration.labels('insert').observe(duration);
    usersCreatedTotal.inc();
    
    res.json({ 
      success: true, 
      data: { id: result.insertId, name, email }
    });
  } catch (error) {
    console.error('Error adding user:', error);
    apiErrorsTotal.labels('/api/users', 'insert_error').inc();
    res.status(500).json({ success: false, error: error.message });
  }
});

// Delete user
app.delete('/api/users/:id', async (req, res) => {
  const { id } = req.params;
  
  try {
    const startTime = Date.now();
    await pool.execute('DELETE FROM users WHERE id = ?', [id]);
    const duration = (Date.now() - startTime) / 1000;
    
    dbQueryDuration.labels('delete').observe(duration);
    usersDeletedTotal.inc();
    
    res.json({ success: true, message: 'User deleted' });
  } catch (error) {
    console.error('Error deleting user:', error);
    apiErrorsTotal.labels('/api/users/:id', 'delete_error').inc();
    res.status(500).json({ success: false, error: error.message });
  }
});

// Export app for testing
module.exports = { app, initDB };

// Start server only when run directly
if (require.main === module) {
  initDB().then(() => {
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`✓ Backend API running on port ${PORT}`);
    });
  });
}
