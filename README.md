# Database Horizontal Scaling with NestJS, TypeORM, PgBouncer, HAProxy, and PostgreSQL Replication

This project details the setup of a horizontally scaled PostgreSQL database architecture (Primary/Replica) with PgBouncer connection poolers, HAProxy load balancer routing, and a dockerized NestJS application using TypeORM replication.

---

## 🏗️ Architecture Diagram

The system consists of the following components:

![Architecture Diagram](./src/assets/hydradb.drawio.svg)

---

## 🛠️ Key Components & Design

1. **PostgreSQL Replication**:
   - `pg_primary` streams Write-Ahead Logs (WAL) to `pg_replica`.
   - `pg_replica` operates in Hot Standby mode (read-only queries).
2. **PgBouncer**:
   - Manages connection pools for both database instances independently using `transaction` pooling mode to prevent database connection exhaustion.
3. **HAProxy**:
   - Exposes port `5432` for write traffic (routing to primary PgBouncer).
   - Exposes port `5433` for read traffic (routing to replica PgBouncer).
4. **TypeORM Replication**:
   - TypeORM is configured with a replication connection provider. All `save`, `update`, `delete`, and transaction queries are routed to `HAProxy:5432`. All `find` and `select` queries are routed to `HAProxy:5433`.

---

## 🚀 Setup & Execution

### Prerequisites
- Docker Desktop / Daemon running
- Node.js & Yarn (for local workspace packages)

### 1. Project Dependencies Installation (Local)
Install the dependencies in your local development environment:
```bash
yarn install
```

### 2. Startup Infrastructure
Start all services in detached mode:
```bash
docker compose up --build -d
```
This spins up:
- PostgreSQL primary database (`pg_primary`)
- PostgreSQL replica database (`pg_replica`)
- PgBouncer for primary (`pgbouncer_primary`)
- PgBouncer for replica (`pgbouncer_replica`)
- HAProxy load balancer (`haproxy`)
- NestJS application (`app`)
Connected through a custom bridge network `hydra_net`.

---

## 🧪 Verification & Testing

### 1. Check Service Health
Confirm that all containers are healthy:
```bash
docker compose ps
```

### 2. Verify Database Replication
Log into `pg_primary` to see active replication connections:
```bash
docker compose exec pg_primary psql -U postgres -d hydra_db -c "SELECT * FROM pg_stat_replication;"
```

### 3. Test API Endpoints

- **Perform a Write (routes to Master/Primary):**
  ```bash
  curl -X POST http://localhost:3000/users \
       -H "Content-Type: application/json" \
       -d '{"name": "Hydra", "email": "hydra@example.com"}'
  ```

- **Perform a Read (routes to Slave/Replica):**
  ```bash
  curl http://localhost:3000/users
  ```

- **Check Connection Info Routing:**
  Query the endpoint that explicitly compares active connections:
  ```bash
  curl http://localhost:3000/users/db-info
  ```
  This endpoint will return verification of routing, where the read connection has `is_replica: true` and the write connection has `is_replica: false`.

---

## 📜 License
Nest is [MIT licensed](LICENSE).
