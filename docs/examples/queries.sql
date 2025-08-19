-- Example queries for ApiOS (see ACTION-008)
-- Database: /data/apios.db

-- List all linguistic objects
SELECT id, noun, adjectives, verbs FROM linguistic_objects ORDER BY id;

-- Metadata for object id=1
SELECT m.key, m.value FROM metadata m WHERE m.object_id=1 ORDER BY m.key;

-- Relations (subject -> predicate -> object)
SELECT s.id AS subject_id, s.noun AS subject, r.predicate, o.id AS object_id, o.noun AS object
FROM relations r
JOIN linguistic_objects s ON s.id=r.subject_id
JOIN linguistic_objects o ON o.id=r.object_id
ORDER BY r.id;

-- Expected output will include rows seeded in ACTION-007.
