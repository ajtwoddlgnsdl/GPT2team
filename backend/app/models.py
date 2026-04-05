from sqlalchemy import Column, Integer, String, DateTime, Boolean, ForeignKey
from sqlalchemy.orm import relationship
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
    heroines = relationship("HeroineProgress", back_populates="user", cascade="all, delete-orphan")

class HeroineProgress(Base):
    __tablename__ = "heroine_progress"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), index=True) # 💡 외래키 추가
    heroine_name = Column(String) 
    current_day = Column(Integer, default=0) 
    affection = Column(Integer, default=0) 
    is_main = Column(Boolean, default=False)
    is_cleared_today = Column(Boolean, default=False) 
    user = relationship("User", back_populates="heroines")
    viewed_zones = relationship("ViewedZone", back_populates="heroine_progress", cascade="all, delete-orphan")

class ViewedZone(Base):
    __tablename__ = "viewed_zones"
    id = Column(Integer, primary_key=True, index=True)
    heroine_progress_id = Column(Integer, ForeignKey("heroine_progress.id", ondelete="CASCADE"), index=True)
    zone = Column(String)
    heroine_progress = relationship("HeroineProgress", back_populates="viewed_zones")