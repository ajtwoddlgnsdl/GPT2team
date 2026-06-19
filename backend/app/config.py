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

LLM_API_URL = os.getenv("LLM_API_URL", "http://localhost:11434/v1/chat/completions")
LLM_MODEL_NAME = os.getenv("LLM_MODEL_NAME", "gemma4:e4b")

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
    "리안": TimeZone.EVENING.value
}

STORY_CONFIG = {}
config_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "story_config.json")

try:
    with open(config_path, "r", encoding="utf-8") as f:
        STORY_CONFIG = json.load(f)
        logger.info("✅ 스토리 스케줄러(JSON) 로드 완료!")
except FileNotFoundError:
    logger.warning("🚨 story_config.json 파일이 없습니다!")

GIFTS_DATA = [
    {
        "id": "test_item",
        "name": "테스트용 막대사탕",
        "price": 100,
        "affection_boost": 1,
        "description": "테스트를 위한 100원짜리 달콤한 막대사탕",
        "replies": {
            "코토리": "와아! 사탕 선물 고마워요! 맛있게 먹을게요! 🍭✨",
            "이서연": "사탕이네요. 잘 먹을게요. 고마워요.",
            "리안": "막대사탕? ㅋ 군것질거리 고맙다."
        }
    },
    {
        "id": "coffee",
        "name": "스타벅스 아메리카노",
        "price": 1000,
        "affection_boost": 5,
        "description": "따뜻하고 부드러운 일상 속 커피 한 잔",
        "replies": {
            "코토리": "선배! 아메리카노 선물이라니 센스쟁이! 내일 일할 때 맛있게 마실게요! ☕🌸",
            "이서연": "커피 잘 마실게요. 마침 잠이 솔솔 오던 참이었는데 고마워요.",
            "리안": "야, 웬 커피냐? 뭐 잘못 먹었냐? ㅋ 암튼 잘 마실게."
        }
    },
    {
        "id": "chocolate",
        "name": "달콤한 초콜릿 상자",
        "price": 10000,
        "affection_boost": 12,
        "description": "당 충전이 필요한 날에 어울리는 달콤한 고백",
        "replies": {
            "코토리": "우와아! 제가 초콜릿 진짜 좋아하는 거 어떻게 아셨어요? 당 충전 제대로예요! 고마워요 선배! 🥰🍫",
            "이서연": "달콤하네요. 일하면서 머리 식힐 때 하나씩 꺼내 먹기 딱 좋은 것 같아요. 감사해요.",
            "리안": "초콜릿이네. 달아서 이가 썩을 것 같지만... 네가 줬으니까 특별히 먹어줌."
        }
    },
    {
        "id": "macaron",
        "name": "고급 마카롱 세트",
        "price": 22000,
        "affection_boost": 30,
        "description": "쫀득한 꼬끄와 달콤한 필링이 가득한 오색 마카롱",
        "replies": {
            "코토리": "헤헤, 고급 마카롱이라니! 입안에서 사르르 녹아내려요~ 선배 최고! 🍰✨",
            "이서연": "단 걸 그렇게 즐기진 않지만... 이 마카롱은 정말 쫀득하고 맛있네요. 고마워요.",
            "리안": "야... 이거 유명한 가게 마카롱 아냐? 웨이팅 엄청 길던데... 고맙게 잘 먹을게."
        }
    },
    {
        "id": "teddy",
        "name": "포근한 곰 인형",
        "price": 45000,
        "affection_boost": 65,
        "description": "안고 자기에 딱 좋은 포근한 베이지색 테디베어",
        "replies": {
            "코토리": "꺄아! 곰 인형 너무 귀여워요! 침대 머리맡에 두고 매일 선배 생각하면서 잘게요! 🧸✨",
            "이서연": "인형이 참 귀엽네요. 제 방 서재 책꽂이 한편에 놔두면 분위기가 살 것 같아요. 잘 간직할게요.",
            "리안": "곰인형이라고? 내가 이런 오글거리는 걸 좋아할 것 같냐? ...근데 좀 귀엽긴 하네. 방에 던져둘게."
        }
    },
    {
        "id": "perfume",
        "name": "명품 향수",
        "price": 95000,
        "affection_boost": 150,
        "description": "특별한 순간을 완성하는 은은한 시그니처 향수",
        "replies": {
            "코토리": "헙... 향수라니... 이렇게 귀한 선물을 받아도 되는 걸까요? 소중하게 아껴서 뿌릴게요. 정말 고마워요 선배... (부끄러워하며)",
            "이서연": "향수 선물이네요. 향이 아주 제 스타일이에요. 특별한 날에 뿌리고 나갈게요. 마음 써줘서 고마워요.",
            "리안": "헉, 향수?! 너 이거 진짜 비싼 거 아니야? 내가 이런 선물을 받아도 되나... 암튼 냄새 좋네. 고맙다."
        }
    }
]