import json
import os
import logging
from enum import Enum
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

ADMIN_SECRET_KEY = os.getenv("ADMIN_SECRET_KEY")
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
ALGORITHM = "HS256"

if not JWT_SECRET_KEY or not ADMIN_SECRET_KEY:
    logger.error("🚨 환경변수에 시크릿 키가 설정되지 않았습니다! .env 파일을 확인하세요.")

class GameState(str, Enum):
    INTRO_1 = "INTRO_1"
    INTRO_2 = "INTRO_2"
    MAIN = "MAIN"
    END = "END"

class TimeZone(str, Enum):
    MORNING = "아침"
    AFTERNOON = "낮"
    EVENING = "저녁"
    NIGHT = "새벽"

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
    "이서연": TimeZone.MORNING.value,
    "코토리": TimeZone.AFTERNOON.value,
    "최시은": TimeZone.EVENING.value
}

STORY_CONFIG = {}
config_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "story_config.json")

try:
    with open(config_path, "r", encoding="utf-8") as f:
        STORY_CONFIG = json.load(f)
        logger.info("✅ 스토리 스케줄러(JSON) 로드 완료!")
except FileNotFoundError:
    logger.warning("🚨 story_config.json 파일이 없습니다!")