from fastapi import FastAPI, HTTPException, Depends, Header
from typing import List, Dict, Any, Optional
from db.sqlite import get_connection
from pydantic import BaseModel, Field
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from api.security import hash_password, verify_password, create_access_token, decode_token
import os

app = FastAPI(title="ApiOS API", version="0.3.0")

# Models
class ObjectCreate(BaseModel):
    name: str = Field(..., min_length=1)
    content: Optional[str] = None
    project_id: Optional[int] = None
    metadata: Optional[Dict[str, str]] = None

class MetadataCreate(BaseModel):
    object_id: int
    key: str
    value: str

class RelationCreate(BaseModel):
    subject_id: int
    predicate: str
    object_id: int

class UserRegister(BaseModel):
    username: str
    password: str
    email: Optional[str] = None

class UserLogin(BaseModel):
    username: str
    password: str

# Auth utils
bearer_scheme = HTTPBearer(auto_error=False)

def require_user(credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme)) -> Optional[str]:
    # Enforce auth only if a JWT secret is configured
    if not os.getenv("JWT_SECRET"):
        return None  # auth disabled
    if not credentials or not credentials.credentials:
        raise HTTPException(status_code=401, detail="Not authenticated")
    sub = decode_token(credentials.credentials)
    if not sub:
        raise HTTPException(status_code=401, detail="Invalid token")
    # Optional: verify user exists
    with get_connection() as conn:
        cur = conn.execute("SELECT id FROM users WHERE username=?", (sub,))
        if not cur.fetchone():
            raise HTTPException(status_code=401, detail="User not found")
    return sub

# Read endpoints
@app.get("/objects")
def list_objects() -> List[Dict[str, Any]]:
    with get_connection() as conn:
        cur = conn.execute("SELECT id, noun, adjectives, verbs, metadata, content, project_id FROM linguistic_objects ORDER BY id")
        rows = [dict(row) for row in cur.fetchall()]
    return rows

@app.get("/objects/{obj_id}")
def get_object(obj_id: int) -> Dict[str, Any]:
    with get_connection() as conn:
        cur = conn.execute("SELECT id, noun, adjectives, verbs, metadata, project_id, content FROM linguistic_objects WHERE id=?", (obj_id,))
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Object not found")
        obj = dict(row)
        mcur = conn.execute("SELECT key, value FROM metadata WHERE object_id=? ORDER BY key", (obj_id,))
        obj["metadata_entries"] = [dict(m) for m in mcur.fetchall()]
    return obj

@app.get("/projects/{project_id}/objects")
def list_project_objects(project_id: int) -> List[Dict[str, Any]]:
    with get_connection() as conn:
        cur = conn.execute(
            "SELECT id, noun, adjectives, verbs, metadata, content, project_id FROM linguistic_objects WHERE project_id=? ORDER BY id",
            (project_id,)
        )
        rows = [dict(row) for row in cur.fetchall()]
    return rows

# Auth endpoints
@app.post("/users/register")
def register_user(data: UserRegister) -> Dict[str, Any]:
    with get_connection() as conn:
        # enforce unique username/email
        cur = conn.execute("SELECT 1 FROM users WHERE username=?", (data.username,))
        if cur.fetchone():
            raise HTTPException(status_code=400, detail="Username already exists")
        if data.email:
            cur = conn.execute("SELECT 1 FROM users WHERE email=?", (data.email,))
            if cur.fetchone():
                raise HTTPException(status_code=400, detail="Email already exists")
        ph = hash_password(data.password)
        cur = conn.execute(
            "INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)",
            (data.username, data.email, ph)
        )
        uid = cur.lastrowid
        conn.commit()
        return {"id": uid, "username": data.username}

@app.post("/users/login")
def login_user(data: UserLogin) -> Dict[str, Any]:
    with get_connection() as conn:
        cur = conn.execute("SELECT username, password_hash FROM users WHERE username=?", (data.username,))
        row = cur.fetchone()
        if not row or not row["password_hash"] or not verify_password(data.password, row["password_hash"]):
            raise HTTPException(status_code=401, detail="Invalid credentials")
    token = create_access_token(sub=data.username)
    return {"access_token": token, "token_type": "bearer"}

# Write endpoints (authorization required if JWT_SECRET is set)
@app.post("/objects")
def create_object(payload: ObjectCreate, user: Optional[str] = Depends(require_user)) -> Dict[str, Any]:
    with get_connection() as conn:
        # Validate project if provided
        if payload.project_id is not None:
            cur = conn.execute("SELECT 1 FROM projects WHERE id=?", (payload.project_id,))
            if not cur.fetchone():
                raise HTTPException(status_code=422, detail="Invalid project_id")
        # Insert object: map name->noun
        cur = conn.execute(
            "INSERT INTO linguistic_objects (noun, content, project_id) VALUES (?, ?, ?)",
            (payload.name, payload.content, payload.project_id)
        )
        obj_id = cur.lastrowid
        # Insert metadata entries if provided
        if payload.metadata:
            for k, v in payload.metadata.items():
                conn.execute(
                    "INSERT OR IGNORE INTO metadata (key, value, object_id) VALUES (?, ?, ?)",
                    (k, v, obj_id)
                )
        conn.commit()
        return {
            "id": obj_id,
            "name": payload.name,
            "content": payload.content,
            "project_id": payload.project_id,
            "metadata": payload.metadata or {}
        }

@app.post("/metadata")
def create_metadata(item: MetadataCreate, user: Optional[str] = Depends(require_user)) -> Dict[str, Any]:
    with get_connection() as conn:
        cur = conn.execute("SELECT 1 FROM linguistic_objects WHERE id=?", (item.object_id,))
        if not cur.fetchone():
            raise HTTPException(status_code=422, detail="Invalid object_id")
        conn.execute(
            "INSERT OR IGNORE INTO metadata (key, value, object_id) VALUES (?, ?, ?)",
            (item.key, item.value, item.object_id)
        )
        conn.commit()
        return {"object_id": item.object_id, "key": item.key, "value": item.value}

@app.post("/relations")
def create_relation(rel: RelationCreate, user: Optional[str] = Depends(require_user)) -> Dict[str, Any]:
    with get_connection() as conn:
        cur = conn.execute("SELECT COUNT(*) AS c FROM linguistic_objects WHERE id IN (?, ?)", (rel.subject_id, rel.object_id))
        cnt = cur.fetchone()[0]
        if cnt != 2:
            raise HTTPException(status_code=422, detail="Invalid subject_id or object_id")
        conn.execute(
            "INSERT OR IGNORE INTO relations (subject_id, predicate, object_id) VALUES (?, ?, ?)",
            (rel.subject_id, rel.predicate, rel.object_id)
        )
        conn.commit()
        return {"subject_id": rel.subject_id, "predicate": rel.predicate, "object_id": rel.object_id}
