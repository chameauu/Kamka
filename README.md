# 👥 Kamka — Containerized Fullstack Application

A production-grade, containerized fullstack web application equipped with REST APIs, vanilla HTML/CSS frontend, a comprehensive Prometheus/Grafana observability stack, and a robust health-checked deployment script with automatic rollback capabilities.

---

## 🏗️ Architecture & Stack Overview

```
                        [ Internet ]
                             │
                             ▼ (Port 80)
                     ┌───────────────┐
                     │     NGINX     │
                     │  (Frontend)   │
                     └───────────────┘
                       /           \
         (Internal proxy)           (Static HTML/CSS)
                      /               \
                     ▼                 ▼
             ┌───────────────┐   ┌───────────────┐
             │    Express    │   │  User portal  │
             │   (Backend)   │   │  (index.html) │
             └───────────────┘   └───────────────┘
                     │
                     ▼
             ┌───────────────┐
             │     MySQL     │
             │  (Database)   │
             └───────────────┘
```

- **Frontend**: Nginx serving static assets and reverse proxying `/api/*` requests internally.
- **Backend**: Express.js REST API with database pooling and Prometheus instrumentation.
- **Database**: MySQL 8.0 with automated schema migrations.
- **Observability**: Prometheus scraping Nginx, Backend, & MySQL endpoints; Grafana dashboards.
- **CI/CD**: GitHub Actions matrix workflow with smart path-based conditional cache gating.

---

## 🚀 Quick Start (Development Mode)

Get the application up and running locally in development mode in under 2 minutes:

### 1. Configure Environment
Clone the repository and copy the env configuration file:
```bash
cd fullstack-app
cp .env.example .env
```

### 2. Boot Up the Cluster
Spin up all services in development mode:
```bash
docker compose up --build
```

### 3. Access Local Endpoints
- **Web UI**: [http://localhost:8080](http://localhost:8080)
- **API Status**: [http://localhost:3000/health](http://localhost:3000/health)
- **Prometheus Metrics**: [http://localhost:3000/metrics](http://localhost:3000/metrics)
- **Grafana Dashboards**: [http://localhost:3001](http://localhost:3001)

---

## 🔒 Hardened Production Deployment

To run in a secure, hardened production mode, use the production compose override file:
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

### Production Security & Parity Features:
- **Zero Exposed Dev Ports**: Closes public ports for MySQL (`3306`), Backend (`3000`), Exporters (`9113`, `9104`), and Prometheus (`9090`). Only Nginx (`80`) and Grafana (`3001`) are exposed.
- **Resource Constraints**: Limits CPU and Memory allocations for core services (e.g., MySQL capped at 512MB RAM, Express at 256MB).
- **Auto-Recovery**: Containers use `restart: always` to recover from failure or system reboots.

---

## 🔄 Automated Rolling Deployments & Rollbacks

We provide a production-grade Bash deployment script ([deploy.sh](file:///home/chameau/Desktop/Kamka/fullstack-app/scripts/deploy.sh)) that handles rolling updates, native container healthchecks, and automated rollbacks on failure.

### Usage
```bash
./scripts/deploy.sh <tag>
```

### How to Test Deploy and Rollback (Local Sandbox)

To verify the deployment orchestration without pushing to a remote registry, follow these sandbox steps:

#### 1. Build and Tag Healthy Release (`1`)
```bash
docker tag fullstack-app-backend-service ichameau/fullstack-backend:1
docker tag fullstack-app-frontend-service ichameau/fullstack-frontend:1
```

#### 2. Run Deploy for `1`
```bash
./scripts/deploy.sh 1
```
*Result: The script will pull the tag locally, trigger sequential rolling replacement of the containers, wait for the Docker healthcheck status to become `healthy`, and complete.*

#### 3. Build the Broken Release (`error`)
We have pre-configured sandbox folders `backend-error/` and `frontend-error/` containing misconfigured health parameters:
```bash
# Build the faulty images
docker build -t ichameau/fullstack-backend:error ./backend-error
docker build -t ichameau/fullstack-frontend:error ./frontend-error
```

#### 4. Test Deploy and Auto-Rollback
Deploy the faulty `error` release tag:
```bash
./scripts/deploy.sh error
```
*Result: The deployment script begins upgrading the backend container. It polls the container health state, detects it remains `unhealthy` (due to the simulated HTTP 500 configuration), aborts the deployment, and immediately rolls back both services to the previous stable release (`1` / `7`) tags.*

---

## 🧪 Testing & Linting

### Unit & Integration Tests
Run the Express REST API Jest test suite:
```bash
cd backend
npm install
npm test
```

### Linting
Check code style rules with ESLint:
```bash
cd backend
npm run lint
```
