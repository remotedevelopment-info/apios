#!/usr/bin/env bash
# ACTION-007: Insert seed data
set -euo pipefail
export DOCKER_CLI_HINTS=false

DB="/data/apios.db"
FAIL=0

echo "ACTION-007: Seeding database"

# Ensure schema is in canonical form (noun/adjectives/verbs/metadata)
need_noun=$(docker exec apios sqlite3 "$DB" "SELECT 1 FROM pragma_table_info('linguistic_objects') WHERE name='noun' LIMIT 1;") || need_noun=""
if [[ -z "$need_noun" ]]; then
  echo "[FAIL] linguistic_objects schema not migrated (missing 'noun'). Run a006 first."; exit 1
fi

# Insert reproducible seed data (idempotent via UNIQUE and OR IGNORE)
docker exec -i apios bash -lc "sqlite3 '$DB' <<'SQL'
PRAGMA foreign_keys=ON;

-- Seed user
INSERT OR IGNORE INTO users (username, email) VALUES ('testuser', 'test@example.com');

-- Seed project owned by testuser
INSERT OR IGNORE INTO projects (name, owner_id)
SELECT 'Test Project', u.id FROM users u WHERE u.username='testuser';

-- Seed two linguistic objects
INSERT OR IGNORE INTO linguistic_objects (id, noun, adjectives, verbs, metadata) VALUES
  (1, 'alpha', 'quick,bright', 'run,leap', '{"source":"seed"}');
INSERT OR IGNORE INTO linguistic_objects (id, noun, adjectives, verbs, metadata) VALUES
  (2, 'beta', 'calm,blue', 'rest,flow', '{"source":"seed"}');

-- Seed metadata linked to objects (unique on key,object_id)
INSERT OR IGNORE INTO metadata (key, value, object_id) VALUES
  ('category', 'test', 1),
  ('category', 'test', 2),
  ('lang', 'en', 1);

-- Seed relation: alpha related-to beta
INSERT OR IGNORE INTO relations (subject_id, predicate, object_id) VALUES (1, 'related_to', 2);
SQL"

# Validations
users_ct=$(docker exec apios sqlite3 "$DB" "SELECT COUNT(*) FROM users;") || users_ct=0
projects_ct=$(docker exec apios sqlite3 "$DB" "SELECT COUNT(*) FROM projects;") || projects_ct=0
lo_ct=$(docker exec apios sqlite3 "$DB" "SELECT COUNT(*) FROM linguistic_objects;") || lo_ct=0
meta_ct=$(docker exec apios sqlite3 "$DB" "SELECT COUNT(*) FROM metadata;") || meta_ct=0
rel_ct=$(docker exec apios sqlite3 "$DB" "SELECT COUNT(*) FROM relations;") || rel_ct=0

printf "users=%s projects=%s linguistic_objects=%s metadata=%s relations=%s\n" "$users_ct" "$projects_ct" "$lo_ct" "$meta_ct" "$rel_ct"

if [[ $users_ct -ge 1 && $projects_ct -ge 1 && $lo_ct -ge 2 && $meta_ct -ge 2 && $rel_ct -ge 1 ]]; then
  echo "[OK] Seed data present"
else
  echo "[FAIL] Seed validation failed"; FAIL=1
fi

if [[ $FAIL -ne 0 ]]; then echo "❌ ACTION-007 failed"; exit 1; else echo "✅ ACTION-007 completed successfully"; fi
