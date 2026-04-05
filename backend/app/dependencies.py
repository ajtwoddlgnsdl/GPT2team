import jwt
from fastapi import HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.database import SessionLocal
from app.config import JWT_SECRET_KEY, ALGORITHM

security_scheme = HTTPBearer()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_current_user(credentials: HTTPAuthorizationCredentials = Security(security_scheme)):
    token = credentials.credentials
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None: 
            raise HTTPException(status_code=401, detail="MISSING_USER_ID_IN_TOKEN")
        return user_id
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="INVALID_TOKEN")