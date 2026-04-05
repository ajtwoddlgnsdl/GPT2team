from app.config import GameConfig, STORY_CONFIG, GameState

class GameLogicService:
    @staticmethod
    def calculate_penalty(user, all_heroines, offline_days):
        has_penalty = False
        if user.game_state == GameState.MAIN.value and offline_days >= GameConfig.PENALTY_DAYS_MIN:
            main_h = next((h for h in all_heroines if h.is_main == True), None)
            if main_h:
                drop_amount = GameConfig.PENALTY_DROP_MINOR if offline_days < GameConfig.PENALTY_DAYS_MAX else GameConfig.PENALTY_DROP_MAJOR
                main_h.affection = max(0, main_h.affection - drop_amount)
                has_penalty = True
        return has_penalty

    @staticmethod
    def process_daily_reset(user, all_heroines):
        ap_refill_needed = False
        
        if user.game_state == GameState.INTRO_2.value:
            old_max_day = max([h.current_day for h in all_heroines]) if all_heroines else 0
            for h in all_heroines:
                if h.is_cleared_today:
                    h.current_day += 1
                    h.is_cleared_today = False 
                    if h.current_day > old_max_day: 
                        ap_refill_needed = True

            new_max_day = max([h.current_day for h in all_heroines])
            if new_max_day == GameConfig.MAIN_START_DAY:
                user.game_state = GameState.MAIN.value
                candidates = [h for h in all_heroines if h.current_day == GameConfig.MAIN_START_DAY]
                if candidates:
                    best_heroine = max(candidates, key=lambda x: x.affection)
                    best_heroine.is_main = True

        elif user.game_state == GameState.MAIN.value:
            main_h = next((h for h in all_heroines if h.is_main == True), None)
            if main_h and main_h.is_cleared_today:
                config = STORY_CONFIG.get(main_h.heroine_name, {})
                req_zones = config.get("schedule", {}).get(str(main_h.current_day), [])
                
                viewed_zone_names = [vz.zone for vz in main_h.viewed_zones]
                
                if all(zone in viewed_zone_names for zone in req_zones):
                    main_h.current_day += 1
                    main_h.viewed_zones.clear() 
                    main_h.is_cleared_today = False
                    ap_refill_needed = True
                    
                    if main_h.current_day == config.get("end_day"):
                        user.game_state = GameState.END.value
                else:
                    main_h.is_cleared_today = False

            if main_h and user.game_state == GameState.MAIN.value:
                config = STORY_CONFIG.get(main_h.heroine_name, {})
                today_req = config.get("schedule", {}).get(str(main_h.current_day), [])
                if not today_req:
                    main_h.is_cleared_today = True
                    
        return ap_refill_needed