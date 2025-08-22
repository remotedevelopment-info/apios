def test_objects_crud(client):
    # Seed user, project, membership
    client.post("/users/register", json={"username": "owner", "password": "password8", "email": "o@example.com"})
    tok = client.post("/users/login", json={"username": "owner", "password": "password8"}).json()["access_token"]
    # Create project directly in DB via API constraints not implemented for projects
    from db.connection import get_connection
    with get_connection() as conn:
        owner_id = conn.execute("SELECT id FROM users WHERE username=?", ("owner",)).fetchone()[0]
        conn.execute("INSERT INTO projects (name, owner_id) VALUES (?, ?)", ("P1", owner_id))
        project_id = conn.execute("SELECT id FROM projects WHERE name=?", ("P1",)).fetchone()[0]
        conn.execute("INSERT OR IGNORE INTO projects_users (project_id, user_id, role) VALUES (?, ?, 'owner')", (project_id, owner_id))
        conn.commit()
    # Create object
    r = client.post("/objects", headers={"Authorization": f"Bearer {tok}"}, json={"name": "obj", "content": "c", "project_id": project_id, "metadata": {"k":"v"}})
    assert r.status_code == 200
    data = r.json()
    assert data["name"] == "obj"
    oid = data["id"]
    # Get object
    r = client.get(f"/objects/{oid}")
    assert r.status_code == 200
    assert any(m["key"] == "k" for m in r.json()["metadata"]) or any(m.get("key") == "k" for m in r.json()["metadata"])
