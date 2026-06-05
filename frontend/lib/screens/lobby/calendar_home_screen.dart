import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:frontend/core/api_client.dart';

class CalendarHomeScreen extends StatefulWidget {
  const CalendarHomeScreen({super.key});

  @override
  State<CalendarHomeScreen> createState() => _CalendarHomeScreenState();
}

class _CalendarHomeScreenState extends State<CalendarHomeScreen> {
  bool _isLoading = true;
  String _gameState = "INTRO_1";
  String _currentZone = "낮";
  List<dynamic> _heroines = [];
  Map<String, dynamic> _storyConfig = {};

  final Map<String, String> _heroineZones = {
    "이서연": "아침",
    "코토리": "낮",
    "리안": "저녁",
  };

  final Map<String, Color> _heroineColors = {
    "이서연": const Color(0xFFFF8A80), // 연코랄 핑크
    "코토리": const Color(0xFF00BFA5), // 연민트
    "리안": const Color(0xFF8B76F6),  // 연보라
  };

  @override
  void initState() {
    super.initState();
    _loadCalendarStatus();
  }

  Future<void> _loadCalendarStatus() async {
    try {
      final response = await ApiClient().dio.get('/calendar/status');
      if (response.data != null && response.data['status'] == 'success') {
        setState(() {
          _gameState = response.data['game_state'] ?? "INTRO_1";
          _currentZone = response.data['current_zone'] ?? "낮";
          _heroines = response.data['heroines'] ?? [];
          _storyConfig = response.data['story_config'] ?? {};
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("🚨 캘린더 데이터 로드 실패: $e");
      setState(() => _isLoading = false);
    }
  }

  IconData _getZoneIcon(String zone) {
    switch (zone) {
      case "아침":
        return Icons.wb_twilight_rounded;
      case "낮":
        return Icons.wb_sunny_rounded;
      case "저녁":
        return Icons.nightlight_round;
      case "새벽":
        return Icons.nights_stay_rounded;
      default:
        return Icons.access_time_rounded;
    }
  }

  String _getZoneTimeRange(String zone) {
    switch (zone) {
      case "아침":
        return "06:00 ~ 12:00";
      case "낮":
        return "12:00 ~ 18:00";
      case "저녁":
        return "18:00 ~ 24:00";
      case "새벽":
      case "밤":
        return "00:00 ~ 06:00";
      default:
        return "시간대 미정";
    }
  }

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
          top: 80,
          right: -90,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF8B76F6).withValues(alpha: 0.08), // 리안 (연보라)
            ),
          ),
        ),
        Positioned(
          bottom: 250,
          left: -110,
          child: Container(
            width: 340,
            height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF8A80).withValues(alpha: 0.08), // 이서연 (연코랄)
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          right: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00BFA5).withValues(alpha: 0.08), // 코토리 (연민트)
            ),
          ),
        ),
        // Foreground Content
        child,
      ],
    );
  }

  Widget _buildAnimatedItem({required Widget child, required int index}) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (index * 120)),
      curve: Curves.easeOutCubic,
      builder: (context, value, childWidget) {
        return Transform.translate(
          offset: Offset(0, 24 * (1.0 - value)),
          child: Opacity(
            opacity: value,
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Center(
            child: Text(
              '✕',
              style: TextStyle(
                fontSize: 22,
                color: Color(0xFF5F4A41),
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
        title: const Text(
          '캘린더',
          style: TextStyle(
            color: Color(0xFF5F4A41),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFC56F)),
              ),
            )
          : SafeArea(
              child: _buildBackgroundWrapper(
                child: _buildContent(),
              ),
            ),
    );
  }

  Widget _buildContent() {
    final bool isMainOrEnd = _gameState == "MAIN" || _gameState == "END";
    dynamic mainHeroine;
    if (isMainOrEnd) {
      mainHeroine = _heroines.firstWhere(
        (h) => h['is_main'] == true,
        orElse: () => null,
      );
    }

    if (isMainOrEnd && mainHeroine != null) {
      return _buildMainRouteTimeline(mainHeroine);
    } else {
      return _buildIntroHeroineCards();
    }
  }

  // 히로인 원형 아바타 위젯 (완료 시 체크 뱃지 및 반투명 효과 추가)
  Widget _buildAvatar(String name, Color color, bool isCleared) {
    final Map<String, String> avatarPaths = {
      "이서연": "assets/images/character/이서연/이서연_기본.png",
      "코토리": "assets/images/character/코토리/코토리_기본.png",
      "리안": "assets/images/character/리안/리안_실외_기본.png",
    };

    final path = avatarPaths[name];
    return Stack(
      children: [
        Opacity(
          opacity: isCleared ? 0.65 : 1.0,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: path != null
                  ? Image.asset(
                      path,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.person_outline_rounded, color: color, size: 28);
                      },
                    )
                  : Icon(Icons.person_outline_rounded, color: color, size: 28),
            ),
          ),
        ),
        if (isCleared)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.green[600],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 10,
              ),
            ),
          ),
      ],
    );
  }

  // INTRO_1 전용 Day 0 프롤로그 스토리 진행 상황 카드
  Widget _buildIntro1PrologueCard() {
    final color = const Color(0xFFFFC56F); // 프롤로그 전용 골드 옐로우
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 16,
            spreadRadius: 1.5,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: color.withValues(alpha: 0.7),
                width: 2.0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
                    ),
                    child: Icon(Icons.star_rounded, color: color, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "프롤로그 (튜토리얼)",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "진행 가능",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "게임의 첫 시작을 여는 전체 인트로 스토리",
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF95A5A6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.wb_sunny_rounded, size: 13, color: color),
                            const SizedBox(width: 4),
                            Text(
                              "Day 0 - 프롤로그 스토리 대기 중",
                              style: TextStyle(
                                fontSize: 13,
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 히로인 카드 위젯 (완료/예정 모두 공통으로 쓰는 베이스 렌더러)
  Widget _buildHeroineIntroCard({
    required String name,
    required int day,
    required String zone,
    required String timezoneInfo,
    required Color color,
    required String statusText,
    required Color statusBgColor,
    required Color statusTextColor,
    required bool isCleared,
    required bool isTarget,
  }) {
    final displayBorderColor = isTarget
        ? color.withValues(alpha: 0.75)
        : (isCleared ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.3));

    final displayShadowColor = isTarget
        ? color.withValues(alpha: 0.22)
        : (isCleared ? Colors.transparent : color.withValues(alpha: 0.05));

    final double borderWidth = isTarget ? 2.2 : (isCleared ? 1.0 : 1.5);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: displayShadowColor,
            blurRadius: isTarget ? 16 : 10,
            spreadRadius: isTarget ? 1.5 : 0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isCleared
                  ? Colors.white.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: displayBorderColor,
                width: borderWidth,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  _buildAvatar(name, color, isCleared),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2C3E50),
                                decoration: isCleared ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timezoneInfo,
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF95A5A6),
                            fontWeight: FontWeight.w500,
                            decoration: isCleared ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _getZoneIcon(zone),
                              size: 13,
                              color: isCleared ? Colors.grey[400] : color.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _gameState == "INTRO_1" && !isCleared
                                  ? "Day 1 - $zone 스케줄 예정"
                                  : "Day $day - $zone 스케줄",
                              style: TextStyle(
                                fontSize: 13,
                                color: isCleared ? Colors.grey[400] : color.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w700,
                                decoration: isCleared ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 1단계: 인트로 분기 (3인 히로인 일정 카드 세로형 정렬 + 중복 카드 및 독립적 진행 일수 지원)
  Widget _buildIntroHeroineCards() {
    final Map<String, dynamic> heroineMap = {
      for (var h in _heroines) h['name'].toString(): h
    };

    final order = ["이서연", "코토리", "리안"];

    // INTRO_2에서 현재 진행해야 할 히로인 순서 판정 (현재 시간에 따른 순차 진행)
    String nextStoryHeroine = "이서연";
    int nextStoryDay = 1;

    if (_gameState == "INTRO_2") {
      final seoyeon = heroineMap["이서연"];
      final kotori = heroineMap["코토리"];
      final lian = heroineMap["리안"];

      final syCleared = seoyeon != null && seoyeon['is_cleared_today'] == true;
      final ktCleared = kotori != null && kotori['is_cleared_today'] == true;
      final laCleared = lian != null && lian['is_cleared_today'] == true;

      final syDay = seoyeon?['current_day'] ?? 1;
      final ktDay = kotori?['current_day'] ?? 1;
      final laDay = lian?['current_day'] ?? 1;

      if (_currentZone == "아침") {
        if (!syCleared) {
          nextStoryHeroine = "이서연";
          nextStoryDay = syDay;
        } else {
          nextStoryHeroine = "코토리";
          nextStoryDay = ktDay;
        }
      } else if (_currentZone == "낮") {
        if (!ktCleared) {
          nextStoryHeroine = "코토리";
          nextStoryDay = ktDay;
        } else {
          nextStoryHeroine = "리안";
          nextStoryDay = laDay;
        }
      } else if (_currentZone == "저녁") {
        if (!laCleared) {
          nextStoryHeroine = "리안";
          nextStoryDay = laDay;
        } else {
          // 셋 다 오늘 완료했거나 저녁 스토리가 끝난 경우 -> 다음 날 이서연(아침)
          nextStoryHeroine = "이서연";
          nextStoryDay = syDay + 1;
        }
      } else {
        // 새벽/밤 시간대 등인 경우 -> 다음 날 이서연(아침)
        nextStoryHeroine = "이서연";
        nextStoryDay = syDay + (syCleared ? 1 : 0);
      }
    }

    final List<Widget> completedCards = [];
    final List<Widget> upcomingCards = [];

    for (final name in order) {
      final heroine = heroineMap[name];
      if (heroine == null) continue;

      final color = _heroineColors[name] ?? Colors.grey;
      final targetZone = _heroineZones[name] ?? "낮";
      final currentDay = heroine['current_day'] ?? 1;
      final isCleared = heroine['is_cleared_today'] ?? false;
      final timezoneInfo = "등장 시간: ${_getZoneTimeRange(targetZone)}";

      // 1. 당일 이미 완료한 스케줄이 있다면 완료 카드(Day currentDay)를 상단 완료 영역에 추가
      if (_gameState != "INTRO_1" && isCleared) {
        completedCards.add(
          _buildHeroineIntroCard(
            name: name,
            day: currentDay,
            zone: targetZone,
            timezoneInfo: timezoneInfo,
            color: color,
            statusText: "오늘 완료",
            statusBgColor: const Color(0xFFE8F5E9),
            statusTextColor: const Color(0xFF2E7D32),
            isCleared: true,
            isTarget: false,
          ),
        );
      }

      // 2. 앞으로 다가올 대기/예정 카드(Day displayDay)를 예정 영역에 추가
      int displayDay = isCleared ? currentDay + 1 : currentDay;
      String statusText = "대기 중";
      Color statusBgColor = const Color(0xFFECEFF1);
      Color statusTextColor = const Color(0xFF546E7A);

      bool isTarget = false;
      if (_gameState == "INTRO_1") {
        displayDay = 0;
        statusText = "대기 중";
      } else {
        if (name == nextStoryHeroine && displayDay == nextStoryDay) {
          isTarget = true;
          if (_currentZone == targetZone) {
            statusText = "진행 가능";
            statusBgColor = const Color(0xFFE8F5E9); // 연녹색
            statusTextColor = const Color(0xFF2E7D32);
          } else {
            statusText = "등장 예정";
            statusBgColor = const Color(0xFFFFF9C4); // 연황색
            statusTextColor = const Color(0xFFF57F17);
          }
        } else {
          statusText = "대기 중";
        }
      }

      upcomingCards.add(
        _buildHeroineIntroCard(
          name: name,
          day: displayDay,
          zone: targetZone,
          timezoneInfo: timezoneInfo,
          color: color,
          statusText: statusText,
          statusBgColor: statusBgColor,
          statusTextColor: statusTextColor,
          isCleared: false,
          isTarget: isTarget,
        ),
      );
    }

    final List<Widget> finalItems = [];

    if (_gameState == "INTRO_1") {
      finalItems.add(_buildIntro1PrologueCard());
      finalItems.add(const SizedBox(height: 12));
    }

    // 오늘 완료 영역
    if (completedCards.isNotEmpty) {
      finalItems.add(
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 12),
          child: Row(
            children: [
              Text(
                "오늘 완료된 일정",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7F8C8D),
                ),
              ),
              SizedBox(width: 8),
              Expanded(child: Divider(thickness: 1)),
            ],
          ),
        ),
      );
      finalItems.addAll(completedCards);
      finalItems.add(const SizedBox(height: 12));
    }

    // 다음 예정 영역
    if (upcomingCards.isNotEmpty) {
      finalItems.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Row(
            children: [
              Text(
                _gameState == "INTRO_1" ? "다음 예정된 스케줄 (Day 1)" : "다음 예정된 일정",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7F8C8D),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(child: Divider(thickness: 1)),
            ],
          ),
        ),
      );
      finalItems.addAll(upcomingCards);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      itemCount: finalItems.length,
      itemBuilder: (context, index) {
        final item = finalItems[index];
        // Apply animation to actual card items (containers, not dividers/spacers)
        if (item is Container) {
          return _buildAnimatedItem(child: item, index: index);
        }
        return item;
      },
    );
  }

  // 2단계: 메인 루트 분기 (당일 포함 해금된 모든 미래 스케줄 노출)
  Widget _buildMainRouteTimeline(dynamic heroine) {
    final name = heroine['name'].toString();
    final color = _heroineColors[name] ?? Colors.grey;
    final int currentDay = heroine['current_day'] ?? 9;
    final List<dynamic> viewedZones = heroine['viewed_zones'] ?? [];

    final heroineConfig = _storyConfig[name] ?? {};
    final scheduleMap = heroineConfig['schedule'] ?? {};

    // 현재 일수 이상의 해금된 날짜들을 오름차순 정렬
    final List<int> sortedDays = scheduleMap.keys
        .map((k) => int.tryParse(k.toString()) ?? 0)
        .where((d) => d >= currentDay)
        .toList()
      ..sort();

    // 전역 차원에서의 다음 타겟 스토리 색출
    int targetDay = -1;
    String targetZone = "";

    // 1. 당일(currentDay) 진행 대상 검사
    final List<dynamic> currentDaySchedule = scheduleMap[currentDay.toString()] ?? [];
    for (final z in currentDaySchedule) {
      final zoneStr = z.toString();
      if (!viewedZones.contains(zoneStr)) {
        targetDay = currentDay;
        targetZone = zoneStr;
        break;
      }
    }

    // 2. 당일 완료 시, 미래 일정(day > currentDay) 중 첫 번째를 타겟으로 지정
    if (targetDay == -1) {
      for (int day in sortedDays) {
        if (day > currentDay) {
          final List<dynamic> daySchedule = scheduleMap[day.toString()] ?? [];
          if (daySchedule.isNotEmpty) {
            targetDay = day;
            targetZone = daySchedule.first.toString();
            break;
          }
        }
      }
    }

    final List<Widget> timelineItems = [];

    // 1. 프로필 헤더 카드
    timelineItems.add(
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
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
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  _buildAvatar(name, color, false),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$name 루트 진행 중",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "현재 진행도: Day $currentDay",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7F8C8D),
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
      ),
    );

    timelineItems.add(const SizedBox(height: 24));

    // 2. 전체 일정 연출
    if (sortedDays.isEmpty) {
      timelineItems.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              "예정된 스토리 일정이 없습니다.",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    } else {
      for (var day in sortedDays) {
        final List<dynamic> daySchedule = scheduleMap[day.toString()] ?? [];
        final bool isToday = day == currentDay;

        // 일자 구분 구분선 카드
        timelineItems.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isToday
                        ? color.withValues(alpha: 0.15)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isToday ? color : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isToday ? "오늘 (Day $day)" : "Day $day 일정",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isToday ? color : const Color(0xFF7F8C8D),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Divider(thickness: 1, height: 1),
                ),
              ],
            ),
          ),
        );

        // 일자별 스케줄 노드 렌더링
        for (int index = 0; index < daySchedule.length; index++) {
          final zone = daySchedule[index].toString();
          final bool isViewed = day < currentDay || (isToday && viewedZones.contains(zone));
          final bool isNextTarget = day == targetDay && zone == targetZone;

          String statusText = "대기 중";
          Color statusBgColor = const Color(0xFFECEFF1);
          Color statusTextColor = const Color(0xFF546E7A);

          if (isViewed) {
            statusText = "완료";
            statusBgColor = const Color(0xFFE8F5E9);
            statusTextColor = const Color(0xFF2E7D32);
          } else if (isNextTarget) {
            if (isToday && _currentZone == zone) {
              statusText = "진행 가능";
              statusBgColor = const Color(0xFFE8F5E9);
              statusTextColor = const Color(0xFF2E7D32);
            } else {
              statusText = "등장 예정";
              statusBgColor = const Color(0xFFFFF9C4);
              statusTextColor = const Color(0xFFF57F17);
            }
          }

          timelineItems.add(
            _buildTimelineNode(
              day: day,
              zone: zone,
              statusText: statusText,
              statusBgColor: statusBgColor,
              statusTextColor: statusTextColor,
              isViewed: isViewed,
              isNextTarget: isNextTarget,
              isLast: index == daySchedule.length - 1,
              heroineColor: color,
            ),
          );
        }
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: timelineItems.length,
      itemBuilder: (context, index) {
        final item = timelineItems[index];
        // Apply entrance animation to main visual cards
        if (item is Container || item is Row) {
          return _buildAnimatedItem(child: item, index: index);
        }
        return item;
      },
    );
  }

  // 타임라인 개별 노드 위젯
  Widget _buildTimelineNode({
    required int day,
    required String zone,
    required String statusText,
    required Color statusBgColor,
    required Color statusTextColor,
    required bool isViewed,
    required bool isNextTarget,
    required bool isLast,
    required Color heroineColor,
  }) {
    final double borderWidth = isNextTarget ? 1.8 : 1.0;
    final displayBorderColor = isNextTarget
        ? heroineColor.withValues(alpha: 0.55)
        : (isViewed ? heroineColor.withValues(alpha: 0.15) : Colors.grey[200]!);

    final displayShadowColor = isNextTarget
        ? heroineColor.withValues(alpha: 0.12)
        : Colors.transparent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 세로선 및 포인트 아이콘
        Column(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isViewed
                    ? heroineColor
                    : (isNextTarget ? Colors.white : Colors.grey[200]),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isNextTarget ? heroineColor : (isViewed ? Colors.transparent : Colors.grey[300]!),
                  width: isNextTarget ? 2.5 : 1.5,
                ),
              ),
              child: isViewed
                  ? const Icon(Icons.check, size: 10, color: Colors.white)
                  : (isNextTarget
                      ? Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: heroineColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null),
            ),
            if (!isLast)
              Container(
                width: 1.5,
                height: 56,
                color: isViewed ? heroineColor : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 14),
        // 카드 정보
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: displayShadowColor,
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.015),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isViewed
                        ? Colors.white.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: displayBorderColor,
                      width: borderWidth,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getZoneIcon(zone),
                                size: 14,
                                color: isViewed ? Colors.grey[400] : heroineColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "$zone 스토리",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2C3E50),
                                  decoration: isViewed ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ],
                          ),
                          if (isNextTarget) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, size: 13, color: Colors.orangeAccent),
                                const SizedBox(width: 4),
                                Text(
                                  "현재 진행 대상",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ]
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
