import json
import os
from dotenv import load_dotenv

load_dotenv()

ADMIN_SECRET_KEY = os.getenv("ADMIN_SECRET_KEY", "super_secret_dev_key_123!")
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "my_game_secret_key_777!")
ALGORITHM = "HS256"

class GameConfig:
    MAX_AP = 10
    PENALTY_DAYS_MIN = 3
    PENALTY_DAYS_MAX = 5
    PENALTY_DROP_MINOR = 3
    PENALTY_DROP_MAJOR = 10
    MAIN_START_DAY = 9
    BASE_STORY_SCORE = 2
    MAX_BONUS_SCORE = 10
    MINIGAME_COST = 1
    MINIGAME_REWARD_MIN = 100
    MINIGAME_REWARD_MAX = 300
    GIFT_PRICE = 500
    GIFT_AFFECTION_BOOST = 5

HEROINE_INFO = {
    "유나": "아침",
    "지수": "낮",
    "민아": "저녁"
}

STORY_CONFIG = {}
config_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "story_config.json")

try:
    with open(config_path, "r", encoding="utf-8") as f:
        STORY_CONFIG = json.load(f)
        print("✅ 스토리 스케줄러(JSON) 로드 완료!")
except FileNotFoundError:
    print("🚨 story_config.json 파일이 없습니다!")