def test_register_login_refresh(client):
    # Register
    r = client.post("/users/register", json={"username": "tuser", "password": "password8", "email": "t@example.com"})
    assert r.status_code in (200, 400)
    # Login
    r = client.post("/users/login", json={"username": "tuser", "password": "password8"})
    assert r.status_code == 200
    data = r.json()
    assert "access_token" in data
    assert "refresh_token" in data
    # Refresh
    r2 = client.post("/users/refresh", json={"refresh_token": data["refresh_token"]})
    assert r2.status_code == 200
    assert "access_token" in r2.json()
