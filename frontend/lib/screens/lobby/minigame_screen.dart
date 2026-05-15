import 'dart:async';
import 'dart:math';
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
// 🃏 난이도 설정
// ══════════════════════════════════════════════════════════════════════════════

class _LevelConfig {
  final int cols;
  final int rows;
  const _LevelConfig(this.cols, this.rows);
  int get totalCards => cols * rows;
  int get pairCount => totalCards ~/ 2;
}

const List<_LevelConfig> _levels = [
  _LevelConfig(2, 2), // 1단계: 12장
  _LevelConfig(3, 4), // 2단계: 16장
  _LevelConfig(4, 4), // 3단계: 20장
  _LevelConfig(4, 5), // 4단계: 24장
  _LevelConfig(5, 5), // 5단계: 30장
];

const Map<int, int> _rewardTable = {1: 50, 2: 100, 3: 150, 4: 200, 5: 250};

// 카드 앞면에 사용할 아이콘 + 색상 풀
const List<Map<String, dynamic>> _iconPool = [
  {'icon': Icons.favorite, 'color': Color(0xFFE85D75)},
  {'icon': Icons.star, 'color': Color(0xFFFFAF40)},
  {'icon': Icons.diamond_outlined, 'color': Color(0xFF6EC6FF)},
  {'icon': Icons.local_florist, 'color': Color(0xFF66BB6A)},
  {'icon': Icons.music_note, 'color': Color(0xFFAB47BC)},
  {'icon': Icons.wb_sunny, 'color': Color(0xFFFFCA28)},
  {'icon': Icons.bolt, 'color': Color(0xFFFF7043)},
  {'icon': Icons.pets, 'color': Color(0xFF8D6E63)},
  {'icon': Icons.cake, 'color': Color(0xFFEC407A)},
  {'icon': Icons.anchor, 'color': Color(0xFF42A5F5)},
  {'icon': Icons.auto_awesome, 'color': Color(0xFFAB47BC)},
  {'icon': Icons.brightness_7, 'color': Color(0xFFFFA726)},
  {'icon': Icons.cloud, 'color': Color(0xFF78909C)},
  {'icon': Icons.eco, 'color': Color(0xFF66BB6A)},
  {'icon': Icons.extension, 'color': Color(0xFF7E57C2)},
];

// ══════════════════════════════════════════════════════════════════════════════
// 🃏 미니게임 메인 위젯
// ══════════════════════════════════════════════════════════════════════════════

class MinigameScreen extends StatefulWidget {
  final int actionPoints;
  final VoidCallback onClose;
  final Function(int earnedMoney)? onRewardEarned;
  final Function(int newAP)? onAPChanged;

  const MinigameScreen({
    super.key,
    required this.actionPoints,
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

  Future<void> _startGame() async {
    if (_currentAP < 1) {
      _showAPDialog();
      return;
    }

    final ok = await _callStartAPI();
    if (!ok) {
      _showAPDialog();
      return;
    }

    _totalEarned = 0;
    _startLevel(1);
  }

  void _startLevel(int level) {
    // 이전 플립 컨트롤러 정리
    for (final ctrl in _flipControllers.values) {
      ctrl.dispose();
    }
    _flipControllers.clear();

    final config = _levels[level - 1];
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

    if (_currentLevel >= 5) {
      // 전체 클리어
      _showResultDialog(cleared: true, finalLevel: 5);
    } else {
      // 다음 단계로
      _showLevelClearDialog();
    }
  }

  void _handleTimeUp() {
    if (_currentLevel == 0) return;
    _timerCtrl.stop();
    _showResultDialog(cleared: false, finalLevel: _currentLevel - 1);
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
      _totalEarned = 0;
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
          '게임을 시작하기 위한\n행동력이 부족합니다.',
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
    final reward = _rewardTable[_currentLevel] ?? 50;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF5B8DEF), size: 24),
            const SizedBox(width: 8),
            Text(
              'Stage $_currentLevel 클리어!',
              style: const TextStyle(
                color: Color(0xFF2D3142),
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          '보상: $reward원\n\n다음 단계로 진행합니다.',
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _startLevel(_currentLevel + 1);
            },
            child: const Text(
              '다음 단계',
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
              cleared ? Icons.emoji_events : Icons.timer_off,
              color: cleared
                  ? const Color(0xFFFFAF40)
                  : const Color(0xFFE85D75),
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              cleared ? '전체 클리어!' : '타임 오버',
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
            if (!cleared && finalLevel > 0)
              Text(
                'Stage $finalLevel까지 클리어',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
            if (!cleared && finalLevel == 0)
              const Text(
                '아쉽게도 실패했습니다.',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '획득 보상',
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
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _returnToMenu();
            },
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

  // ══════════════════════════════════════════════════════════════════════════
  // 🎨 빌드
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _currentLevel == 0 ? _buildMenuScreen() : _buildGameScreen(),
      ),
    );
  }

  // ── 메인 메뉴 화면 ──

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
                  color: Color(0xFF2D3142),
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
                    const Icon(Icons.bolt, color: Color(0xFF5B8DEF), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$_currentAP',
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

        const Spacer(flex: 3),

        // 게임 타이틀
        Column(
          children: [
            // 아이콘
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7EB6FF), Color(0xFF5B8DEF)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '카드 맞추기',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2D3142),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '카드를 뒤집어 같은 그림을 찾으세요',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),

        const SizedBox(height: 60), // 타이틀과 버튼 사이 거리감
        // 게임 시작 버튼
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: GestureDetector(
            onTap: _startGame,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7EB6FF), Color(0xFF5B8DEF)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '게임 시작',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, color: Colors.white, size: 14),
                        SizedBox(width: 2),
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
              ),
            ),
          ),
        ),

        const Spacer(flex: 4),
      ],
    );
  }

  // ── 인게임 화면 ──

  Widget _buildGameScreen() {
    final config = _levels[_currentLevel - 1];

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

        // 상단 정보 바
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              // 단계 표시
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Stage $_currentLevel',
                  style: const TextStyle(
                    color: Color(0xFF5B8DEF),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
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
                    '카드를 기억하세요!',
                    style: TextStyle(
                      color: Color(0xFFFF9800),
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
                  (availableW - spacing * (config.cols - 1)) / config.cols;
              final cellH =
                  (availableH - spacing * (config.rows - 1)) / config.rows;
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
          // 0.0 = 뒷면, 1.0 = 앞면
          // 0.0~0.5: 뒷면 → 옆면 (Y축 회전 0 → -π/2)
          // 0.5~1.0: 옆면 → 앞면 (Y축 회전 π/2 → 0)
          final angle = value < 0.5
              ? value *
                    pi // 0 → π/2
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
                ? card.color.withValues(alpha: 0.5)
                : const Color(0xFFE8ECF2),
            width: card.isMatched ? 2 : 1.2,
          ),
        ),
        child: Center(
          child: Icon(
            card.icon,
            size: 30,
            color: card.isMatched
                ? card.color.withValues(alpha: 0.6)
                : card.color,
          ),
        ),
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7EB6FF), Color(0xFF5B8DEF)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Icon(
          Icons.question_mark_rounded,
          size: 24,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
