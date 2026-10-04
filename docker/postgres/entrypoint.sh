#!/bin/sh

# Correct ownership and permissions for the data directory
if [ -d "/var/lib/postgresql/data" ]; then
    chown -R postgres:postgres /var/lib/postgresql/data
    chmod 700 /var/lib/postgresql/data
fi

# Start Patroni in background
su-exec postgres patroni /etc/patroni/patroni.yml &
PATRONI_PID=$!

# Wait for PostgreSQL to be ready (retry loop)
max_attempts=30
attempt=1
while ! pg_isready -h /var/run/postgresql -U postgres -t 1; do
  echo "Postgres not ready yet (attempt $attempt/$max_attempts)"
  if [ $attempt -ge $max_attempts ]; then
    echo "Postgres failed to become ready"
    kill $PATRONI_PID
    exit 1
  fi
  attempt=$((attempt+1))
  sleep 2
done

# Only run post_bootstrap if this node is the primary (not in recovery)
IS_RECOVERY=$(psql -h /var/run/postgresql -U postgres -d postgres -tAc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "t")
if [ "$IS_RECOVERY" = "f" ]; then
  echo "Running bootstrap for primary $PATRONI_NAME"
  su-exec postgres /usr/local/bin/post_bootstrap.sh
else
  echo "Node is standby replica or in recovery, skipping post_bootstrap"
fi

# Keep Patroni running
wait $PATRONI_PID
