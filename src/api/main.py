from fastapi import FastAPI, HTTPException, Depends
from fastapi import Request
from typing import List, Dict, Any, Optional
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from api.security import hash_password, verify_password, create_access_token, decode_token
import os
import time

from db.connection import get_connection

app = FastAPI(title="ApiOS API", version="0.4.2")

# Health and readiness
@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/ready")
def ready():
    try:
        with get_connection() as conn:
            # Migrations table existence is sufficient for now
            conn.execute("CREATE TABLE IF NOT EXISTS migrations (version TEXT PRIMARY KEY);")
        return {"status": "ready", "migrations_ok": True}
    except Exception:
        return {"status": "not_ready", "migrations_ok": False}

# Simple in-process metrics
_metrics = {"requests": 0, "errors": 0}

@app.get("/metrics")
def metrics():
    return _metrics

# Models
from pydantic import BaseModel, Field
from pydantic import field_validator

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

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v

class UserLogin(BaseModel):
    username: str
    password: str

# Auth utils
bearer_scheme = HTTPBearer(auto_error=False)

def require_user(credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme)) -> Optional[str]:
    if not os.getenv("JWT_SECRET"):
        return None
    if not credentials or not credentials.credentials:
        raise HTTPException(status_code=401, detail={"error": {"code": "not_authenticated", "message": "Not authenticated"}})
    sub = decode_token(credentials.credentials)
    if not sub:
        raise HTTPException(status_code=401, detail={"error": {"code": "invalid_token", "message": "Invalid token"}})
    with get_connection() as conn:
        cur = conn.execute("SELECT id FROM users WHERE username=?", (sub,))
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=401, detail={"error": {"code": "user_not_found", "message": "User not found"}})
    return sub

# Helper to standardize rows to response shape

def _object_row_to_dict(row: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "id": row["id"],
        "name": row.get("noun") or row.get("name") or None,
        "content": row.get("content"),
        # created_at/updated_at may not exist pre-migration
        "created_at": row.get("created_at") if isinstance(row, dict) else None,
        "updated_at": row.get("updated_at") if isinstance(row, dict) else None,
    }

# Read endpoints
@app.get("/objects")
def list_objects(request: Request, limit: int = 50, offset: int = 0, project_id: Optional[int] = None, meta_key: Optional[str] = None):
    _metrics["requests"] += 1
    where = ["1=1"]
    params: List[Any] = []
    if project_id is not None:
        where.append("project_id=?")
        params.append(project_id)
    base_sql = f"SELECT id, noun, content FROM linguistic_objects WHERE {' AND '.join(where)} ORDER BY id LIMIT ? OFFSET ?"
    with get_connection() as conn:
        if meta_key:
            # Filter objects that have a metadata key
            sql = f"SELECT lo.id, lo.noun, lo.content FROM linguistic_objects lo JOIN metadata m ON m.object_id=lo.id WHERE {' AND '.join(where).replace('project_id','lo.project_id')} AND m.key=? GROUP BY lo.id ORDER BY lo.id LIMIT ? OFFSET ?"
            cur = conn.execute(sql, params + [meta_key, limit, offset])
        else:
            cur = conn.execute(base_sql, params + [limit, offset])
        rows = [ _object_row_to_dict(dict(r)) for r in cur.fetchall() ]
    qp = request.query_params
    wrap = ("wrap" in qp) or ("limit" in qp) or ("offset" in qp) or ("meta_key" in qp) or ("project_id" in qp)
    if wrap:
        return {"items": rows, "limit": limit, "offset": offset}
    return rows

@app.get("/objects/{obj_id}")
def get_object(obj_id: int) -> Dict[str, Any]:
    _metrics["requests"] += 1
    with get_connection() as conn:
        cur = conn.execute("SELECT id, noun, content FROM linguistic_objects WHERE id=?", (obj_id,))
        row = cur.fetchone()
        if not row:
            _metrics["errors"] += 1
            raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Object not found"}})
        obj = _object_row_to_dict(dict(row))
        mcur = conn.execute("SELECT key, value FROM metadata WHERE object_id=? ORDER BY key", (obj_id,))
        entries = [dict(m) for m in mcur.fetchall()]
        obj["metadata_entries"] = entries
        obj["metadata"] = entries
    return obj

@app.get("/projects/{project_id}/objects")
def list_project_objects(project_id: int, credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme)) -> Dict[str, Any]:
    _metrics["requests"] += 1
    # Optional authorization: enforce membership if JWT is configured and a token is provided
    if os.getenv("JWT_SECRET") and credentials and credentials.credentials:
        sub = decode_token(credentials.credentials)
        if not sub:
            raise HTTPException(status_code=401, detail={"error": {"code": "invalid_token", "message": "Invalid token"}})
        with get_connection() as conn:
            cur = conn.execute("SELECT u.id FROM users u WHERE u.username=?", (sub,))
            urow = cur.fetchone()
            if not urow:
                raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "No access"}})
            uid = urow[0]
            # Owner or member allowed to read
            cur = conn.execute("SELECT 1 FROM projects WHERE id=? AND owner_id=?", (project_id, uid))
            if not cur.fetchone():
                cur = conn.execute("SELECT 1 FROM projects_users WHERE project_id=? AND user_id=?", (project_id, uid))
                if not cur.fetchone():
                    raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "Not a project member"}})
    with get_connection() as conn:
        cur = conn.execute("SELECT id, noun, content FROM linguistic_objects WHERE project_id=? ORDER BY id", (project_id,))
        rows = [ _object_row_to_dict(dict(r)) for r in cur.fetchall() ]
    return {"items": rows}

# Auth endpoints
@app.post("/users/register")
def register_user(data: UserRegister) -> Dict[str, Any]:
    with get_connection() as conn:
        cur = conn.execute("SELECT 1 FROM users WHERE username=?", (data.username,))
        if cur.fetchone():
            raise HTTPException(status_code=400, detail={"error": {"code": "username_exists", "message": "Username already exists"}})
        if data.email:
            cur = conn.execute("SELECT 1 FROM users WHERE email=?", (data.email,))
            if cur.fetchone():
                raise HTTPException(status_code=400, detail={"error": {"code": "email_exists", "message": "Email already exists"}})
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
            raise HTTPException(status_code=401, detail={"error": {"code": "invalid_credentials", "message": "Invalid credentials"}})
    access = create_access_token(sub=data.username, expires_minutes=int(os.getenv("JWT_ACCESS_MINUTES", "15")))
    refresh = create_access_token(sub=data.username, expires_minutes=int(os.getenv("JWT_REFRESH_MINUTES", "43200")))  # 30 days
    return {"access_token": access, "refresh_token": refresh, "token_type": "bearer"}

@app.post("/users/refresh")
def refresh_token(payload: Dict[str, str]) -> Dict[str, Any]:
    token = payload.get("refresh_token")
    if not token:
        raise HTTPException(status_code=400, detail={"error": {"code": "bad_request", "message": "Missing refresh_token"}})
    sub = decode_token(token)
    if not sub:
        raise HTTPException(status_code=401, detail={"error": {"code": "invalid_token", "message": "Invalid refresh token"}})
    access = create_access_token(sub=sub, expires_minutes=int(os.getenv("JWT_ACCESS_MINUTES", "15")))
    return {"access_token": access, "token_type": "bearer"}

# Write endpoints (authorization required if JWT_SECRET is set)
@app.post("/objects")
def create_object(payload: ObjectCreate, user: Optional[str] = Depends(require_user)) -> Dict[str, Any]:
    with get_connection() as conn:
        # Authorization: if project_id provided and JWT enabled, only project owners can add
        if os.getenv("JWT_SECRET") and payload.project_id is not None and user is not None:
            # find user id
            cur = conn.execute("SELECT id FROM users WHERE username=?", (user,))
            urow = cur.fetchone()
            if not urow:
                raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "User not found"}})
            uid = urow[0]
            # Owner via projects.owner_id or projects_users role 'owner'
            is_owner = False
            cur = conn.execute("SELECT 1 FROM projects WHERE id=? AND owner_id=?", (payload.project_id, uid))
            if cur.fetchone():
                is_owner = True
            else:
                cur = conn.execute("SELECT role FROM projects_users WHERE project_id=? AND user_id=?", (payload.project_id, uid))
                prow = cur.fetchone()
                if prow and prow[0] == "owner":
                    is_owner = True
            if not is_owner:
                raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "Only owners can add objects"}})
        # Validate project if provided
        if payload.project_id is not None:
            cur = conn.execute("SELECT 1 FROM projects WHERE id=?", (payload.project_id,))
            if not cur.fetchone():
                raise HTTPException(status_code=422, detail={"error": {"code": "invalid_project", "message": "Invalid project_id"}})
        # Insert object
        cur = conn.execute(
            "INSERT INTO linguistic_objects (noun, content) VALUES (?, ?)",
            (payload.name, payload.content)
        )
        obj_id = cur.lastrowid
        if payload.project_id is not None:
            conn.execute("UPDATE linguistic_objects SET project_id=? WHERE id=?", (payload.project_id, obj_id))
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
            "created_at": None,
            "updated_at": None,
            "metadata": [{"key": k, "value": v} for k, v in (payload.metadata or {}).items()]
        }

@app.post("/metadata")
def create_metadata(item: MetadataCreate, user: Optional[str] = Depends(require_user)) -> Dict[str, Any]:
    with get_connection() as conn:
        cur = conn.execute("SELECT 1 FROM linguistic_objects WHERE id=?", (item.object_id,))
        if not cur.fetchone():
            raise HTTPException(status_code=422, detail={"error": {"code": "invalid_object", "message": "Invalid object_id"}})
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
            raise HTTPException(status_code=422, detail={"error": {"code": "invalid_input", "message": "Invalid subject_id or object_id"}})
        conn.execute(
            "INSERT OR IGNORE INTO relations (subject_id, predicate, object_id) VALUES (?, ?, ?)",
            (rel.subject_id, rel.predicate, rel.object_id)
        )
        conn.commit()
        return {"from_id": rel.subject_id, "predicate": rel.predicate, "type": rel.predicate, "to_id": rel.object_id}
