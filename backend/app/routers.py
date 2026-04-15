import jwt
import datetime
import random
from typing import Optional
from fastapi import APIRouter, Depends, Header, Body
from sqlalchemy.orm import Session

from app import models
from app.config import GameConfig, HEROINE_INFO, STORY_CONFIG, JWT_SECRET_KEY, ALGORITHM, ADMIN_SECRET_KEY, GameState, TimeZone
from app.dependencies import get_db, get_current_user
from app.services import GameLogicService

router = APIRouter()

KST = datetime.timezone(datetime.timedelta(hours=9))

def _get_story_status(user, all_heroines, current_zone):
    auto_play = {"is_available": False}
    if user.game_state == GameState.INTRO_1.value:
        auto_play = {"is_available": True, "heroine_name": "TUTORIAL_DUMMY", "story_id": "intro_1_prologue", "target_day": 0}
    
    elif user.game_state == GameState.INTRO_2.value:
        target_h = next((h for h in all_heroines if HEROINE_INFO.get(h.heroine_name) == current_zone), None)
        if target_h and not target_h.is_cleared_today:
            auto_play = {"is_available": True, "heroine_name": target_h.heroine_name, "story_id": f"day{target_h.current_day}_{current_zone}_{target_h.heroine_name}", "target_day": target_h.current_day}
            
    elif user.game_state == GameState.MAIN.value:
        main_h = next((h for h in all_heroines if h.is_main), None)
        if main_h:
            config = STORY_CONFIG.get(main_h.heroine_name, {})
            req_zones = config.get("schedule", {}).get(str(main_h.current_day), [])
            viewed_zones = [vz.zone for vz in main_h.viewed_zones]
            
            if len(viewed_zones) < len(req_zones):
                next_req_zone = req_zones[len(viewed_zones)]
                if next_req_zone == current_zone:
                    auto_play = {"is_available": True, "heroine_name": main_h.heroine_name, "story_id": f"MAIN_day{main_h.current_day}_{current_zone}_{main_h.heroine_name}", "target_day": main_h.current_day}
                    
    elif user.game_state == GameState.END.value:
        main_h = next((h for h in all_heroines if h.is_main), None)
        if main_h:
            if main_h.affection < 30:
                ending_type = "BAD"
            elif 30 <= main_h.affection < 80:
                ending_type = "NORMAL"
            else:
                ending_type = "TRUE"
            auto_play = {"is_available": True, "heroine_name": main_h.heroine_name, "story_id": f"ENDING_{ending_type}_{main_h.heroine_name}", "target_day": main_h.current_day}
            
    return auto_play

# ==========================================
# 👤 일반 유저 API 
# ==========================================

@router.get("/server-time")
def get_server_time():
    now = datetime.datetime.now(KST)
    return {"status": "success", "hour": now.hour, "timestamp": now.isoformat()}

@router.post("/verify-time")
def verify_time(client_estimated_hour: int = Body(..., embed=True)):
    now = datetime.datetime.now(KST)
    if client_estimated_hour == now.hour:
        return {"status": "success", "server_hour": now.hour}
    else:
        return {"status": "fail", "server_hour": now.hour}

@router.get("/user/status")
def get_user_status(user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user: 
        return {"status": "error"}
    return {"status": "success", "username": user.username, "ap": user.action_points, "money": user.money}

@router.post("/auth/guest-login")
def guest_login(db: Session = Depends(get_db)):
    new_user = models.User(username="Guest", game_state=GameState.INTRO_1.value, last_login=datetime.datetime.now(KST))
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    for h_name in HEROINE_INFO.keys():
        new_heroine = models.HeroineProgress(user_id=new_user.id, heroine_name=h_name)
        db.add(new_heroine)
    db.commit()

    expire_time = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=2)
    access_token = jwt.encode({"sub": str(new_user.id), "exp": expire_time}, JWT_SECRET_KEY, algorithm=ALGORITHM)

    return {"status": "success", "user_id": str(new_user.id), "access_token": access_token}

@router.post("/update-nickname")
def update_nickname(
    username: str = Body(..., min_length=2, max_length=12, embed=True),
    user_id: str = Depends(get_current_user), 
    db: Session = Depends(get_db)
):
    username = username.strip()
    if not username:
        return {"status": "error", "error_code": "INVALID_NICKNAME"}
    
    user = db.query(models.User).filter(models.User.id == user_id).with_for_update().first()
    if not user:
        return {"status": "error"}
    
    user.username = username
    db.commit()
    
    return {"status": "success", "new_username": user.username}

@router.post("/login")
def login(user_id: str, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).with_for_update().first()
    if not user:
        return {"status": "error", "error_code": "USER_NOT_FOUND"}

    all_heroines = db.query(models.HeroineProgress).filter(models.HeroineProgress.user_id == user_id).with_for_update().all()

    now = datetime.datetime.now(KST)
    offline_days = (now.replace(tzinfo=None) - user.last_login.replace(tzinfo=None)).days if user.last_login else 0
    has_penalty = GameLogicService.calculate_penalty(user, all_heroines, offline_days)
    crossed_midnight = user.last_login and user.last_login.date() < now.date()

    if crossed_midnight:
        ap_refill_needed = GameLogicService.process_daily_reset(user, all_heroines)
        if ap_refill_needed:
            user.action_points = GameConfig.MAX_AP 

    user.last_login = now
    db.commit()

    expire_time = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=2)
    new_access_token = jwt.encode({"sub": str(user.id), "exp": expire_time}, JWT_SECRET_KEY, algorithm=ALGORITHM)

    return {"status": "success", "access_token": new_access_token, "user_status": {"current_ap": user.action_points, "game_state": user.game_state}, "penalty_info": {"has_penalty": has_penalty}}

@router.get("/check-story")
def check_story(user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    hour = datetime.datetime.now(KST).hour
    
    if 6 <= hour < 12:
        current_zone = TimeZone.MORNING.value
    elif 12 <= hour < 18:
        current_zone = TimeZone.AFTERNOON.value
    elif 18 <= hour < 24:
        current_zone = TimeZone.EVENING.value
    else:
        current_zone = TimeZone.NIGHT.value

    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        return {"status": "error"}
    
    all_heroines = db.query(models.HeroineProgress).filter(models.HeroineProgress.user_id == user_id).all()
    auto_play = _get_story_status(user, all_heroines, current_zone)

    if auto_play.get("is_available"):
        expire_time = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=2)
        ticket_payload = {"heroine_name": auto_play["heroine_name"], "zone": current_zone, "target_day": auto_play.get("target_day", 0), "exp": expire_time}
        auto_play["story_ticket"] = jwt.encode(ticket_payload, JWT_SECRET_KEY, algorithm=ALGORITHM)

    return {"status": "success", "current_zone": current_zone, "auto_play_story": auto_play}

@router.post("/complete-story")
def complete_story(story_ticket: str = Body(...), bonus_token: Optional[str] = Body(None), user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).with_for_update().first()
    if not user:
        return {"status": "error"}

    # 프롤로그(INTRO_1)는 티켓 유효성 검사 없이 상태만 변경
    if user.game_state == GameState.INTRO_1.value:
        user.game_state = GameState.INTRO_2.value
        all_heroines = db.query(models.HeroineProgress).filter(models.HeroineProgress.user_id == user_id).all()
        for h in all_heroines:
            h.is_cleared_today = True
        db.commit()
        return {"status": "success"}

    # 프롤로그가 아닌 경우, 티켓 유효성 검사
    try:
        payload = jwt.decode(story_ticket, JWT_SECRET_KEY, algorithms=[ALGORITHM])
        heroine_name = payload.get("heroine_name")
        viewed_zone = payload.get("zone")
        target_day = payload.get("target_day")
    except jwt.ExpiredSignatureError:
        return {"status": "error", "error_code": "STORY_TICKET_EXPIRED"}
    except jwt.PyJWTError:
        return {"status": "error", "error_code": "INVALID_STORY_TICKET"}

    heroine = db.query(models.HeroineProgress).filter(models.HeroineProgress.user_id == user_id, models.HeroineProgress.heroine_name == heroine_name).with_for_update().first()
    if not heroine:
        return {"status": "error"}

    if target_day is not None and heroine.current_day != target_day:
        return {"status": "error", "error_code": "INVALID_DAY_TICKET"}
    if heroine.is_cleared_today:
        return {"status": "error", "error_code": "ALREADY_CLEARED_TODAY"}
        
    if user.game_state == GameState.MAIN.value:
        viewed_zone_names = [vz.zone for vz in heroine.viewed_zones]
        if viewed_zone and viewed_zone in viewed_zone_names:
            return {"status": "error", "error_code": "ALREADY_CLEARED_ZONE"}

    bonus_affection = 0
    if bonus_token:
        try:
            b_payload = jwt.decode(bonus_token, JWT_SECRET_KEY, algorithms=[ALGORITHM])
            bonus_affection = b_payload.get("bonus", 0)
        except jwt.PyJWTError:
            return {"status": "error", "error_code": "INVALID_BONUS_TOKEN"}

    heroine.affection += (GameConfig.BASE_STORY_SCORE + bonus_affection) 
    
    if user.game_state == GameState.MAIN.value:
        if viewed_zone: 
            new_vz = models.ViewedZone(zone=viewed_zone)
            heroine.viewed_zones.append(new_vz)
        
        config = STORY_CONFIG.get(heroine.heroine_name, {})
        req_zones = config.get("schedule", {}).get(str(heroine.current_day), [])
        
        if len(heroine.viewed_zones) >= len(req_zones):
            heroine.is_cleared_today = True
    else:
        heroine.is_cleared_today = True 

    db.commit()
    return {"status": "success"}

@router.post("/play-minigame")
def play_minigame(user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).with_for_update().first()
    if not user:
        return {"status": "error"}
    if user.action_points < GameConfig.MINIGAME_COST:
        return {"status": "fail", "error_code": "NOT_ENOUGH_AP"}
        
    user.action_points -= GameConfig.MINIGAME_COST
    earned_money = random.randint(GameConfig.MINIGAME_REWARD_MIN, GameConfig.MINIGAME_REWARD_MAX)
    user.money += earned_money
    db.commit()
    return {"status": "success", "earned_money": earned_money, "current_ap": user.action_points, "total_money": user.money}

@router.post("/buy-gift")
def buy_gift(heroine_name: str = Body(..., embed=True), user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).with_for_update().first()
    heroine = db.query(models.HeroineProgress).filter(models.HeroineProgress.user_id == user_id, models.HeroineProgress.heroine_name == heroine_name).with_for_update().first()
    
    if not user or not heroine:
        return {"status": "error"}
    if user.money < GameConfig.GIFT_PRICE:
        return {"status": "fail", "error_code": "NOT_ENOUGH_MONEY"}
        
    user.money -= GameConfig.GIFT_PRICE
    heroine.affection += GameConfig.GIFT_AFFECTION_BOOST
    db.commit()
    return {"status": "success", "current_money": user.money, "hidden_affection": heroine.affection}


# ==========================================
# 🛠️ 개발자(Admin) 전용 치트 API 
# ==========================================

@router.post("/admin/login")
def admin_login(user_id: str, cheat_offline_days: int, admin_key: str = Header(...), db: Session = Depends(get_db)):
    if admin_key != ADMIN_SECRET_KEY:
        return {"status": "error", "error_code": "UNAUTHORIZED"}
    
    user = db.query(models.User).filter(models.User.id == user_id).with_for_update().first()
    if not user:
        return {"status": "error"}

    all_heroines = db.query(models.HeroineProgress).filter(models.HeroineProgress.user_id == user_id).with_for_update().all()
    now = datetime.datetime.now(KST)

    has_penalty = GameLogicService.calculate_penalty(user, all_heroines, cheat_offline_days)
    if cheat_offline_days >= 1:
        ap_refill_needed = GameLogicService.process_daily_reset(user, all_heroines)
        if ap_refill_needed:
            user.action_points = GameConfig.MAX_AP 

    user.last_login = now
    db.commit()

    expire_time = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=2)
    new_access_token = jwt.encode({"sub": str(user.id), "exp": expire_time}, JWT_SECRET_KEY, algorithm=ALGORITHM)

    return {"status": "success", "access_token": new_access_token, "user_status": {"current_ap": user.action_points, "game_state": user.game_state}, "penalty_info": {"has_penalty": has_penalty}}

@router.get("/admin/check-story")
def admin_check_story(cheat_hour: int, admin_key: str = Header(...), user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    if admin_key != ADMIN_SECRET_KEY:
        return {"status": "error", "error_code": "UNAUTHORIZED"}
    
    if 6 <= cheat_hour < 12:
        current_zone = TimeZone.MORNING.value
    elif 12 <= cheat_hour < 18:
        current_zone = TimeZone.AFTERNOON.value
    elif 18 <= cheat_hour < 24:
        current_zone = TimeZone.EVENING.value
    else:
        current_zone = TimeZone.NIGHT.value

    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        return {"status": "error"}
    
    all_heroines = db.query(models.HeroineProgress).filter(models.HeroineProgress.user_id == user_id).all()
    auto_play = _get_story_status(user, all_heroines, current_zone)

    if auto_play.get("is_available"):
        expire_time = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=2)
        ticket_payload = {"heroine_name": auto_play["heroine_name"], "zone": current_zone, "target_day": auto_play.get("target_day", 0), "exp": expire_time}
        auto_play["story_ticket"] = jwt.encode(ticket_payload, JWT_SECRET_KEY, algorithm=ALGORITHM)

    return {"status": "success", "current_zone": current_zone, "auto_play_story": auto_play}