#!/bin/bash
set -e

echo "Setting up replication and application users on Primary..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER $REPLICATION_USER WITH REPLICATION ENCRYPTED PASSWORD '$REPLICATION_PASSWORD';
    CREATE USER $DB_USERNAME WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
    GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $DB_USERNAME;
    GRANT ALL ON SCHEMA public TO $DB_USERNAME;
EOSQL

# Allow replication connections from any host using password authentication
echo "host replication $REPLICATION_USER 0.0.0.0/0 scram-sha-256" >> "$PGDATA/pg_hba.conf"

echo "Replication user and application user created successfully."
