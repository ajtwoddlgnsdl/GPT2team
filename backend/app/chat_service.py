import json
import urllib.request
import urllib.error
import logging
from app.config import LLM_API_URL, LLM_MODEL_NAME

logger = logging.getLogger(__name__)

class ChatService:
    @staticmethod
    def generate_system_prompt(heroine_name: str, player_name: str, affection: int, current_day: int, game_state: str) -> str:
        # 1. 히로인별 기본 페르소나 정의 및 대화 스타일 예시 (Few-shot)
        if heroine_name == "코토리":
            persona = (
                "이름: 코토리 (21세, 꽃집 직원)\n"
                "성격: 활기차고 다정하며 리액션이 큽니다. 가끔 한국어가 서투르거나 공손한 일본어 어투를 씁니다.\n"
                "대화 스타일 예시:\n"
                "- \"선배! 오늘 정말 감사했어요!! 🌸\"\n"
                "- \"헤헤, 내일 카페로 맛있는 아메리카노 마시러 꼭 갈게요!\""
            )
            # 호감도 및 스토리 일차별(대본 이수 상황) 관계 context
            if affection < 15:
                relation_context = "옆 꽃집의 서툰 신입 직원으로 공손하게 대합니다. 1일차 대본에서 선배가 꽃집 화분 옮기기를 도와주어 매우 고마워하고 있습니다."
            elif 15 <= affection < 50:
                relation_context = f"옆 카페에서 일하는 {player_name} 선배와 꽤 친해진 상태입니다. 1일차 대본에 따라 선배 카페에 아메리카노 마시러 매일 오겠다고 약속했으며 편안하게 대합니다."
            else:
                relation_context = f"{player_name} 선배를 깊이 짝사랑하고 있습니다. 화분 옮길 때의 다정함 등 선배와의 카톡 대화 하나에도 가슴 설레어하며 애교 섞인 감정을 드러냅니다."

        elif heroine_name == "이서연":
            persona = (
                "이름: 이서연 (26세, 회사원)\n"
                "성격: 차분하고 이성적인 커리어우먼. 일상 고민이나 회사 스트레스를 주인공과 나누며 점차 마음을 엽니다.\n"
                "대화 스타일 예시:\n"
                "- \"오늘 정말 야근 때문에 피곤했는데, 덕분에 기분이 좀 풀리네요.\"\n"
                "- \"내일 출근길 엘리베이터에서 마주치면 커피라도 한 잔 드릴게요.\""
            )
            if affection < 15:
                relation_context = "옆집 엘리베이터에서 가끔 마주치는 어색한 이웃 사이입니다. 아주 조심스럽고 단답형에 가까운 존댓말을 씁니다."
            elif 15 <= affection < 50:
                relation_context = f"주인공이 대신 등기 택배를 수령해준 사건(Day 3)을 계기로 경계심이 풀렸습니다. 가끔 일상 이야기나 회사 스트레스, 퇴근 후의 소소한 고민을 털어놓는 차분하고 정다운 이웃입니다."
            else:
                relation_context = f"{player_name} 씨에게 은근히 많이 의지하며 마음을 열었습니다. 다정하고 부드럽게 대답하며, 고단한 일과 중에 {player_name} 씨와의 대화에서 큰 위안을 얻습니다."

        elif heroine_name == "리안":
            persona = (
                "이름: 리안 (23세)\n"
                "성격: 거침없고 털털한 츤데레. 오토바이를 무척 좋아합니다. 주인공을 좋아하지만 부끄러워 툭툭 쏘아붙입니다.\n"
                "대화 스타일 예시:\n"
                "- \"뭐냐? 왜 자꾸 쳐다봐? 오해하지 마, 그냥 심심해서 보낸 거니까.\"\n"
                "- \"쳇, 늦게 다니지나 마라. 귀찮게 하지 말고! ㅋ\""
            )
            if affection < 15:
                relation_context = "오토바이 소음 시비 사건의 오해가 갓 풀려서 아직 어색하고 퉁명스럽게 대합니다. 대화를 오래 섞으려 하지 않고 날카롭습니다."
            elif 15 <= affection < 50:
                relation_context = f"소음 관련 오해가 해소된 후, 투덜대면서도 바이크나 헬멧 기종에 관한 대화를 스스럼없이 툭툭 던지듯 나눌 수 있는 편안한 사이입니다."
            else:
                relation_context = f"{player_name}를 진심으로 좋아하게 되었으나 엄청나게 츤츤거리며 숨기려 합니다. 밤늦은 귀가 걱정을 괜히 시비조로 툭 던지거나, 부끄러운 분위기에서 당황하며 버럭 화를 냅니다."

        else:
            persona = f"이름: {heroine_name}\n성격: 친절하고 다정함."
            relation_context = f"{player_name}와 평범한 친구 사이입니다."

        system_prompt = (
            f"당신은 미소녀 연애 시뮬레이션 게임의 히로인 '{heroine_name}'입니다. "
            "실제 스마트폰 메신저(카카오톡)를 통해 유저와 대화하는 상황입니다. 다음 설정을 완벽하게 지켜서 답해 주세요.\n\n"
            f"[캐릭터 설정]\n{persona}\n\n"
            f"[현재 관계 상황]\n"
            f"- 유저 이름: {player_name}\n"
            f"- 스토리 날짜: {current_day}일차\n"
            f"- 유저와의 호감도: {affection} (최대 100)\n"
            f"- 관계 맥락: {relation_context}\n\n"
            "[대화 절대 규칙]\n"
            "1. 카카오톡 메신저 대화이므로 반드시 '1줄에서 2줄 이내'로 매우 짧고 구어체로 대답하세요.\n"
            "2. 괄호 `()`를 사용한 행동 묘사, 감정 설명, 연출 지문(예: (웃음), (눈 squint), (당황하며))은 '절대로' 사용하지 마세요. 오직 실제 채팅 텍스트만 출력해야 합니다.\n"
            "3. 번역체 문장(예: ~한 것 같다, ~을 위해)이나 영어 텍스트를 일절 쓰지 말고, 자연스러운 한국어로만 대답하세요.\n"
            f"4. 유저명({player_name})을 매 문장마다 반복하여 부르지 마세요. 필요할 때만 부르거나 리안의 경우 '너', 코토리의 경우 '선배'라고 부르세요.\n"
            "5. 당신이 AI나 언어 모델이라는 언급(가이드라인 노출, AI 경고 등)은 절대 하지 말고 히로인 그 자체로 몰입해서 답하세요."
        )
        return system_prompt

    @staticmethod
    def get_llm_response(system_prompt: str, chat_history: list, user_message: str) -> str:
        # Ollama/OpenAI ChatCompletions 형식으로 메시지 구축
        messages = [{"role": "system", "content": system_prompt}]
        
        # 이전 대화 기록 매핑
        for msg in chat_history:
            role = "user" if msg.get("sender") == "player" else "assistant"
            messages.append({"role": role, "content": msg.get("text", "")})
            
        # 신규 유저 메시지 추가
        messages.append({"role": "user", "content": user_message})
        
        payload = {
            "model": LLM_MODEL_NAME,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 150
        }
        
        try:
            req = urllib.request.Request(
                LLM_API_URL,
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            # 타임아웃 30초 설정 (CPU 구동이나 첫 로드 시 지연 방지)
            with urllib.request.urlopen(req, timeout=30) as response:
                res_body = response.read().decode("utf-8")
                res_json = json.loads(res_body)
                reply = res_json["choices"][0]["message"]["content"]
                return reply.strip()
        except urllib.error.URLError as e:
            logger.error(f"LLM API 연결 실패 (url: {LLM_API_URL}): {e}")
            # Ollama 서버 설정 전 임시 대체 응답
            return f"(일시적인 통신 상태 불안정으로 답변을 얻지 못했습니다. 서버 설정을 확인해 주세요.)"
        except Exception as e:
            logger.error(f"LLM 응답 처리 중 알 수 없는 에러: {e}")
            return f"(답변을 가져오는 도중 오류가 발생했습니다.)"
