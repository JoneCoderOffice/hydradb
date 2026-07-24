#!/bin/sh
set -e

# Correct ownership and permissions for the data directory
if [ -d "/var/lib/postgresql/data" ]; then
    chown -R postgres:postgres /var/lib/postgresql/data
    chmod 700 /var/lib/postgresql/data
fi

# Export the actual container hostname to Patroni connect address variables
export PATRONI_RESTAPI_CONNECT_ADDRESS="${HOSTNAME}:8008"
export PATRONI_POSTGRESQL_CONNECT_ADDRESS="${HOSTNAME}:5432"

# If PATRONI_NAME is not set, dynamically set it to be unique based on hostname
if [ -z "$PATRONI_NAME" ]; then
    export PATRONI_NAME="pg_node_${HOSTNAME}"
fi

# Step down to postgres user and run Patroni
exec su-exec postgres patroni /etc/patroni/patroni.yml
