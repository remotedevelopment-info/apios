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

## Objects

- GET /objects
  - List all objects.

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

## Projects

- GET /projects/{project_id}/objects
  - Returns objects scoped to a project.

Notes:
- JWT enforcement is active when env JWT_SECRET is provided to the API container.
- SQLite DB path: /data/apios.db (mounted read-only in API container).
