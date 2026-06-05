from fastapi import FastAPI
from sqlalchemy import inspect, text
from fastapi.middleware.cors import CORSMiddleware
from app import models
from app.database import engine
from app.routers import router

models.Base.metadata.create_all(bind=engine)

def _ensure_schema():
    inspector = inspect(engine)
    columns = {column["name"] for column in inspector.get_columns("heroine_progress")}
    if "unlocked_illustrations" not in columns:
        with engine.begin() as conn:
            conn.execute(
                text(
                    "ALTER TABLE heroine_progress "
                    "ADD COLUMN unlocked_illustrations VARCHAR DEFAULT ''"
                )
            )

_ensure_schema()

app = FastAPI(title="리얼타임 비주얼 노벨 API")

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=".*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)
