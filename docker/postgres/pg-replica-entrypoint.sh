#!/bin/bash
set -e

# The pg_basebackup requires the directory to be empty.
# We check if PGDATA has a PG_VERSION file.
if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "Replica data directory is empty. Initializing replica from primary..."
  
  # Clear out the directory if there are any default/dangling files
  rm -rf "$PGDATA"/*

  # Loop until pg_basebackup is successful
  export PGPASSWORD="$REPLICATION_PASSWORD"
  until pg_basebackup -h pg_primary -D "$PGDATA" -U "$REPLICATION_USER" -v -P -R -X stream; do
    echo "Waiting for primary database ($REPLICATION_USER@pg_primary) to start and replicate..."
    sleep 2
  done
  
  echo "Replication base backup completed successfully."
  chmod 700 "$PGDATA"
fi

# Hand over execution to the official postgres entrypoint script
exec docker-entrypoint.sh "$@"
