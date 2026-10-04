#!/bin/sh
set -e

# Wait for PostgreSQL to accept connections (retry loop)
max_attempts=30
attempt=1
while ! pg_isready -h /var/run/postgresql -U postgres -t 1; do
  echo "Postgres not ready yet (attempt $attempt/$max_attempts)"
  if [ $attempt -ge $max_attempts ]; then
    echo "Postgres failed to become ready after $max_attempts attempts"
    exit 1
  fi
  attempt=$((attempt + 1))
  sleep 2
done

echo "Postgres is ready, checking node replication status..."
IS_RECOVERY=$(psql -h /var/run/postgresql -U postgres -d postgres -tAc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "t")
if [ "$IS_RECOVERY" = "t" ]; then
  echo "Node is standby replica (read-only). Skipping bootstrap."
  exit 0
fi

echo "Node is primary. Proceeding with idempotent bootstrap..."

# 1. Create application user if not exists
psql -h /var/run/postgresql -U postgres -d postgres -c "
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USERNAME}') THEN
    CREATE USER ${DB_USERNAME} WITH PASSWORD '${DB_PASSWORD}';
  ELSE
    ALTER USER ${DB_USERNAME} WITH PASSWORD '${DB_PASSWORD}';
  END IF;
END
\$\$;"

# 2. Create database if not exists
DB_EXISTS=$(psql -h /var/run/postgresql -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '${POSTGRES_DB}';" 2>/dev/null || echo "")
if [ "$DB_EXISTS" != "1" ]; then
  psql -h /var/run/postgresql -U postgres -d postgres -c "CREATE DATABASE ${POSTGRES_DB} OWNER ${DB_USERNAME};"
fi

# 3. Grant schema permissions
psql -h /var/run/postgresql -U postgres -d ${POSTGRES_DB} -c "GRANT ALL ON SCHEMA public TO ${DB_USERNAME};"

echo "Bootstrap completed successfully."
