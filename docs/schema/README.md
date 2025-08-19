# ApiOS SQLite Schema

This document describes the core schema used by ApiOS.

Canonical database path: `/data/apios.db` (bind-mounted from `./data/apios.db`).

Tables added in ACTION-006:

- users
  - id INTEGER PRIMARY KEY AUTOINCREMENT
  - username TEXT UNIQUE NOT NULL
  - email TEXT UNIQUE NOT NULL
  - password_hash TEXT  (ACTION-012)
  - created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP

- projects
  - id INTEGER PRIMARY KEY AUTOINCREMENT
  - name TEXT UNIQUE NOT NULL
  - owner_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE
  - created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP

- metadata
  - id INTEGER PRIMARY KEY AUTOINCREMENT
  - key TEXT NOT NULL
  - value TEXT
  - object_id INTEGER NOT NULL REFERENCES linguistic_objects(id) ON DELETE CASCADE
  - UNIQUE(key, object_id)

- relations
  - id INTEGER PRIMARY KEY AUTOINCREMENT
  - subject_id INTEGER NOT NULL REFERENCES linguistic_objects(id)
  - predicate TEXT NOT NULL
  - object_id INTEGER NOT NULL REFERENCES linguistic_objects(id)
  - created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  - UNIQUE(subject_id, predicate, object_id)

Existing table (from earlier actions):

- linguistic_objects
  - id INTEGER PRIMARY KEY AUTOINCREMENT
  - noun TEXT
  - adjectives TEXT
  - verbs TEXT
  - content TEXT (ACTION-011)
  - metadata TEXT
  - project_id INTEGER (nullable) (ACTION-011)

Notes:
- Foreign keys are enforced per-connection via `PRAGMA foreign_keys=ON;` in code.
- WAL mode and `synchronous=NORMAL` configured for better read concurrency.
- Helpful indexes exist on metadata.object_id, projects.owner_id, relations subject/object ids, and linguistic_objects.project_id.

ERD (simplified):

users (1)───<(owner_id) projects

linguistic_objects (1)───<(object_id) metadata

linguistic_objects (1)───<(subject_id) relations >───(object_id) linguistic_objects

projects (1)───<(project_id) linguistic_objects

This schema supports storing linguistic objects, attaching arbitrary key/value metadata, modeling relationships between objects, and scoping objects under projects. Projects are owned by users. Foreign keys for newly added columns are checked in application logic on insert.
