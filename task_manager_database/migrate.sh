#!/bin/bash
set -euo pipefail

DB_NAME="myapp"
DB_USER="appuser"
DB_PASSWORD="dbuser123"
DB_PORT="5000"

# Find PostgreSQL version and set paths
PG_VERSION=$(ls /usr/lib/postgresql/ | head -1)
PG_BIN="/usr/lib/postgresql/${PG_VERSION}/bin"

echo "Running DB migrations (schema.sql) against ${DB_NAME} on port ${DB_PORT}..."

# Wait until postgres is ready
for i in {1..30}; do
  if sudo -u postgres "${PG_BIN}/pg_isready" -p "${DB_PORT}" > /dev/null 2>&1; then
    break
  fi
  echo "Waiting for PostgreSQL... ($i/30)"
  sleep 1
done

if ! sudo -u postgres "${PG_BIN}/pg_isready" -p "${DB_PORT}" > /dev/null 2>&1; then
  echo "PostgreSQL is not ready on port ${DB_PORT}; cannot run migrations."
  exit 1
fi

# Apply schema as app user (ensures permissions are correct for normal operation)
# Note: PGPASSWORD is used only for this command invocation.
PGPASSWORD="${DB_PASSWORD}" "${PG_BIN}/psql" \
  -h localhost -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
  -v ON_ERROR_STOP=1 \
  -f "$(dirname "$0")/schema.sql"

echo "✓ Migrations applied successfully."
