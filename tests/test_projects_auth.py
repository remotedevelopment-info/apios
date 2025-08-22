def test_project_member_read_only(client):
    # Owner and member
    client.post("/users/register", json={"username": "own", "password": "password8", "email": "own@example.com"})
    client.post("/users/register", json={"username": "mem", "password": "password8", "email": "mem@example.com"})
    own_tok = client.post("/users/login", json={"username": "own", "password": "password8"}).json()["access_token"]
    # Create project and membership
    from db.connection import get_connection
    with get_connection() as conn:
        owner_id = conn.execute("SELECT id FROM users WHERE username=?", ("own",)).fetchone()[0]
        member_id = conn.execute("SELECT id FROM users WHERE username=?", ("mem",)).fetchone()[0]
        conn.execute("INSERT INTO projects (name, owner_id) VALUES (?, ?)", ("P2", owner_id))
        project_id = conn.execute("SELECT id FROM projects WHERE name=?", ("P2",)).fetchone()[0]
        conn.execute("INSERT OR IGNORE INTO projects_users (project_id, user_id, role) VALUES (?, ?, 'owner')", (project_id, owner_id))
        conn.execute("INSERT OR IGNORE INTO projects_users (project_id, user_id, role) VALUES (?, ?, 'member')", (project_id, member_id))
        conn.commit()
    # Owner can create object
    r = client.post("/objects", headers={"Authorization": f"Bearer {own_tok}"}, json={"name": "o", "content": "c", "project_id": project_id})
    assert r.status_code == 200
    # Member can read
    mem_tok = client.post("/users/login", json={"username": "mem", "password": "password8"}).json()["access_token"]
    r2 = client.get(f"/projects/{project_id}/objects", headers={"Authorization": f"Bearer {mem_tok}"})
    assert r2.status_code == 200
