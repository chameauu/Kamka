# Fullstack Application

A Docker-based fullstack application with three core services: MySQL database, Node.js backend API, and Nginx frontend.

## Services

### 1. MySQL Service
- **Container**: `mysql-service`
- **Port**: `3306`
- **Role**: Relational database for storing user data
- **Features**:
  - Automatic table creation on startup
  - Health checks enabled
  - Persistent volume storage (`mysql_data`)
  - User authentication with environment variables

### 2. Backend Service
- **Container**: `backend-service`
- **Port**: `3000`
- **Role**: Express.js API server
- **Features**:
  - REST endpoints for user management (`GET`, `POST`, `DELETE`)
  - Prometheus metrics tracking
  - Health check endpoint (`/health`)
  - CORS enabled
  - Connects to MySQL database
  - Metrics exposed at `/metrics`

### 3. Frontend Service
- **Container**: `frontend-service`
- **Port**: `8080`
- **Role**: Nginx web server
- **Features**:
  - Static file serving
  - Health checks enabled
  - Nginx Prometheus exporter integration
  - Reverse proxy ready

### 4. Nginx Exporter (Bonus)
- **Container**: `nginx-exporter`
- **Port**: `9113`
- **Role**: Prometheus metrics exporter for Nginx monitoring

## Quick Start

1. **Setup environment variables**:
   ```bash
   cp .env.example .env
   ```

2. **Build and start services**:
   ```bash
   docker compose up --build
   ```

3. **Access services**:
   - Frontend: `http://localhost:8080`
   - Backend API: `http://localhost:3000`
   - Metrics: `http://localhost:3000/metrics`
   - Nginx Exporter: `http://localhost:9113`
   - MySQL: `localhost:3306`

## API Endpoints

### Users
- `GET /api/users` - Get all users
- `POST /api/users` - Create new user (body: `{name, email}`)
- `DELETE /api/users/:id` - Delete user by ID

### Health & Metrics
- `GET /health` - Backend health check
- `GET /metrics` - Prometheus metrics

## Environment Variables

See `.env.example` for required configuration:
- `MYSQL_ROOT_PASSWORD`
- `MYSQL_DATABASE`
- `MYSQL_USER`
- `MYSQL_PASSWORD`

## Service Dependencies

- Frontend depends on Backend (healthcheck)
- Backend depends on MySQL (healthcheck)
- Nginx Exporter depends on Frontend (healthcheck)

## Volumes

- `mysql_data` - MySQL persistent storage

## Development

To stop services:
```bash
docker compose down
```

To view logs:
```bash
docker compose logs -f [service-name]
```

To rebuild a specific service:
```bash
docker compose up --build [service-name]
```
