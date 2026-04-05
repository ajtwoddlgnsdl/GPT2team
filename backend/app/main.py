from fastapi import FastAPI
from app import models
from app.database import engine
from app.routers import router

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="리얼타임 비주얼 노벨 API")

app.include_router(router)