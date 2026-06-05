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
KOTORI_NAME = "코토리"
CAFE_GAME_TYPE = "cafe_kotori"

# 💡 일러스트 해금 조건 매핑 테이블 (히로인 이름 -> (Day, Zone) -> 일러스트 ID)
ILLUSTRATION_UNLOCK_CONDITIONS = {
    "리안": {
        (1, "밤"): "lian_first_meet",
        (2, "밤"): "lian_home_lobby",
        (3, "밤"): "lian_riding_day3",
    },
    "이서연": {
        (9, "아침"): "seoyeon_flowershop",
    },
    "코토리": {
        (2, "낮"): "kotori_cafe",
    }
}

def _zone_from_hour(hour):
    if 6 <= hour < 12:
        return TimeZone.MORNING.value
    if 12 <= hour < 18:
        return TimeZone.AFTERNOON.value
    if 18 <= hour < 24:
        return TimeZone.EVENING.value
    return TimeZone.NIGHT.value

def _current_day(all_heroines):
    if not all_heroines:
        return 0
    return max(h.current_day for h in all_heroines)

def _kotori_progress(all_heroines):
    return next((h for h in all_heroines if h.heroine_name == KOTORI_NAME), None)

def _kotori_story_completed_today(user, kotori):
    if not kotori:
        return False
    if user.game_state == GameState.INTRO_2.value:
        return kotori.is_cleared_today
    if user.game_state == GameState.MAIN.value:
        if not kotori.is_main:
            return False
        viewed_zone_names = [vz.zone for vz in kotori.viewed_zones]
        return kotori.is_cleared_today or TimeZone.AFTERNOON.value in viewed_zone_names
    return False

def _cafe_minigame_status(user, all_heroines, current_zone=None):
    current_zone = current_zone or _zone_from_hour(datetime.datetime.now(KST).hour)
    kotori = _kotori_progress(all_heroines)
    story_completed = _kotori_story_completed_today(user, kotori)
    day = kotori.current_day if kotori else _current_day(all_heroines)
    can_play = (
        current_zone == TimeZone.AFTERNOON.value
        and story_completed
        and user.action_points >= GameConfig.MINIGAME_COST
    )
    return {
        "current_day": day,
        "day": day,
        "current_zone": current_zone,
        "ap": user.action_points,
        "current_ap": user.action_points,
        "money": user.money,
        "story_completed_today": story_completed,
        "can_play": can_play,
        "game_type": CAFE_GAME_TYPE,
    }

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
    all_heroines = db.query(models.HeroineProgress).filter(models.HeroineProgress.user_id == user_id).all()
    current_day = _current_day(all_heroines)
    return {
        "status": "success",
        "username": user.username,
        "ap": user.action_points,
        "money": user.money,
        "day": current_day,
        "current_day": current_day,
    }

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
    if len(username) < 2 or len(username) > 12:
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
    current_zone = _zone_from_hour(datetime.datetime.now(KST).hour)

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

    # 💡 모든 스토리(프롤로그 포함)에 대해 티켓 유효성 검사 수행
    try:
        payload = jwt.decode(story_ticket, JWT_SECRET_KEY, algorithms=[ALGORITHM])
        heroine_name = payload.get("heroine_name")
        viewed_zone = payload.get("zone")
        target_day = payload.get("target_day")
    except jwt.ExpiredSignatureError:
        return {"status": "error", "error_code": "STORY_TICKET_EXPIRED"}
    except jwt.PyJWTError:
        return {"status": "error", "error_code": "INVALID_STORY_TICKET"}

    # 프롤로그1(INTRO_1) 처리 → intro_2_prologue 티켓 발급 후 next_story로 반환
    if user.game_state == GameState.INTRO_1.value:
        if heroine_name != "TUTORIAL_DUMMY":
            return {"status": "error", "error_code": "INVALID_STORY_TICKET"}

        user.game_state = GameState.INTRO_2.value
        db.commit()

        expire_time = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=2)
        next_ticket = jwt.encode(
            {"heroine_name": "TUTORIAL_DUMMY", "zone": "intro_2", "target_day": 0, "exp": expire_time},
            JWT_SECRET_KEY, algorithm=ALGORITHM
        )
        return {"status": "success", "next_story": {
            "story_id": "intro_2_prologue",
            "heroine_name": "TUTORIAL_DUMMY",
            "story_ticket": next_ticket
        }}

    # 프롤로그2(INTRO_2 + TUTORIAL_DUMMY) 처리 → 모든 히로인 오늘치 소비 후 로비
    if user.game_state == GameState.INTRO_2.value and heroine_name == "TUTORIAL_DUMMY":
        all_heroines = db.query(models.HeroineProgress).filter(models.HeroineProgress.user_id == user_id).all()
        for h in all_heroines:
            h.is_cleared_today = True
        db.commit()
        return {"status": "success"}

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
            b_payload = jwt.decode(bonus_token, JWT_SECRET_KEY, algorithms=[ALGORITHM], options={"verify_iat": False})
            bonus_affection = b_payload.get("bonus", 0)
        except jwt.PyJWTError as e:
            print(f"🚨 보너스 토큰 디코딩 에러: {e}")
            return {"status": "error", "error_code": "INVALID_BONUS_TOKEN"}

    heroine.affection += (GameConfig.BASE_STORY_SCORE + bonus_affection)

    if heroine.heroine_name == KOTORI_NAME and viewed_zone == TimeZone.AFTERNOON.value:
        user.action_points = min(GameConfig.MAX_AP, user.action_points + 1)
    
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

    # 💡 앨범 일러스트 동적 해금 판정
    unlocked_id = None
    if heroine_name in ILLUSTRATION_UNLOCK_CONDITIONS:
        conds = ILLUSTRATION_UNLOCK_CONDITIONS[heroine_name]
        target_key = (heroine.current_day, viewed_zone)
        if target_key in conds:
            tgt_id = conds[target_key]
            # 기존 해금 리스트 파싱
            current_unlocked = [x.strip() for x in (heroine.unlocked_illustrations or "").split(",") if x.strip()]
            if tgt_id not in current_unlocked:
                current_unlocked.append(tgt_id)
                heroine.unlocked_illustrations = ",".join(current_unlocked)
                unlocked_id = tgt_id

    db.commit()
    
    response_data = {"status": "success"}
    if unlocked_id:
        response_data["unlocked_id"] = unlocked_id
    return response_data

@router.get("/album/status")
def album_status(user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        return {"status": "error"}

    all_heroines = db.query(models.HeroineProgress).filter(models.HeroineProgress.user_id == user_id).all()
    
    unlocked_data = {
        "리안": [],
        "이서연": [],
        "코토리": []
    }
    
    for hp in all_heroines:
        if hp.heroine_name in unlocked_data:
            ids = [x.strip() for x in (hp.unlocked_illustrations or "").split(",") if x.strip()]
            unlocked_data[hp.heroine_name] = ids
            
    return {"status": "success", "unlocked_data": unlocked_data}

@router.get("/calendar/status")
def calendar_status(user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        return {"status": "error"}

    all_heroines = db.query(models.HeroineProgress).filter(models.HeroineProgress.user_id == user_id).all()
    current_zone = _zone_from_hour(datetime.datetime.now(KST).hour)

    heroine_list = []
    for hp in all_heroines:
        viewed_zones = [vz.zone for vz in hp.viewed_zones]
        heroine_list.append({
            "name": hp.heroine_name,
            "current_day": hp.current_day,
            "is_main": hp.is_main,
            "is_cleared_today": hp.is_cleared_today,
            "viewed_zones": viewed_zones
        })

    return {
        "status": "success",
        "game_state": user.game_state,
        "current_zone": current_zone,
        "heroines": heroine_list,
        "story_config": STORY_CONFIG
    }

@router.get("/minigame/status")
def minigame_status(game_type: str = CAFE_GAME_TYPE, user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        return {"status": "error"}

    all_heroines = db.query(models.HeroineProgress).filter(models.HeroineProgress.user_id == user_id).all()
    if game_type == CAFE_GAME_TYPE:
        return {"status": "success", **_cafe_minigame_status(user, all_heroines)}

    return {
        "status": "success",
        "game_type": game_type,
        "ap": user.action_points,
        "current_ap": user.action_points,
        "money": user.money,
        "day": _current_day(all_heroines),
        "current_day": _current_day(all_heroines),
        "can_play": user.action_points >= GameConfig.MINIGAME_COST,
    }

@router.post("/minigame/start")
def start_minigame(game_type: str = Body(..., embed=True), user_id: str = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).with_for_update().first()
    if not user:
        return {"status": "error"}

    if game_type == CAFE_GAME_TYPE:
        all_heroines = db.query(models.HeroineProgress).filter(models.HeroineProgress.user_id == user_id).with_for_update().all()
        status = _cafe_minigame_status(user, all_heroines)
        if status["current_zone"] != TimeZone.AFTERNOON.value:
            return {"status": "fail", "error_code": "CAFE_ONLY_AFTERNOON", **status}
        if not status["story_completed_today"]:
            return {"status": "fail", "error_code": "KOTORI_STORY_REQUIRED", **status}

    if user.action_points < GameConfig.MINIGAME_COST:
        return {"status": "fail", "error_code": "NOT_ENOUGH_AP"}
    
    user.action_points -= GameConfig.MINIGAME_COST
    db.commit()
    return {"status": "success", "current_ap": user.action_points}

@router.post("/minigame/reward")
def reward_minigame(
    game_type: str = Body(...),
    cleared_level: Optional[int] = Body(None),
    result: Optional[str] = Body(None),
    latte_art: bool = Body(False),
    user_id: str = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    user = db.query(models.User).filter(models.User.id == user_id).with_for_update().first()
    if not user:
        return {"status": "error"}

    if game_type == CAFE_GAME_TYPE:
        reward_table = {"success": 2500, "normal": 1800, "funny": 700, "fail": 900}
        safe_result = result if result in reward_table else "fail"
        earned_money = reward_table[safe_result]
        tip = 700 if safe_result == "success" else 0
        if safe_result == "success" and latte_art:
            earned_money += 500
            tip += 300
        user.money += earned_money + tip
        db.commit()
        return {
            "status": "success",
            "earned_money": earned_money,
            "tip": tip,
            "total_money": user.money,
            "result": safe_result,
        }

    reward_table = {1: 50, 2: 100, 3: 150, 4: 200, 5: 250}
    earned_money = reward_table.get(cleared_level, 50)

    user.money += earned_money
    db.commit()
    return {"status": "success", "earned_money": earned_money, "total_money": user.money}

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
