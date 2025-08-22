import os
import datetime as dt
from typing import Optional
from passlib.context import CryptContext
from jose import jwt, JWTError

JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret-change-me")
ALGO = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "60"))

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(password: str, hashed: str) -> bool:
    return pwd_context.verify(password, hashed)

def create_access_token(sub: str, expires_minutes: Optional[int] = None) -> str:
    expire = dt.datetime.now(dt.timezone.utc) + dt.timedelta(minutes=expires_minutes or ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode = {"sub": sub, "exp": expire}
    return jwt.encode(to_encode, JWT_SECRET, algorithm=ALGO)

def decode_token(token: str) -> Optional[str]:
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[ALGO])
        return payload.get("sub")
    except JWTError:
        return None
