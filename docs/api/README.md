# ApiOS API

Base URL: http://localhost:8080

Authentication: JWT (Bearer). Obtain via POST /users/login after registering.

## Auth

- POST /users/register
  - Body: { username, password, email? }
  - Response: { id, username }

- POST /users/login
  - Body: { username, password }
  - Response: { access_token, token_type: "bearer" }

- POST /users/refresh
  - Response: { access_token, token_type: "bearer" }

## New Endpoints

- GET /ready: readiness (DB + migrations applied)
- GET /metrics: basic counters

## Objects

- GET /objects
  - List all objects.
  - Supports pagination: `?limit=50&offset=0`
  - Filters: `?project_id=1`, `?meta_key=stage`, `?include_deleted=1`
  - Response shape alignment: { id, name, content, created_at, updated_at, metadata? }

- GET /objects/{id}
  - Single object with metadata_entries.

- POST /objects (auth required when JWT_SECRET is set)
  - Body: { name: string, content?: string, project_id?: int, metadata?: { [key]: value } }
  - Response: { id, name, content, project_id, metadata }

## Metadata

- POST /metadata (auth required)
  - Body: { object_id, key, value }
  - Response: { object_id, key, value }

## Relations

- POST /relations (auth required)
  - Body: { subject_id, predicate, object_id }
  - Response: { subject_id, predicate, object_id }

- Response shape: { from_id, to_id, type }

## Projects

- GET /projects/{project_id}/objects
  - Returns objects scoped to a project.

## Authorization

- Only project owners can POST /objects to a project.
- Project members can GET /projects/{id}/objects when JWT is enabled.

Notes:
- JWT enforcement is active when env JWT_SECRET is provided to the API container.
- SQLite DB path: /data/apios.db (mounted read-write in API container to support WAL and write endpoints).
