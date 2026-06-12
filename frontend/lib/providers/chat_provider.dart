import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../core/chat_db_helper.dart';
import '../core/api_client.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 💬 채팅 데이터 모델
// ══════════════════════════════════════════════════════════════════════════════

class ChatMessageModel {
  final int? id;
  final String heroineName;
  final String sender; // 'player' or 'heroine'
  final String messageText;
  final String timestamp;

  ChatMessageModel({
    this.id,
    required this.heroineName,
    required this.sender,
    required this.messageText,
    required this.timestamp,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['id'],
      heroineName: map['heroine_name'],
      sender: map['sender'],
      messageText: map['message_text'],
      timestamp: map['timestamp'],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 💬 채팅방 상태 모델 (대화 메시지, 모드, 타이핑 상태 등 통합 관리)
// ══════════════════════════════════════════════════════════════════════════════

enum ChatMode {
  scenario, // 미리 짜인 JSON 대본 진행 모드
  aiFreeChat, // AI 자유 대화 모드
}

class ChatRoomState {
  final List<ChatMessageModel> messages;
  final ChatMode mode;
  final bool isTyping; // 상대가 타이핑 중인지 (AI 대기)
  final int remainingFreeChats; // 오늘 남은 무료 채팅 수 (최대 10회)
  final bool isClearedToday; // 오늘 대본 모드를 완료했는지

  ChatRoomState({
    required this.messages,
    required this.mode,
    this.isTyping = false,
    this.remainingFreeChats = 10,
    this.isClearedToday = false,
  });

  ChatRoomState copyWith({
    List<ChatMessageModel>? messages,
    ChatMode? mode,
    bool? isTyping,
    int? remainingFreeChats,
    bool? isClearedToday,
  }) {
    return ChatRoomState(
      messages: messages ?? this.messages,
      mode: mode ?? this.mode,
      isTyping: isTyping ?? this.isTyping,
      remainingFreeChats: remainingFreeChats ?? this.remainingFreeChats,
      isClearedToday: isClearedToday ?? this.isClearedToday,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 💬 Notifier 구현 (Map 기반으로 각 히로인별 상태 관리)
// ══════════════════════════════════════════════════════════════════════════════

class ChatRoomNotifier extends Notifier<Map<String, ChatRoomState>> {
  final _db = ChatDbHelper();
  final _api = ApiClient();

  @override
  Map<String, ChatRoomState> build() {
    return {};
  }

  // 특정 히로인의 상태 안전 조회
  ChatRoomState getRoomState(String heroineName) {
    return state[heroineName] ?? ChatRoomState(messages: [], mode: ChatMode.aiFreeChat);
  }

  // 특정 히로인의 상태 업데이트
  void _updateRoomState(String heroineName, ChatRoomState roomState) {
    state = {
      ...state,
      heroineName: roomState,
    };
  }

  // 채팅방 로드 (메시지 이력 + 대본 모드 유효성 확인)
  Future<void> loadRoom(String heroineName, int currentDay, String currentTimeZone) async {
    try {
      // 1. 오늘 대본 모드 클리어 여부 확인
      final isCleared = await _db.isScriptCleared(heroineName, currentDay, currentTimeZone);

      // 2. 대본 파일 존재 여부 확인
      bool hasScript = false;
      try {
        final scriptPath = 'assets/scripts/chat_script/$heroineName/chat_day${currentDay}_$currentTimeZone.json';
        await rootBundle.load(scriptPath);
        hasScript = true;
      } catch (_) {
        hasScript = false;
      }

      final activeMode = (hasScript && !isCleared) ? ChatMode.scenario : ChatMode.aiFreeChat;

      // 3. 로컬 DB 메시지 이력 로드
      final rawMessages = await _db.getMessages(heroineName);
      final msgList = rawMessages.map((m) => ChatMessageModel.fromMap(m)).toList();

      // 4. 남은 무료 횟수 로드
      final limitKey = 'free_chats_${heroineName}_day$currentDay';
      final rawLimit = await _api.storage.read(key: limitKey);
      int remaining = 10;
      if (rawLimit != null) {
        remaining = int.tryParse(rawLimit) ?? 10;
      } else {
        await _api.storage.write(key: limitKey, value: '10');
      }

      _updateRoomState(
        heroineName,
        ChatRoomState(
          messages: msgList,
          mode: activeMode,
          remainingFreeChats: remaining,
          isClearedToday: isCleared,
        ),
      );
    } catch (e) {
      debugPrint("🚨 loadRoom 에러 발생: $e");
      // 에러 발생 시 앱 프리징 방지를 위해 기본 자유대화 모드로 상태 초기화
      _updateRoomState(
        heroineName,
        ChatRoomState(
          messages: [],
          mode: ChatMode.aiFreeChat,
          remainingFreeChats: 10,
          isClearedToday: false,
        ),
      );
    }
  }

  // 시나리오 대본 모드 완료 처리
  Future<void> completeScenarioMode(String heroineName, int currentDay, String currentTimeZone) async {
    await _db.markScriptCleared(heroineName, currentDay, currentTimeZone);
    
    final currentRoom = getRoomState(heroineName);
    _updateRoomState(
      heroineName,
      currentRoom.copyWith(
        mode: ChatMode.aiFreeChat,
        isClearedToday: true,
      ),
    );
  }

  // 스토리 진행으로 인한 채팅 리셋 처리
  Future<void> resetHistory(String heroineName) async {
    await _db.clearHistory(heroineName);
    
    final currentRoom = getRoomState(heroineName);
    _updateRoomState(
      heroineName,
      currentRoom.copyWith(messages: []),
    );
  }

  // 메시지 로컬 DB 추가
  Future<void> saveLocalMessage(String heroineName, String sender, String text) async {
    await _db.insertMessage(heroineName, sender, text);
    
    // 상태 갱신
    final rawMessages = await _db.getMessages(heroineName);
    final msgList = rawMessages.map((m) => ChatMessageModel.fromMap(m)).toList();
    
    final currentRoom = getRoomState(heroineName);
    _updateRoomState(
      heroineName,
      currentRoom.copyWith(messages: msgList),
    );
  }

  // AI 메시지 전송 및 답변 처리
  Future<bool> sendChatMessage(String heroineName, String text, int currentDay) async {
    final currentRoom = getRoomState(heroineName);
    if (currentRoom.remainingFreeChats <= 0) {
      return false; // 무료 횟수 소진
    }

    // 1. 유저 메시지 저장
    await saveLocalMessage(heroineName, 'player', text);

    // 2. 타이핑 애니메이션 활성화 및 무료 횟수 차감
    final afterUserSendRoom = getRoomState(heroineName);
    _updateRoomState(
      heroineName,
      afterUserSendRoom.copyWith(
        isTyping: true,
        remainingFreeChats: afterUserSendRoom.remainingFreeChats - 1,
      ),
    );

    // 차감된 횟수 보관
    final limitKey = 'free_chats_${heroineName}_day$currentDay';
    final updatedRoom = getRoomState(heroineName);
    await _api.storage.write(key: limitKey, value: updatedRoom.remainingFreeChats.toString());

    // 3. 서버 전송용 최근 N개 대화 컨텍스트 조회
    final contextHistory = await _db.getRecentContext(heroineName, limit: 10);

    try {
      // 4. API 전송
      final response = await _api.dio.post(
        '/chat/send',
        data: {
          'heroine_name': heroineName,
          'message': text,
          'chat_history': contextHistory,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final reply = response.data['reply'] as String;

        // 5. 히로인 답변 저장
        await saveLocalMessage(heroineName, 'heroine', reply);
      } else {
        await saveLocalMessage(heroineName, 'heroine', "(연락이 닿지 않는 것 같다...)");
      }
    } catch (e) {
      debugPrint("🚨 AI 채팅 통신 에러: $e");
      await saveLocalMessage(heroineName, 'heroine', "(연락이 닿지 않는 것 같다...)");
    } finally {
      final finalRoom = getRoomState(heroineName);
      _updateRoomState(
        heroineName,
        finalRoom.copyWith(isTyping: false),
      );
    }

    return true;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 💬 Provider 노출 (NotifierProvider 활용)
// ══════════════════════════════════════════════════════════════════════════════

final chatRoomProvider = NotifierProvider<ChatRoomNotifier, Map<String, ChatRoomState>>(() {
  return ChatRoomNotifier();
});
