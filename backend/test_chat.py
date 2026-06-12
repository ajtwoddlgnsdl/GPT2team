import os
import sys

# 프로젝트 루트를 path에 추가하여 app 모듈 임포트 가능케 함
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.chat_service import ChatService

def run_prompt_test():
    print("=== Heroine AI Chat System Prompt Test ===")

    
    player = "홍길동"
    
    # 1. 코토리 테스트
    kotori_low = ChatService.generate_system_prompt("코토리", player, affection=5, current_day=1, game_state="INTRO_2")
    kotori_high = ChatService.generate_system_prompt("코토리", player, affection=65, current_day=10, game_state="MAIN")
    
    # 2. 이서연 테스트
    seoyeon_low = ChatService.generate_system_prompt("이서연", player, affection=0, current_day=1, game_state="INTRO_2")
    seoyeon_high = ChatService.generate_system_prompt("이서연", player, affection=80, current_day=12, game_state="MAIN")
    
    # 3. 리안 테스트
    lian_low = ChatService.generate_system_prompt("리안", player, affection=2, current_day=1, game_state="INTRO_2")
    lian_high = ChatService.generate_system_prompt("리안", player, affection=75, current_day=11, game_state="MAIN")
    
    print("\n--- [1] 코토리 (호감도 낮음/극초반) ---")
    print(kotori_low)
    
    print("\n--- [2] 코토리 (호감도 높음/메인루트) ---")
    print(kotori_high)
    
    print("\n--- [3] 이서연 (호감도 낮음/극초반) ---")
    print(seoyeon_low)
    
    print("\n--- [4] 이서연 (호감도 높음/메인루트) ---")
    print(seoyeon_high)
    
    print("\n--- [5] 리안 (호감도 낮음/극초반) ---")
    print(lian_low)
    
    print("\n--- [6] 리안 (호감도 높음/메인루트) ---")
    print(lian_high)
    
    print("\n=== 프롬프트 구성 완료! ===")

if __name__ == "__main__":
    run_prompt_test()
