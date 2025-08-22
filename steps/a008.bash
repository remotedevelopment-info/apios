#!/usr/bin/env bash
# ACTION-008: Basic query layer
set -euo pipefail
export DOCKER_CLI_HINTS=false

DB="/data/apios.db"

echo "ACTION-008: Running basic queries"

printf "\n[Query] List all linguistic objects\n"
docker exec apios sqlite3 -header -column "$DB" "SELECT id, noun, adjectives, verbs FROM linguistic_objects ORDER BY id;"

printf "\n[Query] Metadata for object id=1\n"
docker exec apios sqlite3 -header -column "$DB" "SELECT m.key, m.value FROM metadata m WHERE m.object_id=1 ORDER BY m.key;"

printf "\n[Query] Relations (subject -> predicate -> object)\n"
docker exec apios sqlite3 -header -column "$DB" "SELECT s.id AS subject_id, s.noun AS subject, r.predicate, o.id AS object_id, o.noun AS object
FROM relations r
JOIN linguistic_objects s ON s.id=r.subject_id
JOIN linguistic_objects o ON o.id=r.object_id
ORDER BY r.id;"

echo "✅ ACTION-008 completed"
