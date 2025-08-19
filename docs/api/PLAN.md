# ApiOS API Plan (FastAPI)

Goal: Provide a minimal REST API to read data from the SQLite backend at `/data/apios.db`.

Language/Framework: Python 3 + FastAPI + Uvicorn

Directory Layout:

- src/
  - api/
    - main.py        # FastAPI app, routers
  - db/
    - sqlite.py      # DB connection wrapper
- api/
  - Dockerfile       # API container Dockerfile

Dependencies:
- fastapi
- uvicorn[standard]

Runtime assumptions:
- API container mounts host `./data` to container `/data`.
- DB path defaults to `/data/apios.db` and can be overridden via env `APISQLITE_DB_PATH`.

Endpoints (MVP):
- GET /objects
  - Returns list of linguistic objects: id, noun, adjectives, verbs, metadata (as JSON string if present).
- GET /objects/{id}
  - Returns a single object by id and its associated metadata entries as an array of key/value pairs.

Container Runtime:
- The container will listen on port 8000 (exposed externally via host mapping, e.g., 8080->8000).
- Example run: `docker run -d --name apios-api --network apios-net -p 8080:8000 -v ./data:/data apios-api:latest`

Non-goals (for MVP):
- Write operations (create/update/delete)
- AuthN/AuthZ

Next Steps (post-MVP):
- Add filters, pagination, and project/user endpoints.
- Add health checks and OpenAPI docs exposure.
