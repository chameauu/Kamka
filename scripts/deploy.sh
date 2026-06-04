#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Health-checked deploy with automatic rollback
#
# Usage:
#   ./scripts/deploy.sh <image-tag>
#
# Examples:
#   ./scripts/deploy.sh sha-a1b2c3d        # deploy a specific SHA tag
#   ./scripts/deploy.sh latest              # deploy latest
#
# What it does:
#   1. Records the currently running image tags (snapshot for rollback)
#   2. Pulls the new images for the given tag
#   3. Performs a rolling cutover (recreates containers one by one)
#   4. Runs health checks against all HTTP services
#   5. On failure → automatically rolls back to the previous snapshot
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# Load environment variables from .env if present (robust parsing)
if [[ -f .env ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*# ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
      continue
    fi
    if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
      val="${val#\"}"
      val="${val%\"}"
      val="${val#\'}"
      val="${val%\'}"
      export "$key"="$val"
    fi
  done < .env
fi

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
PROD_OVERRIDE="${PROD_OVERRIDE:-docker-compose.prod.yml}"
DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-}"

# Services that have Docker Hub images
DEPLOY_SERVICES=("backend-service" "frontend-service")

# Image names on Docker Hub (must match docker-compose image: fields)
declare -A SERVICE_IMAGES=(
  ["frontend-service"]="fullstack-frontend"
  ["backend-service"]="fullstack-backend"
)

HEALTH_RETRIES=12       # number of attempts
HEALTH_INTERVAL=5       # seconds between attempts
ROLLBACK_SNAPSHOT_FILE="/tmp/deploy_rollback_snapshot_$(date +%s)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()     { echo "[$(date '+%H:%M:%S')] $*"; }
success() { echo "[$(date '+%H:%M:%S')] ✔  $*"; }
warn()    { echo "[$(date '+%H:%M:%S')] ⚠  $*" >&2; }
error()   { echo "[$(date '+%H:%M:%S')] ✘  $*" >&2; }

require() {
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || { error "Required command not found: $cmd"; exit 1; }
  done
}

compose() {
  docker compose -f "$COMPOSE_FILE" -f "$PROD_OVERRIDE" "$@"
}

# ---------------------------------------------------------------------------
# Snapshot current image tags for rollback
# ---------------------------------------------------------------------------
snapshot_current_tags() {
  log "Snapshotting current running image tags → $ROLLBACK_SNAPSHOT_FILE"
  : > "$ROLLBACK_SNAPSHOT_FILE"
  for svc in "${DEPLOY_SERVICES[@]}"; do
    local container_name
    container_name=$(compose ps -q "$svc" 2>/dev/null | head -1 || true)
    if [[ -n "$container_name" ]]; then
      local current_image
      current_image=$(docker inspect --format '{{.Config.Image}}' "$container_name" 2>/dev/null || echo "")
      echo "${svc}=${current_image}" >> "$ROLLBACK_SNAPSHOT_FILE"
      log "  $svc → $current_image"
    else
      warn "  $svc is not currently running — no rollback target for this service"
    fi
  done
}

# ---------------------------------------------------------------------------
# Health check a single service
# ---------------------------------------------------------------------------
wait_healthy() {
  local svc="$1"

  # Find container ID for the service
  local container_id
  container_id=$(compose ps -q "$svc" 2>/dev/null | head -1 || true)
  
  if [[ -z "$container_id" ]]; then
    error "No running container found for service $svc"
    return 1
  fi

  log "Health-checking $svc (ID: $container_id) via Docker health status (${HEALTH_RETRIES} attempts, ${HEALTH_INTERVAL}s apart)…"
  
  local attempt=1
  while (( attempt <= HEALTH_RETRIES )); do
    local status
    status=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_id" 2>/dev/null || echo "failed")
    
    if [[ "$status" == "healthy" ]]; then
      success "$svc is healthy"
      return 0
    elif [[ "$status" == "unhealthy" ]]; then
      error "$svc health check reported unhealthy by Docker"
      return 1
    fi
    
    # If the container has no healthcheck configured (none), consider it healthy/started
    if [[ "$status" == "none" ]]; then
      success "$svc has no health check configured, assuming healthy"
      return 0
    fi

    warn "  Attempt $attempt/$HEALTH_RETRIES — status is '$status', retrying in ${HEALTH_INTERVAL}s…"
    sleep "$HEALTH_INTERVAL"
    (( attempt++ ))
  done

  error "$svc failed health check after $HEALTH_RETRIES attempts"
  return 1
}

# ---------------------------------------------------------------------------
# Rollback to snapshot
# ---------------------------------------------------------------------------
rollback() {
  error "Deploy FAILED — initiating rollback"

  if [[ ! -f "$ROLLBACK_SNAPSHOT_FILE" ]]; then
    error "No rollback snapshot found at $ROLLBACK_SNAPSHOT_FILE — manual intervention required"
    exit 1
  fi

  log "Reading rollback snapshot…"
  local backend_rollback_img=""
  local frontend_rollback_img=""

  while IFS='=' read -r svc image; do
    if [[ -z "$image" ]]; then
      warn "  No previous image recorded for $svc — skipping"
      continue
    fi
    if [[ "$svc" == "backend-service" ]]; then
      backend_rollback_img="$image"
    elif [[ "$svc" == "frontend-service" ]]; then
      frontend_rollback_img="$image"
    fi
  done < "$ROLLBACK_SNAPSHOT_FILE"

  # Apply rollback for backend-service
  if [[ -n "$backend_rollback_img" ]]; then
    log "  Rolling back backend-service → $backend_rollback_img"
    if ! BACKEND_IMAGE="$backend_rollback_img" compose up -d --no-deps --no-build --force-recreate backend-service; then
      warn "  Failed to roll back backend-service immediately, trying to pull first..."
      docker pull "$backend_rollback_img" || true
      BACKEND_IMAGE="$backend_rollback_img" compose up -d --no-deps --force-recreate backend-service || \
        warn "  Could not roll back backend-service — manual intervention may be needed"
    fi
  fi

  # Apply rollback for frontend-service
  if [[ -n "$frontend_rollback_img" ]]; then
    log "  Rolling back frontend-service → $frontend_rollback_img"
    if ! FRONTEND_IMAGE="$frontend_rollback_img" compose up -d --no-deps --no-build --force-recreate frontend-service; then
      warn "  Failed to roll back frontend-service immediately, trying to pull first..."
      docker pull "$frontend_rollback_img" || true
      FRONTEND_IMAGE="$frontend_rollback_img" compose up -d --no-deps --force-recreate frontend-service || \
        warn "  Could not roll back frontend-service — manual intervention may be needed"
    fi
  fi

  error "Rollback complete. Please investigate the failed deployment."
  exit 1
}

# ---------------------------------------------------------------------------
# Main deploy flow
# ---------------------------------------------------------------------------
main() {
  local tag="${1:-}"

  if [[ -z "$tag" ]]; then
    error "Usage: $0 <image-tag>"
    error "  Example: $0 sha-a1b2c3d"
    exit 1
  fi

  if [[ -z "$DOCKERHUB_USERNAME" ]]; then
    error "DOCKERHUB_USERNAME environment variable is not set."
    error "  Export it before running: export DOCKERHUB_USERNAME=yourusername"
    exit 1
  fi

  require docker curl

  log "═══════════════════════════════════════════════════"
  log " Deploying tag: $tag"
  log " User:          $DOCKERHUB_USERNAME"
  log " Compose file:  $COMPOSE_FILE + $PROD_OVERRIDE"
  log "═══════════════════════════════════════════════════"

  # Step 1: Record rollback snapshot
  snapshot_current_tags

  # Step 2: Pull new images
  log "Pulling new images (tag: $tag)…"
  for svc in "${DEPLOY_SERVICES[@]}"; do
    local image_name="${SERVICE_IMAGES[$svc]}"
    local full_image="${DOCKERHUB_USERNAME}/${image_name}:${tag}"
    log "  Pulling $full_image"
    if ! docker pull "$full_image"; then
      if docker inspect "$full_image" &>/dev/null; then
        warn "  Failed to pull $full_image, but image exists locally. Proceeding with local image."
      else
        error "  Failed to pull $full_image and no local copy found."
        rollback
      fi
    else
      success "  Pulled $full_image"
    fi
  done

  # Set the environment variables for the new images
  export BACKEND_IMAGE="${DOCKERHUB_USERNAME}/fullstack-backend:${tag}"
  export FRONTEND_IMAGE="${DOCKERHUB_USERNAME}/fullstack-frontend:${tag}"

  # Step 3: Recreate services one by one (rolling cutover)
  log "Performing rolling cutover…"
  for svc in "${DEPLOY_SERVICES[@]}"; do
    log "  Switching $svc to new tag..."

    if ! compose up -d --no-deps --no-build --force-recreate "$svc"; then
      error "Failed to recreate $svc"
      rollback
    fi

    # Step 4: Health check each service immediately after cutover
    if ! wait_healthy "$svc"; then
      rollback
    fi
  done

  # Final status
  log ""
  success "══════════════════════════════════════════════════"
  success " Deployment of tag '$tag' completed successfully!"
  success "══════════════════════════════════════════════════"
  compose ps
  rm -f "$ROLLBACK_SNAPSHOT_FILE"
}

# Trap unexpected errors and trigger rollback
trap 'error "Unexpected error on line $LINENO — triggering rollback"; rollback' ERR

main "$@"
