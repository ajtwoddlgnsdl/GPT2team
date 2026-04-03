from sqlalchemy import Column, Integer, String, DateTime, Boolean
from sqlalchemy.sql import func
import uuid
from app.database import Base 

class User(Base):
    __tablename__ = "users"
    id = Column(String, primary_key=True, index=True, default=lambda: str(uuid.uuid4()))
    username = Column(String, index=True)
    game_state = Column(String, default="INTRO_1") 
    action_points = Column(Integer, default=10) 
    money = Column(Integer, default=0) 
    last_login = Column(DateTime(timezone=True), server_default=func.now()) 

class HeroineProgress(Base):
    __tablename__ = "heroine_progress"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True) 
    heroine_name = Column(String) 
    current_day = Column(Integer, default=0) 
    affection = Column(Integer, default=0) 
    is_main = Column(Integer, default=0)
    is_cleared_today = Column(Boolean, default=False) 
    viewed_zones_today = Column(String, default="")