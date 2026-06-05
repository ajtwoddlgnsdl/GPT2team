from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app import models
from app.database import engine
from app.routers import router

models.Base.metadata.create_all(bind=engine)

# 테이블에 study_ap 컬럼이 없는 경우 동적으로 추가
from sqlalchemy import text
with engine.connect() as conn:
    try:
        conn.execute(text("SELECT study_ap FROM users LIMIT 1"))
    except Exception:
        # SQLite에서 컬럼이 없으면 ALTER TABLE로 동적 추가
        conn.execute(text("ALTER TABLE users ADD COLUMN study_ap INTEGER DEFAULT 10"))

app = FastAPI(title="리얼타임 비주얼 노벨 API")

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=".*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)
