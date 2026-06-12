import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../core/api_client.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 🃏 카드 데이터 모델
// ══════════════════════════════════════════════════════════════════════════════

class _CardData {
  final int pairId;
  final IconData icon;
  final Color color;
  bool isFlipped = false;
  bool isMatched = false;
  bool isBouncing = false;

  _CardData({required this.pairId, required this.icon, required this.color});
}

// ══════════════════════════════════════════════════════════════════════════════
// 📚 대학 과목 (Stage) 설정 모델
// ══════════════════════════════════════════════════════════════════════════════

class _StageConfig {
  final int stage;
  final String title;
  final String subTitle;
  final int cols;
  final int rows;
  final int reward;

  const _StageConfig({
    required this.stage,
    required this.title,
    required this.subTitle,
    required this.cols,
    required this.rows,
    required this.reward,
  });

  int get totalCards => cols * rows;
  int get pairCount => totalCards ~/ 2;
}

// 5단계 과목 스케줄 정의 (E-class 과제 매핑)
const List<_StageConfig> _stages = [
  _StageConfig(stage: 1, title: "컴퓨터 아키텍처 과제", subTitle: "초급 실습 (2 x 2)", cols: 2, rows: 2, reward: 50),
  _StageConfig(stage: 2, title: "데이터 구조 실습", subTitle: "중급 코딩 (3 x 4)", cols: 3, rows: 4, reward: 100),
  _StageConfig(stage: 3, title: "객체지향 프로그래밍 퀴즈", subTitle: "중급 퀴즈 (4 x 4)", cols: 4, rows: 4, reward: 150),
  _StageConfig(stage: 4, title: "인공지능 입문 레포트", subTitle: "고급 레포트 (4 x 5)", cols: 4, rows: 5, reward: 200),
  _StageConfig(stage: 5, title: "졸업 프로젝트 대체 과제", subTitle: "최고난도 프로젝트 (6 x 5)", cols: 6, rows: 5, reward: 250),
];

// 카드 앞면에 사용할 대학교/과제 생활 테마 아이콘 + 색상 풀
const List<Map<String, dynamic>> _iconPool = [
  {'icon': Icons.menu_book_rounded, 'color': Color(0xFF5B8DEF)}, // 전공서적 - 블루
  {'icon': Icons.laptop_mac_rounded, 'color': Color(0xFF42A5F5)}, // 코딩 노트북 - 라이트블루
  {'icon': Icons.local_cafe_rounded, 'color': Color(0xFF8D6E63)}, // 밤샘커피 - 브라운
  {'icon': Icons.edit_note_rounded, 'color': Color(0xFFFF7043)}, // 레포트 작성 - 오렌지
  {'icon': Icons.alarm_rounded, 'color': Color(0xFFE85D75)}, // 마감기한 - 레드
  {'icon': Icons.school_rounded, 'color': Color(0xFF9C27B0)}, // 학사모(졸업) - 보라
  {'icon': Icons.lightbulb_rounded, 'color': Color(0xFFFFCA28)}, // 아이디어 - 옐로우
  {'icon': Icons.analytics_rounded, 'color': Color(0xFF00BFA5)}, // 발표자료 - 민트
  {'icon': Icons.workspace_premium_rounded, 'color': Color(0xFFFF8A80)}, // A+ 성적 - 핑크
  {'icon': Icons.import_contacts_rounded, 'color': Color(0xFF66BB6A)}, // 노트정리 - 그린
  {'icon': Icons.terminal_rounded, 'color': Color(0xFF26A69A)}, // 실습실 터미널 - 에메랄드
  {'icon': Icons.calculate_rounded, 'color': Color(0xFFAB47BC)}, // 전공수학 계산 - 연보라
  {'icon': Icons.draw_rounded, 'color': Color(0xFFEC407A)}, // 설계 드로잉 - 체리
  {'icon': Icons.science_rounded, 'color': Color(0xFF26C6DA)}, // 화학/물리 실험 - 시안
  {'icon': Icons.group_work_rounded, 'color': Color(0xFF78909C)}, // 조별과제 - 그레이
];

// ══════════════════════════════════════════════════════════════════════════════
// 🏫 미니게임 메인 위젯
// ══════════════════════════════════════════════════════════════════════════════

class MinigameScreen extends StatefulWidget {
  final int actionPoints;
  final int currentDay;
  final VoidCallback onClose;
  final Function(int earnedMoney)? onRewardEarned;
  final Function(int newAP)? onAPChanged;

  // 당일 클리어한 과제 목록 누적용 static 변수
  static final Set<int> clearedStagesToday = {};
  static int lastOpenedDay = -1;

  const MinigameScreen({
    super.key,
    required this.actionPoints,
    required this.currentDay,
    required this.onClose,
    this.onRewardEarned,
    this.onAPChanged,
  });

  @override
  State<MinigameScreen> createState() => _MinigameScreenState();
}

class _MinigameScreenState extends State<MinigameScreen>
    with TickerProviderStateMixin {
  final ApiClient _api = ApiClient();

  // 게임 상태
  int _currentAP = 0;
  int _currentLevel = 0; // 0 = 메인 화면, 1~5 = 게임 진행 중
  bool _isPreviewing = false;
  bool _isProcessing = false; // 카드 비교 중 입력 잠금
  List<_CardData> _cards = [];
  List<int> _flippedIndices = [];
  int _totalEarned = 0; // 이번 세션에서 번 돈 누적

  // 타이머
  late AnimationController _timerCtrl;

  // 미리보기 타이머 (3초, 빨간색)
  late AnimationController _previewTimerCtrl;

  // 카드 플립 애니메이션 컨트롤러 (각 카드별)
  final Map<int, AnimationController> _flipControllers = {};

  @override
  void initState() {
    super.initState();
    _currentAP = widget.actionPoints;

    // 날짜가 바뀐 경우 당일 과제 이수 내역 초기화
    if (MinigameScreen.lastOpenedDay != widget.currentDay) {
      MinigameScreen.lastOpenedDay = widget.currentDay;
      MinigameScreen.clearedStagesToday.clear();
    }

    _timerCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 30))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _handleTimeUp();
            }
          });
    _previewTimerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _timerCtrl.dispose();
    _previewTimerCtrl.dispose();
    for (final ctrl in _flipControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // ── API 호출 ──

  Future<bool> _callStartAPI() async {
    try {
      final res = await _api.dio.post(
        '/minigame/start',
        data: {'game_type': 'card_match'},
      );
      final data = res.data;
      if (data['status'] == 'success') {
        setState(() => _currentAP = data['current_ap']);
        widget.onAPChanged?.call(data['current_ap'] as int);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('🚨 minigame/start 에러: $e');
      return false;
    }
  }

  Future<void> _callRewardAPI(int clearedLevel) async {
    try {
      final res = await _api.dio.post(
        '/minigame/reward',
        data: {'game_type': 'card_match', 'cleared_level': clearedLevel},
      );
      final data = res.data;
      if (data['status'] == 'success') {
        final earned = data['earned_money'] as int;
        _totalEarned += earned;
        widget.onRewardEarned?.call(earned);
      }
    } catch (e) {
      debugPrint('🚨 minigame/reward 에러: $e');
    }
  }

  // ── 게임 플로우 ──

  Future<void> _startGameForStage(int stage) async {
    if (_currentAP < 1) {
      _showAPDialog();
      return;
    }

    final ok = await _callStartAPI();
    if (!ok) {
      _showAPDialog();
      return;
    }

    _startLevel(stage);
  }

  void _startLevel(int level) {
    // 이전 플립 컨트롤러 정리
    for (final ctrl in _flipControllers.values) {
      ctrl.dispose();
    }
    _flipControllers.clear();

    final config = _stages[level - 1];
    final rng = Random();

    // 아이콘 풀에서 필요한 만큼 선택
    final shuffledIcons = List.of(_iconPool)..shuffle(rng);
    final selected = shuffledIcons.take(config.pairCount).toList();

    // 카드 쌍 생성 후 셔플
    List<_CardData> cards = [];
    for (int i = 0; i < selected.length; i++) {
      final entry = selected[i];
      cards.add(
        _CardData(
          pairId: i,
          icon: entry['icon'] as IconData,
          color: entry['color'] as Color,
        ),
      );
      cards.add(
        _CardData(
          pairId: i,
          icon: entry['icon'] as IconData,
          color: entry['color'] as Color,
        ),
      );
    }
    cards.shuffle(rng);

    // 각 카드에 대해 플립 컨트롤러 생성
    for (int i = 0; i < cards.length; i++) {
      _flipControllers[i] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 275),
      );
    }

    setState(() {
      _currentLevel = level;
      _cards = cards;
      _flippedIndices = [];
      _isProcessing = false;
      _isPreviewing = true;
    });

    // 미리보기: 모든 카드를 앞면으로 표시
    for (final card in _cards) {
      card.isFlipped = true;
    }
    for (final ctrl in _flipControllers.values) {
      ctrl.value = 1.0; // 즉시 앞면
    }

    // 미리보기 타이머 시작 (3초 빨간색 바)
    _previewTimerCtrl.forward(from: 0.0);

    // 3초 후 뒤집기
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || _currentLevel != level) return;
      setState(() {
        for (final card in _cards) {
          if (!card.isMatched) card.isFlipped = false;
        }
        _isPreviewing = false;
      });
      // 카드 뒤집기 애니메이션
      for (final ctrl in _flipControllers.values) {
        ctrl.reverse();
      }
      // 게임 타이머 시작
      _timerCtrl.forward(from: 0.0);
    });
  }

  void _onCardTapped(int index) async {
    if (_isPreviewing || _isProcessing) return;
    if (_cards[index].isFlipped || _cards[index].isMatched) return;
    if (_flippedIndices.length >= 2) return;

    setState(() {
      _cards[index].isFlipped = true;
      _flippedIndices.add(index);
    });
    // 플립 애니메이션 시작 후 완료까지 대기
    await _flipControllers[index]?.forward();

    if (_flippedIndices.length == 2) {
      _isProcessing = true;
      final idx1 = _flippedIndices[0];
      final idx2 = _flippedIndices[1];

      // 두 카드 모두 완전히 뒤집힐 때까지 대기
      await Future.wait([
        _flipControllers[idx1]?.forward() ?? Future.value(),
        _flipControllers[idx2]?.forward() ?? Future.value(),
      ]);

      if (_cards[idx1].pairId == _cards[idx2].pairId) {
        // 매칭 성공
        setState(() {
          _cards[idx1].isMatched = true;
          _cards[idx1].isBouncing = true;
          _cards[idx2].isMatched = true;
          _cards[idx2].isBouncing = true;
          _flippedIndices.clear();
          _isProcessing = false;
        });
        // 바운스 해제 (200ms 후 원래 크기로)
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              _cards[idx1].isBouncing = false;
              _cards[idx2].isBouncing = false;
            });
          }
        });
        _checkLevelClear();
      } else {
        // 오답: 유저가 확인할 수 있도록 잠시 보여준 후 뒤집기
        await Future.delayed(const Duration(milliseconds: 150));
        if (!mounted) return;
        setState(() {
          _cards[idx1].isFlipped = false;
          _cards[idx2].isFlipped = false;
          _flippedIndices.clear();
        });
        _flipControllers[idx1]?.reverse();
        await _flipControllers[idx2]?.reverse();
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  void _checkLevelClear() async {
    final allMatched = _cards.every((c) => c.isMatched);
    if (!allMatched) return;

    _timerCtrl.stop();
    await _callRewardAPI(_currentLevel);

    if (!mounted) return;

    // 해당 과목(Stage) 이수 완료 처리
    MinigameScreen.clearedStagesToday.add(_currentLevel);

    if (_currentLevel >= 5) {
      // 전체 클리어
      _showResultDialog(cleared: true, finalLevel: 5);
    } else {
      // 개별 단계 클리어 다이얼로그 노출
      _showLevelClearDialog();
    }
  }

  void _handleTimeUp() {
    if (_currentLevel == 0) return;
    _timerCtrl.stop();
    _showResultDialog(cleared: false, finalLevel: _currentLevel);
  }

  void _returnToMenu() {
    _timerCtrl.stop();
    _timerCtrl.reset();
    for (final ctrl in _flipControllers.values) {
      ctrl.dispose();
    }
    _flipControllers.clear();
    setState(() {
      _currentLevel = 0;
      _cards = [];
      _flippedIndices = [];
    });
  }

  // ── 다이얼로그 ──

  void _showAPDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '행동력 부족',
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: const Text(
          '과제를 수행하기 위한\n행동력이 부족합니다.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '확인',
              style: TextStyle(
                color: Color(0xFF5B8DEF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLevelClearDialog() {
    final reward = _stages[_currentLevel - 1].reward;
    final stageConfig = _stages[_currentLevel - 1];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Color(0xFF2E7D32), size: 24),
            const SizedBox(width: 8),
            const Text(
              '과제 제출 승인 완료',
              style: TextStyle(
                color: Color(0xFF2D3142),
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '[${stageConfig.title}] 과제가 정상 제출되었습니다.',
              style: const TextStyle(
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '학비 보조금 수령',
                    style: TextStyle(color: Color(0xFF2E7D32), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '+$reward원',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _returnToMenu(); // 다음 과목으로 자동 진행하지 않고 학사 포털로 이동
            },
            child: const Text(
              '학사 포털로 이동',
              style: TextStyle(
                color: Color(0xFF5B8DEF),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResultDialog({required bool cleared, required int finalLevel}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              cleared ? Icons.workspace_premium_rounded : Icons.running_with_errors_rounded,
              color: cleared
                  ? const Color(0xFFFFCA28)
                  : const Color(0xFFE85D75),
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              cleared ? 'A+ 학기 최종 이수 완료!' : '과제 제출 기한 마감',
              style: const TextStyle(
                color: Color(0xFF2D3142),
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cleared
                  ? '수강한 모든 과목의 인터넷 강의 수강 및 과제 제출을 성공적으로 완료하였습니다!'
                  : '제출 마감 시간을 초과하여 금일 과제 수행에 실패하였습니다.',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, height: 1.5),
            ),
            if (!cleared && finalLevel > 0) ...[
              const SizedBox(height: 8),
              Text(
                '실패한 과목: 과목 $finalLevel (${_stages[finalLevel - 1].title})',
                style: const TextStyle(color: Color(0xFFE85D75), fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '총 장학 보조금',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),
                  Text(
                    '$_totalEarned원',
                    style: const TextStyle(
                      color: Color(0xFF2D3142),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!cleared)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _startGameForStage(finalLevel);
              },
              child: const Text(
                '재도전 (행동력 -1)',
                style: TextStyle(
                  color: Color(0xFFE53935),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _returnToMenu();
            },
            child: Text(
              cleared ? '확인' : '학사 포털로 이동',
              style: const TextStyle(
                color: Color(0xFF5B8DEF),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 배경 연출 ──

  Widget _buildBackgroundWrapper({required Widget child}) {
    return Stack(
      children: [
        // Background Soft Gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFFDFBFA),
                Color(0xFFF5F7FA),
              ],
            ),
          ),
        ),
        // Soft glowing background blobs for visual depth and premium glassmorphic effect
        Positioned(
          top: 60,
          right: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF5B8DEF).withValues(alpha: 0.07), // 메인 블루 테마 블롭
            ),
          ),
        ),
        Positioned(
          bottom: 200,
          left: -100,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFA590FF).withValues(alpha: 0.07), // 서브 퍼플 테마 블롭
            ),
          ),
        ),
        Positioned(
          bottom: -40,
          right: -40,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6AD8C3).withValues(alpha: 0.07), // 서브 민트 테마 블롭
            ),
          ),
        ),
        // Foreground Content
        child,
      ],
    );
  }

  // 오늘 남은 가장 낮은 진행 대상 과제 탐색 (순차 진행 확인)
  int _getActiveStage() {
    for (int i = 1; i <= 5; i++) {
      if (!MinigameScreen.clearedStagesToday.contains(i)) {
        return i;
      }
    }
    return 6; // 전과목 이수 완료
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _buildBackgroundWrapper(
          child: _currentLevel == 0 ? _buildMenuScreen() : _buildGameScreen(),
        ),
      ),
    );
  }

  // ── 메인 메뉴 화면 (E-class 학사 정보 및 수강 리스트) ──

  Widget _buildMenuScreen() {
    return Column(
      children: [
        // 상단 바: 뒤로가기 + AP
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const Spacer(),
              // AP 뱃지
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDDE4F0), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_rounded, color: Color(0xFF5B8DEF), size: 16),
                    const SizedBox(width: 5),
                    Text(
                      '학업 AP $_currentAP',
                      style: const TextStyle(
                        color: Color(0xFF5B8DEF),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              // 학사 정보 등록 카드
              _buildAcademicInfoCard(),
              const SizedBox(height: 24),

              // 섹션 타이틀
              const Text(
                '이번 학기 수강 과목 (과제 목록)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),

              // 과목 리스트
              ..._stages.map((stage) => _buildCourseItemCard(stage)),
              const SizedBox(height: 24),

              // 인터넷 강의 수강 시작 버튼
              _buildStartButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAcademicInfoCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B8DEF).withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF5B8DEF).withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // 학사 아이콘 데코
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B8DEF).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF5B8DEF).withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Color(0xFF5B8DEF),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // 학적 정보 상세
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'E-class 학사 정보 포털',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5B8DEF),
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '이름: 주인공 (3학년)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '학부: 소프트웨어학과 / 학번: 202610427',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7F8C8D),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseItemCard(_StageConfig stage) {
    final int s = stage.stage;
    final bool isCleared = MinigameScreen.clearedStagesToday.contains(s);
    final bool isUnlocked = s == 1 || MinigameScreen.clearedStagesToday.contains(s - 1);

    Color courseColor = Colors.grey;
    String statusText = "대기 중";
    Color statusBgColor = const Color(0xFFECEFF1);
    Color statusTextColor = const Color(0xFF78909C);

    if (isCleared) {
      courseColor = const Color(0xFF2E7D32); // Green
      statusText = "제출 완료";
      statusBgColor = const Color(0xFFE8F5E9);
      statusTextColor = const Color(0xFF2E7D32);
    } else if (isUnlocked) {
      courseColor = const Color(0xFF5B8DEF); // Blue
      statusText = "과제 예정";
      statusBgColor = const Color(0xFFF0F4FF);
      statusTextColor = const Color(0xFF5B8DEF);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: courseColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: GestureDetector(
            onTap: () {
              if (isCleared) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('오늘 이미 과제를 제출 완료한 과목입니다.'),
                    duration: Duration(seconds: 1),
                  ),
                );
              } else if (isUnlocked) {
                _startGameForStage(s);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('이전 과목의 과제를 먼저 완료해야 합니다.'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUnlocked
                    ? Colors.white.withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUnlocked
                      ? courseColor.withValues(alpha: 0.45)
                      : Colors.grey.withValues(alpha: 0.15),
                  width: isUnlocked ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  // 과목 번호
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: courseColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: isCleared
                          ? const Icon(Icons.check_rounded, color: Color(0xFF2E7D32), size: 18)
                          : Text(
                              '$s',
                              style: TextStyle(
                                color: courseColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // 과목명 및 실습 유형
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stage.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isUnlocked ? const Color(0xFF2C3E50) : const Color(0xFF7F8C8D),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stage.subTitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF95A5A6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 학비 보조금 (보상) 정보 및 상태 표시
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${stage.reward}원',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isUnlocked ? const Color(0xFF2C3E50) : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: statusTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    final activeStage = _getActiveStage();
    final bool allCleared = activeStage > 5;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: allCleared
                ? Colors.grey.withValues(alpha: 0.1)
                : const Color(0xFF5B8DEF).withValues(alpha: 0.22),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: allCleared
              ? null
              : () => _startGameForStage(activeStage),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: allCleared
                  ? const LinearGradient(
                      colors: [Color(0xFFB0BEC5), Color(0xFF90A4AE)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF7EB6FF), Color(0xFF5B8DEF)],
                    ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  allCleared ? '오늘의 수강 및 과제 완료' : '인터넷 강의 수강 및 과제 수행',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                if (!allCleared) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 3),
                        Text(
                          '-1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 인게임 화면 ──

  Widget _buildGameScreen() {
    final config = _stages[_currentLevel - 1];

    return Column(
      children: [
        // 타이머 바 (상단에 얇게) - 미리보기 시 빨간색, 게임 시 블루
        if (_isPreviewing)
          AnimatedBuilder(
            animation: _previewTimerCtrl,
            builder: (context, child) {
              final progress = 1.0 - _previewTimerCtrl.value;
              return Container(
                height: 4,
                width: double.infinity,
                color: const Color(0xFFF0F0F0),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(color: const Color(0xFFE85D75)),
                ),
              );
            },
          )
        else
          AnimatedBuilder(
            animation: _timerCtrl,
            builder: (context, child) {
              final progress = 1.0 - _timerCtrl.value;
              return Container(
                height: 4,
                width: double.infinity,
                color: const Color(0xFFF0F0F0),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF87CEEB),
                          Color.lerp(
                            const Color(0xFF5B8DEF),
                            const Color(0xFFE85D75),
                            _timerCtrl.value,
                          )!,
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

        // 상단 정보 바 (가로 레이아웃 오버플로우 방지 처리 적용)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              // 단계 표시 (가로 공간에 맞춰 텍스트 생략 처리되도록 Expanded 감쌈)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '과목 $_currentLevel: ${config.title}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xFF5B8DEF),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_isPreviewing)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '과제 미리보기 (암기하세요!)',
                    style: TextStyle(
                      color: Color(0xFFFF9800),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '제출 대기 중',
                    style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 카드 그리드 (상하 중앙 배치, 화면 꽉 채우기)
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final spacing = 8.0;
              final hPad = 12.0;
              final availableW = constraints.maxWidth - hPad * 2;
              final availableH = constraints.maxHeight - 16; // 하단 안전 여백
              final cellW =
                  ((availableW - spacing * (config.cols - 1)) / config.cols)
                      .clamp(1.0, double.infinity);
              final cellH =
                  ((availableH - spacing * (config.rows - 1)) / config.rows)
                      .clamp(1.0, double.infinity);
              final aspectRatio = cellW / cellH;

              // 실제 그리드가 차지하는 높이 계산
              final gridH = cellH * config.rows + spacing * (config.rows - 1);
              final vPad = (availableH - gridH) / 2;

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  vPad.clamp(0, double.infinity),
                  hPad,
                  vPad.clamp(0, double.infinity),
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: config.cols,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    childAspectRatio: aspectRatio,
                  ),
                  itemCount: _cards.length,
                  itemBuilder: (context, index) {
                    return _buildCard(index);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 개별 카드 위젯 (3D Flip) ──

  Widget _buildCard(int index) {
    final card = _cards[index];
    final controller = _flipControllers[index]!;

    return GestureDetector(
      onTap: () => _onCardTapped(index),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final value = controller.value;
          // Y축 회전 계산
          final angle = value < 0.5
              ? value * pi // 0 → π/2
              : (1 - value) * pi; // π/2 → 0
          final showFront = value >= 0.5;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // 원근감
              ..rotateY(angle),
            child: showFront ? _buildCardFront(card) : _buildCardBack(),
          );
        },
      ),
    );
  }

  Widget _buildCardFront(_CardData card) {
    return AnimatedScale(
      scale: card.isBouncing ? 1.06 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: card.isMatched
                ? card.color.withValues(alpha: 0.6)
                : const Color(0xFFE8ECF2),
            width: card.isMatched ? 2 : 1.5,
          ),
          boxShadow: [
            if (card.isMatched)
              BoxShadow(
                color: card.color.withValues(alpha: 0.15),
                blurRadius: 8,
                spreadRadius: 1,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Center(
          child: Icon(
            card.icon,
            size: 28,
            color: card.isMatched
                ? card.color.withValues(alpha: 0.65)
                : card.color,
          ),
        ),
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF5B8DEF).withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B8DEF).withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background abstract grid lines mimicking a ID card security pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.04,
              child: GridPaper(
                color: const Color(0xFF5B8DEF),
                divisions: 1,
                subdivisions: 1,
                interval: 20,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.school_rounded,
                  size: 24,
                  color: const Color(0xFF5B8DEF).withValues(alpha: 0.8),
                ),
                const SizedBox(height: 2),
                Text(
                  'E-CLASS',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF5B8DEF).withValues(alpha: 0.7),
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
