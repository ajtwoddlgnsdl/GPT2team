import 'dart:convert';
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
  final int isRead; // 0=unread, 1=read

  ChatMessageModel({
    this.id,
    required this.heroineName,
    required this.sender,
    required this.messageText,
    required this.timestamp,
    this.isRead = 1,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['id'],
      heroineName: map['heroine_name'],
      sender: map['sender'],
      messageText: map['message_text'],
      timestamp: map['timestamp'],
      isRead: map['is_read'] ?? 1,
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
  final int unreadCount; // 안 읽은 메시지 개수

  ChatRoomState({
    required this.messages,
    required this.mode,
    this.isTyping = false,
    this.remainingFreeChats = 10,
    this.isClearedToday = false,
    this.unreadCount = 0,
  });

  ChatRoomState copyWith({
    List<ChatMessageModel>? messages,
    ChatMode? mode,
    bool? isTyping,
    int? remainingFreeChats,
    bool? isClearedToday,
    int? unreadCount,
  }) {
    return ChatRoomState(
      messages: messages ?? this.messages,
      mode: mode ?? this.mode,
      isTyping: isTyping ?? this.isTyping,
      remainingFreeChats: remainingFreeChats ?? this.remainingFreeChats,
      isClearedToday: isClearedToday ?? this.isClearedToday,
      unreadCount: unreadCount ?? this.unreadCount,
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

      // 4. 안 읽은 메시지 수 로드
      final unread = await _db.getUnreadCount(heroineName);

      // 5. 남은 무료 횟수 로드
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
          unreadCount: unread,
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
          unreadCount: 0,
        ),
      );
    }
  }

  // 안 읽은 메시지 읽음 처리 및 상태 갱신
  Future<void> markAsRead(String heroineName) async {
    await _db.markMessagesAsRead(heroineName);
    
    final currentRoom = getRoomState(heroineName);
    final rawMessages = await _db.getMessages(heroineName);
    final msgList = rawMessages.map((m) => ChatMessageModel.fromMap(m)).toList();

    _updateRoomState(
      heroineName,
      currentRoom.copyWith(
        messages: msgList,
        unreadCount: 0,
      ),
    );
  }

  // 특정 히로인의 대기 중인 선물/자유 메시지 키 생성 (시나리오 진행 중인 동안 큐잉용)
  String _getPendingGiftsKey(String heroineName) {
    return 'pending_gifts_$heroineName';
  }

  // 대기 중인 메시지 가져오기
  Future<List<Map<String, dynamic>>> _getPendingGifts(String heroineName) async {
    final key = _getPendingGiftsKey(heroineName);
    final raw = await _api.storage.read(key: key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // 대기 중인 메시지 저장
  Future<void> _savePendingGifts(String heroineName, List<Map<String, dynamic>> gifts) async {
    final key = _getPendingGiftsKey(heroineName);
    await _api.storage.write(key: key, value: jsonEncode(gifts));
  }

  // 시나리오 대본 모드 완료 처리
  Future<void> completeScenarioMode(String heroineName, int currentDay, String currentTimeZone) async {
    await _db.markScriptCleared(heroineName, currentDay, currentTimeZone);
    
    // 시나리오 모드가 해제되었으므로 대기 중이던 선물 등의 메시지를 로컬 DB에 순서대로 추가합니다.
    final pending = await _getPendingGifts(heroineName);
    if (pending.isNotEmpty) {
      debugPrint("🎁 [선물 메시지 플러시] 대기 중이던 메시지 ${pending.length}개를 DB에 저장합니다.");
      for (final msg in pending) {
        final sender = msg['sender'] as String;
        final text = msg['text'] as String;
        final isRead = msg['is_read'] as int? ?? 1;
        // isPriority: true를 주어 대기 큐에 다시 들어가지 않고 직접 DB에 저장되도록 합니다.
        await saveLocalMessage(heroineName, sender, text, isRead: isRead, isPriority: true);
      }
      await _savePendingGifts(heroineName, []);
    }

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
    await _savePendingGifts(heroineName, []);
    
    final currentRoom = getRoomState(heroineName);
    _updateRoomState(
      heroineName,
      currentRoom.copyWith(messages: [], unreadCount: 0),
    );
  }

  // 메시지 로컬 DB 추가
  Future<void> saveLocalMessage(String heroineName, String sender, String text, {int isRead = 1, bool isPriority = false}) async {
    final currentRoom = getRoomState(heroineName);
    
    // 💡 시나리오 진행 모드 중이고 우선순위(시나리오 대사)가 아닌 일반 메시지/선물은 큐에 임시 저장
    if (currentRoom.mode == ChatMode.scenario && !isPriority) {
      final pending = await _getPendingGifts(heroineName);
      pending.add({
        'sender': sender,
        'text': text,
        'is_read': isRead,
      });
      await _savePendingGifts(heroineName, pending);
      debugPrint("🎁 [선물 메시지 대기] 시나리오 진행 중이므로 메시지를 임시 저장합니다: $text");
      return;
    }

    await _db.insertMessage(heroineName, sender, text, isRead: isRead);
    
    // 상태 갱신
    final rawMessages = await _db.getMessages(heroineName);
    final msgList = rawMessages.map((m) => ChatMessageModel.fromMap(m)).toList();
    final unread = await _db.getUnreadCount(heroineName);
    
    _updateRoomState(
      heroineName,
      currentRoom.copyWith(
        messages: msgList,
        unreadCount: unread,
      ),
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
