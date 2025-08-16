# ApiOS Deployment Guide

This guide explains the recommended ways to deploy **ApiOS**, whether you are running a single server or scaling across multiple nodes. ApiOS supports both **native Linux installation** and **containerized deployment**.

---

## **1. Native Linux Deployment (Ubuntu example)**

**Use case:** Single-server deployments where performance and minimal overhead are priorities.  

**Steps:**

1. Install dependencies:
   - Python 3.11
   - Go 1.20+
   - pip packages: `pymongo`, `fastapi`, `uvicorn`
   - MongoDB, SQLite

2. Clone the ApiOS repo:

```bash
git clone https://github.com/YOUR_USERNAME/ApiOS.git
cd ApiOS
````

3. Initialize the environment:

```bash
python3 scripts/init_system.py
```

4. Run daemons manually or via systemd:

```bash
python3 src/linguistic_analysis.py
python3 src/library_evolution.py
python3/src/user_dashboard.py
```

5. Optional: Use Nginx or a reverse proxy to expose dashboard endpoints.

**Diagram (single-server native deployment):**

```
+------------------+
| Ubuntu Server    |
|                  |
|  +------------+  |
|  | Daemons    |  |
|  | - Linguistic Analysis
|  | - Library Evolution
|  | - User Dashboard
|  +------------+  |
|  +------------+  |
|  | MongoDB/SQLite
|  +------------+  |
+------------------+
```

**Pros:** Low overhead, simple, easier debugging
**Cons:** Must manually manage dependencies and environment consistency

---

## **2. Containerized Deployment**

**Use case:** Development parity, multi-daemon isolation, scaling, or experimental setups.

**Steps:**

1. Build and start containers with Docker Compose:

```bash
docker compose build
docker compose up -d
```

2. Access the ApiOS container:

```bash
docker exec -it apios bash
```

3. Daemons run inside the container, communicating via UNIX sockets or mounted volumes.
4. MongoDB and SQLite can also be containerized or kept native — adjust volumes accordingly.

**Diagram (containerized deployment):**

```
+-------------------------+
| Host OS (Ubuntu)        |
|                         |
| +-------------------+   |
| | Docker Containers |   |
| |                   |   |
| | +---------------+ |   |
| | | ApiOS Daemons | |   |
| | +---------------+ |   |
| | +---------------+ |   |
| | | MongoDB       | |   |
| | +---------------+ |   |
| | +---------------+ |   |
| | | SQLite        | |   |
| | +---------------+ |   |
| +-------------------+   |
+-------------------------+
```

**Pros:** Reproducible environments, easy upgrades and rollback, ready for orchestration
**Cons:** Slight resource overhead, careful volume/data management required

---

## **Recommendation**

* Start with **native Linux deployment** for simplicity and testing.
* Use **containerized deployment** for development, experimentation, or multi-node scaling.
* Hybrid approach is possible: run core daemons natively while containerizing MongoDB or optional LLM services.

---

> Both deployment methods are supported and fully compatible with v0.1.x. Choose the one that best fits your workflow and environment.

```
