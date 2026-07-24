#!/bin/sh
set -e

# Wait for postgres to accept connections using Unix domain socket
pg_isready -h /var/run/postgresql -U postgres -t 30

# Create application user, database, and assign owner via Unix socket
psql -h /var/run/postgresql -U postgres -d postgres -c "CREATE USER ${DB_USERNAME} WITH PASSWORD '${DB_PASSWORD}';"
psql -h /var/run/postgresql -U postgres -d postgres -c "CREATE DATABASE ${POSTGRES_DB} OWNER ${DB_USERNAME};"
psql -h /var/run/postgresql -U postgres -d ${POSTGRES_DB} -c "GRANT ALL ON SCHEMA public TO ${DB_USERNAME};"
