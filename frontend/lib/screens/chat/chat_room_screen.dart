import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/chat_provider.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String heroineName;
  final int currentDay;
  final String currentTimeZone;

  const ChatRoomScreen({
    super.key,
    required this.heroineName,
    required this.currentDay,
    required this.currentTimeZone,
  });

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 시나리오 관련 로컬 상태
  List<dynamic> _scenarioLines = [];
  int _scenarioIndex = 0;
  bool _scenarioLoading = false;
  bool _isChoiceMode = false;
  List<dynamic> _currentChoices = [];

  // 💡 자동 시나리오 재생 관련 타이머 및 상태
  Timer? _scenarioTimer;
  bool _isScenarioTyping = false;

  // 화면에 임시로 노출되는 시나리오 대화 리스트
  final List<Map<String, String>> _visibleScenarioBubbles = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(chatRoomProvider.notifier);
      await notifier.loadRoom(widget.heroineName, widget.currentDay, widget.currentTimeZone);
      await notifier.markAsRead(widget.heroineName);

      final roomState = ref.read(chatRoomProvider.notifier).getRoomState(widget.heroineName);
      if (roomState.mode == ChatMode.scenario) {
        _loadScenarioScript();
      }
    });
  }

  // 1. 시나리오 JSON 로드
  Future<void> _loadScenarioScript() async {
    setState(() => _scenarioLoading = true);
    final hName = widget.heroineName;
    final day = widget.currentDay;
    final tz = widget.currentTimeZone;
    final filePath = 'assets/scripts/chat_script/$hName/chat_day${day}_$tz.json';

    try {
      final jsonString = await rootBundle.loadString(filePath);
      final list = jsonDecode(jsonString) as List<dynamic>;
      setState(() {
        _scenarioLines = list;
        _scenarioIndex = 0;
        _scenarioLoading = false;
        _visibleScenarioBubbles.clear();
      });
      // 첫 라인 시작
      _playNextScenarioLine();
    } catch (e) {
      debugPrint("🚨 시나리오 파일 읽기 실패 ($filePath): $e");
      // 대본 파일 읽기 실패 시 강제 자유대화 모드로 탈출
      await ref.read(chatRoomProvider.notifier).completeScenarioMode(hName, day, tz);
      setState(() => _scenarioLoading = false);
    }
  }

  // 2. 시나리오 라인 한 줄씩 출력 (자동 진행 및 말풍선 타이핑 대기 효과 적용)
  void _playNextScenarioLine() {
    if (_scenarioIndex >= _scenarioLines.length) {
      _finishScenario();
      return;
    }

    final line = _scenarioLines[_scenarioIndex] as Map<String, dynamic>;

    if (line.containsKey('action')) {
      if (line['action'] == 'choice') {
        setState(() {
          _isChoiceMode = true;
          _currentChoices = line['choices'];
        });
        _scrollToBottom();
        return;
      }
    }

    // 닉네임 교환 처리 등 변수 매핑
    final speaker = line['speaker'] as String? ?? '';
    final text = (line['text'] as String? ?? '').replaceAll('{name}', '주인공');

    // 말하는 사람이 주인공인지 히로인인지 구별
    final sender = (speaker == '' || speaker == '{name}' || speaker == '주인공') ? 'player' : 'heroine';

    if (sender == 'heroine') {
      // 히로인이 말하는 차례: 타이핑 인디케이터 표시 후 대사 출력
      setState(() {
        _isScenarioTyping = true;
      });
      _scrollToBottom();

      // 글자 수에 맞추어 유동적인 대기 시간 산출 (글자당 40ms, 최소 1.2초, 최대 2.5초)
      final delayMs = (text.length * 40).clamp(1200, 2500);

      _scenarioTimer?.cancel();
      _scenarioTimer = Timer(Duration(milliseconds: delayMs), () {
        if (!mounted) return;
        setState(() {
          _isScenarioTyping = false;
          _visibleScenarioBubbles.add({
            'sender': sender,
            'text': text,
          });
          _scenarioIndex++;
        });
        _scrollToBottom();
        
        // 1.5초 대기 후 자동으로 다음 대사 진행
        _scheduleNextScenarioLine(1500);
      });
    } else {
      // 주인공이 혼잣말을 하거나 답변하는 차례: 타이핑 인디케이터 없이 침묵 딜레이 후 노출
      _scenarioTimer?.cancel();
      _scenarioTimer = Timer(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() {
          _visibleScenarioBubbles.add({
            'sender': sender,
            'text': text,
          });
          _scenarioIndex++;
        });
        _scrollToBottom();

        // 1.5초 대기 후 자동으로 다음 대사 진행
        _scheduleNextScenarioLine(1500);
      });
    }
  }

  // 💡 다음 시나리오 진행 스케줄링 헬퍼
  void _scheduleNextScenarioLine(int delayMs) {
    _scenarioTimer?.cancel();
    _scenarioTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      final chatRooms = ref.read(chatRoomProvider);
      final roomState = chatRooms[widget.heroineName];
      if (roomState != null && roomState.mode == ChatMode.scenario && !_isChoiceMode) {
        _playNextScenarioLine();
      }
    });
  }

  // 3. 시나리오 선택지 선택 처리
  void _onChoiceSelected(Map<String, dynamic> choice) {
    final text = (choice['text'] as String? ?? '').replaceAll('{name}', '주인공');

    setState(() {
      _visibleScenarioBubbles.add({
        'sender': 'player',
        'text': text,
      });
      _isChoiceMode = false;
      _currentChoices = [];

      // 선택지 하위 대사 삽입
      if (choice.containsKey('next_lines')) {
        final nextLines = choice['next_lines'] as List<dynamic>;
        _scenarioLines.insertAll(_scenarioIndex + 1, nextLines);
      }
    });

    _scenarioIndex++;
    _scrollToBottom();
    
    // 💡 선택 완료 후 다음 라인 자동 스케줄링 실행
    _scheduleNextScenarioLine(800);
  }

  // 4. 시나리오 완료 후 자유대화 모드 안착
  Future<void> _finishScenario() async {
    final notifier = ref.read(chatRoomProvider.notifier);
    
    // 1) 대본 대화 내용을 기기 SQLite 로컬 DB에 영구 저장
    for (final b in _visibleScenarioBubbles) {
      await notifier.saveLocalMessage(widget.heroineName, b['sender']!, b['text']!, isPriority: true);
    }

    // 2) 클리어 기록 저장 및 모드 변경
    await notifier.completeScenarioMode(widget.heroineName, widget.currentDay, widget.currentTimeZone);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('시나리오가 완료되었습니다. 이제 자유 대화가 가능합니다.'),
          backgroundColor: Color(0xFF6D574A),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // 5. 스크롤 제어
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 6. 히로인별 테마 칼라 추출
  Color _getPrimaryColor() {
    switch (widget.heroineName) {
      case "코토리":
        return const Color(0xFFFFB7B2); // 벚꽃 연분홍
      case "이서연":
        return const Color(0xFF457B9D); // 세련된 스틸블루
      case "리안":
        return const Color(0xFFF4A261); // 빈티지 오렌지
      default:
        return const Color(0xFF5F4A41);
    }
  }

  Color _getBubbleColor(String sender) {
    final primary = _getPrimaryColor();
    if (sender == 'player') {
      return primary.withValues(alpha: 0.85);
    } else {
      return Colors.white;
    }
  }

  Color _getTextColor(String sender) {
    if (sender == 'player') {
      return Colors.white;
    } else {
      return const Color(0xFF2D2420);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatRooms = ref.watch(chatRoomProvider);
    final roomState = chatRooms[widget.heroineName] ?? ChatRoomState(messages: [], mode: ChatMode.aiFreeChat);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F0), // 부드러운 연한 미색 배경
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF5F4A41)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.heroineName,
              style: const TextStyle(
                color: Color(0xFF5F4A41),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (roomState.mode == ChatMode.aiFreeChat)
              Text(
                '오늘 남은 대화: ${roomState.remainingFreeChats}회',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              const Text(
                '시나리오 대본 모드 진행 중',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
      body: GestureDetector(
        // 자동 재생되므로 수동 터치 반응 비활성화
        onTap: null,
        child: Column(
          children: [
            // 메시지 리스트
            Expanded(
              child: _scenarioLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMessageList(roomState),
            ),

            // 선택지 패널 (대본 모드 선택지 출력 시 노출)
            if (_isChoiceMode && roomState.mode == ChatMode.scenario)
              _buildChoicesOverlay(),

            // 하단 입력 창
            _buildBottomBar(roomState),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ChatRoomState roomState) {
    final isScenario = roomState.mode == ChatMode.scenario;
    final count = isScenario ? _visibleScenarioBubbles.length : roomState.messages.length;
    final primaryColor = _getPrimaryColor();
    final isTyping = isScenario ? _isScenarioTyping : roomState.isTyping;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: count + (isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == count) {
          // 타이핑 인디케이터
          return _buildTypingIndicator();
        }

        final String sender;
        final String text;

        if (isScenario) {
          final b = _visibleScenarioBubbles[index];
          sender = b['sender']!;
          text = b['text']!;
        } else {
          final m = roomState.messages[index];
          sender = m.sender;
          text = m.messageText;
        }

        final isPlayer = sender == 'player';

        // 💡 선물 메시지 여부 판단 및 정보 파싱
        String displayText = text;
        String? giftId;
        if (isPlayer && text.startsWith('[선물:') && text.contains(']')) {
          final closeIndex = text.indexOf(']');
          giftId = text.substring(5, closeIndex);
          displayText = text.substring(closeIndex + 1).trim();
        }

        final isGift = giftId != null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: isPlayer ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPlayer) ...[
                const SizedBox(width: 48), // 💡 플레이어 말풍선 왼쪽에 공백 확보 (왼쪽 끝까지 차지 않게 함)
              ],
              if (!isPlayer) ...[
                // 히로인 아바타 아이콘
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: 0.3),
                  ),
                  child: Center(
                    child: Text(
                      widget.heroineName[0],
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // 말풍선
              Flexible(
                child: Container(
                  padding: isGift
                      ? const EdgeInsets.all(8)
                      : const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: isGift ? const Color(0xFFFFF2EE) : _getBubbleColor(sender),
                    border: isGift
                        ? Border.all(color: const Color(0xFFFFDEC9), width: 1.2)
                        : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isPlayer ? const Radius.circular(16) : const Radius.circular(4),
                      bottomRight: isPlayer ? const Radius.circular(4) : const Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: isGift
                      ? _buildGiftCard(giftId, displayText)
                      : Text(
                          displayText,
                          style: TextStyle(
                            color: _getTextColor(sender),
                            fontSize: 14.5,
                            height: 1.35,
                            fontFamilyFallback: const [
                              'Apple Color Emoji',
                              'Noto Color Emoji',
                              'Segoe UI Emoji',
                              'EmojiOne Color',
                            ],
                          ),
                        ),
                ),
              ),
              if (!isPlayer) ...[
                const SizedBox(width: 48), // 💡 히로인 말풍선 오른쪽에 공백 확보 (오른쪽 끝까지 차지 않게 함)
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildGiftCard(String giftId, String text) {
    String giftName = "선물";
    IconData giftIcon = Icons.card_giftcard_outlined;
    List<Color> colors = const [Color(0xFFFFC6FF), Color(0xFFFFADAD)];

    switch (giftId) {
      case "test_item":
        giftName = "테스트용 막대사탕";
        giftIcon = Icons.circle_rounded;
        colors = const [Color(0xFFFFC6FF), Color(0xFFFFD6A5)];
        break;
      case "coffee":
        giftName = "스타벅스 아메리카노";
        giftIcon = Icons.local_cafe_outlined;
        colors = const [Color(0xFFE6CCB2), Color(0xFFB08968)];
        break;
      case "chocolate":
        giftName = "달콤한 초콜릿 상자";
        giftIcon = Icons.cookie_outlined;
        colors = const [Color(0xFFFFADAD), Color(0xFFFF85A1)];
        break;
      case "macaron":
        giftName = "고급 마카롱 세트";
        giftIcon = Icons.cake_outlined;
        colors = const [Color(0xFFFDFFB6), Color(0xFFFFD6A5)];
        break;
      case "teddy":
        giftName = "포근한 곰 인형";
        giftIcon = Icons.toys_outlined;
        colors = const [Color(0xFFCAFFBF), Color(0xFF96E072)];
        break;
      case "perfume":
        giftName = "명품 향수";
        giftIcon = Icons.spa_outlined;
        colors = const [Color(0xFFBDB2FF), Color(0xFF9BF6FF)];
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7F2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(giftIcon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎁 GIFT CARD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE85D75),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      giftName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2D2420),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF5F4A41),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    final primaryColor = _getPrimaryColor();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withValues(alpha: 0.3),
            ),
            child: Center(
              child: Text(
                widget.heroineName[0],
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(150),
                const SizedBox(width: 4),
                _buildDot(300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int delay) {
    return _DotAnimation(delay: delay);
  }

  Widget _buildChoicesOverlay() {
    final primaryColor = _getPrimaryColor();
    return Container(
      color: Colors.black.withValues(alpha: 0.05),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _currentChoices.map((choice) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2D2420),
                  elevation: 1.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: primaryColor.withValues(alpha: 0.4), width: 1),
                  ),
                ),
                onPressed: () => _onChoiceSelected(choice),
                child: Text(
                  choice['text'] as String? ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomBar(ChatRoomState roomState) {
    final isScenario = roomState.mode == ChatMode.scenario;
    final isLimitReached = roomState.remainingFreeChats <= 0;
    final primaryColor = _getPrimaryColor();

    String hintText = "메시지를 입력하세요...";
    bool isEnabled = true;

    if (isScenario) {
      hintText = "대본을 읽는 중입니다. 화면을 탭하세요.";
      isEnabled = false;
    } else if (isLimitReached) {
      hintText = "오늘의 대화 가능 횟수를 소진했습니다.";
      isEnabled = false;
    } else if (roomState.isTyping) {
      hintText = "${widget.heroineName}님이 입력 중입니다...";
      isEnabled = false;
    }

    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F1ED),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _messageController,
                enabled: isEnabled,
                style: const TextStyle(fontSize: 14.5, color: Color(0xFF2D2420)),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13.5),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMsg(roomState),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isEnabled ? () => _sendMsg(roomState) : null,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isEnabled ? primaryColor : Colors.grey[300],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          )
        ],
      ),
    );
  }

  void _sendMsg(ChatRoomState roomState) async {
    final text = _messageController.text.trim();
    if (text.isEmpty || roomState.remainingFreeChats <= 0) return;

    _messageController.clear();
    _scrollToBottom();

    final success = await ref
        .read(chatRoomProvider.notifier)
        .sendChatMessage(widget.heroineName, text, widget.currentDay);

    if (success) {
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _scenarioTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// 쩜쩜쩜 애니메이션용 커스텀 위젯
class _DotAnimation extends StatefulWidget {
  final int delay;
  const _DotAnimation({required this.delay});

  @override
  State<_DotAnimation> createState() => _DotAnimationState();
}

class _DotAnimationState extends State<_DotAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _animation = Tween<double>(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_animation.value),
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
