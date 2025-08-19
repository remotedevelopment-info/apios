from fastapi import FastAPI, HTTPException
from typing import List, Dict, Any
from db.sqlite import get_connection

app = FastAPI(title="ApiOS API", version="0.1.0")

@app.get("/objects")
def list_objects() -> List[Dict[str, Any]]:
    with get_connection() as conn:
        cur = conn.execute("SELECT id, noun, adjectives, verbs, metadata FROM linguistic_objects ORDER BY id")
        rows = [dict(row) for row in cur.fetchall()]
    # Optionally parse metadata JSON if present
    return rows

@app.get("/objects/{obj_id}")
def get_object(obj_id: int) -> Dict[str, Any]:
    with get_connection() as conn:
        cur = conn.execute("SELECT id, noun, adjectives, verbs, metadata FROM linguistic_objects WHERE id=?", (obj_id,))
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Object not found")
        obj = dict(row)
        mcur = conn.execute("SELECT key, value FROM metadata WHERE object_id=? ORDER BY key", (obj_id,))
        obj["metadata_entries"] = [dict(m) for m in mcur.fetchall()]
    return obj
