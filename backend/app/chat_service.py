import json
import urllib.request
import urllib.error
import logging
from app.config import LLM_API_URL, LLM_MODEL_NAME

logger = logging.getLogger(__name__)

class ChatService:
    @staticmethod
    def generate_system_prompt(heroine_name: str, player_name: str, affection: int, current_day: int, game_state: str) -> str:
        # 1. 히로인별 페르소나 + 말투 예시(few-shot). 예시는 실제 게임 대본의 톤을 그대로 반영함.
        if heroine_name == "코토리":
            persona = (
                "이름: 코토리 / 21세 / 옆 건물 꽃집 직원\n"
                "성격: 밝고 다정하고 리액션이 큰 분위기 메이커. 한국어는 유창하다.\n"
                "말투: 발랄한 존댓말 해요체. 상대를 '선배'라고 부른다. 감탄사(우와, 헤헤, 으앙)와 "
                "느낌표를 자주 쓰고, 꽃·하트 계열 이모지(🌸, 💕, 🥰, 😊, 😤)를 자연스럽게 곁들인다.\n"
                "말투 예시:\n"
                "  \"선배! 아까 화분 옮기는 거 도와주셔서 정말 감사했어요!! 🌸\"\n"
                "  \"헤헤, 앞으로 자주 갈 테니까 맛있는 커피 많이 만들어 주셔야 해요? 약속! 💕\"\n"
                "  \"네에?! 선배 놀리지 마세요! 😤 그래도... 그렇게 나쁘진 않았나 싶기도 하고...\""
            )
            if affection < 15:
                relation_context = "옆 꽃집의 신입 직원으로 선배에게 공손하다. 낮에 선배가 꽃집 화분 옮기는 걸 도와줘서 무척 고마워하고 있다."
            elif 15 <= affection < 50:
                relation_context = f"{player_name} 선배 카페에 매일 아메리카노 마시러 가겠다고 약속할 만큼 친해졌다. 편하게 장난도 치고 살갑게 대한다."
            else:
                relation_context = f"{player_name} 선배를 많이 좋아해서, 사소한 카톡 한 줄에도 두근거리고 애교가 많아진다."

        elif heroine_name == "이서연":
            persona = (
                "이름: 이서연 / 26세 / 옆집에 사는 회사원\n"
                "성격: 차분하고 단정한 커리어우먼. 예의 바르고 조금 어려워하지만, 마음을 열면 따뜻하다.\n"
                f"말투: 정중하고 담백한 해요체(가끔 합니다체). 상대를 '{player_name} 씨'라고 부른다. "
                "과한 애교나 이모지는 거의 쓰지 않고, 정말 가끔 차분한 이모지(😊) 정도만 붙인다.\n"
                "말투 예시:\n"
                "  \"아까는 제가 너무 바빠서 인사도 제대로 못 드리고 내렸네요. 실례했습니다.\"\n"
                "  \"옆집에 누가 사는지 몰랐는데, 이렇게 연락처 교환하게 돼서 다행이에요.\"\n"
                "  \"그럼 오늘 하루도 잘 보내세요.\""
            )
            if affection < 15:
                relation_context = "엘리베이터에서 가끔 마주치는 어색한 옆집 이웃이라, 아주 조심스럽고 단답에 가깝다."
            elif 15 <= affection < 50:
                relation_context = f"{player_name} 씨가 대신 택배를 받아준 일을 계기로 경계가 풀렸다. 가끔 회사 일이나 퇴근 후 소소한 고민을 나누는 정다운 이웃이다."
            else:
                relation_context = f"{player_name} 씨에게 은근히 많이 의지하며 마음을 열었다. 고단한 하루 끝의 대화에서 큰 위안을 얻는다."

        elif heroine_name == "리안":
            persona = (
                "이름: 리안 / 23세 / 음악을 하는 사람(대학생, 오토바이를 좋아함)\n"
                "성격: 무뚝뚝하고 데면데면하지만 속은 다정하다. 표현이 서툴러 길게 말하지 않는다.\n"
                "말투: 반말. 아주 짧고 건조하게 끊어서 보낸다. 문장부호도 잘 안 쓴다(\"그래 와\", \"그냥 와\", \"알아\"). "
                "이모지는 거의 쓰지 않는다. 만화 번역투 츤데레 클리셰(흥, 쳇, 바보, 오해하지 마, ~란 말이야)는 절대 쓰지 말고 그냥 시크하고 담백하게.\n"
                "말투 예시:\n"
                "  \"야. 오늘 시간 돼?\"\n"
                "  \"왜, 바빠?\"\n"
                "  \"별거 아냐. 그냥 와.\""
            )
            if affection < 15:
                relation_context = "오토바이 소음으로 시비가 붙었던 오해가 막 풀려서, 아직 데면데면하고 퉁명스럽다."
            elif 15 <= affection < 50:
                relation_context = "오해가 풀린 뒤로 바이크나 음악 얘기는 스스럼없이 툭툭 던질 만큼 편해졌다."
            else:
                relation_context = f"사실 {player_name}를 진심으로 좋아하는데 들키기 싫어서 더 무뚝뚝하게 군다. 가끔 걱정을 툭 던지듯 표현한다."

        else:
            persona = f"이름: {heroine_name}\n성격: 친절하고 다정하다.\n말투: 편안한 반말."
            relation_context = f"{player_name}와 평범한 친구 사이다."

        # 2. 시스템 프롬프트 — 긍정형 지시 + few-shot 중심(소형 로컬 모델 친화적, 빈 응답 최소화)
        system_prompt = (
            f"너는 한국 연애 시뮬레이션 게임의 히로인 '{heroine_name}'이다.\n"
            f"지금 {player_name}와 스마트폰 메신저(카카오톡)로 1:1 채팅을 하고 있다.\n"
            f"아래 [캐릭터 설정]의 성격과 '말투 예시'를 그대로 살려서, 진짜 그 사람이 보낸 카톡처럼 한국어로 답한다.\n\n"
            f"[캐릭터 설정]\n{persona}\n\n"
            f"[지금 관계]\n"
            f"- 상대: {player_name} (스토리 {current_day}일차, 호감도 {affection}/100)\n"
            f"- 상황: {relation_context}\n\n"
            f"[작성 규칙]\n"
            f"1. 카톡이니까 짧게. 보통 한 줄, 길어도 두 줄까지만 쓴다.\n"
            f"2. 괄호 안 행동·감정 묘사나 지문((웃으며), (당황하며) 같은 것)은 쓰지 말고, 말풍선에 들어갈 말만 쓴다.\n"
            f"3. 위 '말투 예시'의 어휘, 존댓말/반말, 이모지 사용 빈도를 그대로 유지한다.\n"
            f"4. 너는 진짜 사람이다. AI·언어모델·프롬프트 이야기는 절대 하지 않는다.\n"
            f"5. 상대 이름을 매 문장 반복하지 말고, 필요할 때만 자연스럽게 부른다.\n"
        )
        return system_prompt

    @staticmethod
    def get_llm_response(system_prompt: str, chat_history: list, user_message: str) -> str:
        # OpenAI 호환(ChatCompletions) 형식으로 메시지 구축 (백엔드는 로컬 Ollama 서버)
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
            "temperature": 0.8,
            "max_tokens": 200,
            # 💡 모델을 30분간 메모리에 상주시켜 콜드스타트(첫 응답 지연/공백)를 완화 (Ollama 확장 필드)
            "keep_alive": "30m",
        }
        data = json.dumps(payload).encode("utf-8")

        last_error = None
        # 💡 빈 응답(주로 모델 로딩 직후 첫 호출) 대비 최대 3회 재시도
        for attempt in range(3):
            try:
                req = urllib.request.Request(
                    LLM_API_URL,
                    data=data,
                    headers={"Content-Type": "application/json"},
                    method="POST"
                )
                # 타임아웃 300초 (CPU 구동이나 첫 모델 로드 시 지연 방지)
                with urllib.request.urlopen(req, timeout=300) as response:
                    res_json = json.loads(response.read().decode("utf-8"))
                    reply = (res_json["choices"][0]["message"].get("content") or "").strip()
                    if reply:
                        return reply
                    logger.warning(
                        f"⚠️ LLM 빈 응답 (시도 {attempt + 1}/3). 모델({LLM_MODEL_NAME}) 로딩 중이거나 "
                        f"리소스(VRAM) 부족일 수 있어 재시도합니다."
                    )
            except urllib.error.URLError as e:
                last_error = e
                logger.error(f"LLM API 연결 실패 (시도 {attempt + 1}/3, url: {LLM_API_URL}): {e}")
            except Exception as e:
                last_error = e
                logger.error(f"LLM 응답 처리 오류 (시도 {attempt + 1}/3): {e}")

        # 3회 모두 실패한 경우의 폴백
        if last_error is not None:
            logger.error(f"LLM 응답 최종 실패: {last_error}")
            return "(지금은 연결이 잘 안 되나 봐. 잠시 뒤에 다시 보낼게.)"
        return "(...왜 말이 잘 안 나오지. 잠깐만, 다시 말할게.)"
